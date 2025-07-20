/*
 * TSN Traffic Shaping Engine
 * 
 * This module implements IEEE 802.1Qbv Time-Aware Shaping and IEEE 802.1Qav 
 * Credit-Based Shaping for automotive TSN applications. Features include:
 * - Gate Control Lists (GCL) for deterministic scheduling
 * - Credit-based shaping for bandwidth management
 * - 8 traffic classes per port with strict priority
 * - Guard band implementation for frame protection
 * - Sub-microsecond timing precision
 * 
 * Author: Sid Kundu
 * Target: NXP Automotive TSN Applications
 * Compliance: IEEE 802.1Qbv-2015, IEEE 802.1Qav-2009
 */

module tsn_traffic_shaper #(
    parameter NUM_PORTS = 4,                // Number of Ethernet ports
    parameter NUM_CLASSES = 8,              // Number of traffic classes (0-7)
    parameter GCL_DEPTH = 1024,             // Gate Control List depth
    parameter GUARD_BAND_NS = 500           // Guard band in nanoseconds
) (
    // Clock and Reset
    input  wire         clk,                // System clock (125 MHz)
    input  wire         rst_n,              // Active-low reset
    
    // PTP Time Interface
    input  wire [63:0]  ptp_time,           // Current PTP time (nanoseconds)
    input  wire         time_valid,         // PTP time is synchronized
    
    // Frame Input Interface (from MAC/Classifier)
    input  wire         frame_valid,        // Frame ready for transmission
    input  wire [2:0]   frame_class,        // Traffic class (0-7)
    input  wire [1:0]   frame_port,         // Destination port (0-3)
    input  wire [15:0]  frame_length,       // Frame length in bytes
    input  wire [63:0]  frame_timestamp,    // Frame arrival timestamp
    input  wire         frame_preemptable,  // Frame can be preempted (802.1Qbu)
    output wire         frame_ready,        // Ready to accept frame
    
    // Gate Control Interface (IEEE 802.1Qbv)
    output wire [7:0]   gate_states [0:3],  // Gate state for each port/class
    output wire         transmission_gate,  // Current gate allows transmission
    output wire [31:0]  current_cycle_time, // Current cycle time
    output wire [31:0]  next_gate_event,    // Time to next gate event (ns)
    
    // Credit-Based Shaping Interface (IEEE 802.1Qav)
    output wire [31:0]  credit_sr_a [0:3],  // Credits for SR Class A (per port)
    output wire [31:0]  credit_sr_b [0:3],  // Credits for SR Class B (per port)
    output wire         cbs_gate_a [0:3],   // CBS gate for Class A
    output wire         cbs_gate_b [0:3],   // CBS gate for Class B
    
    // Transmission Decision Output
    output wire         transmit_enable,    // Frame can be transmitted now
    output wire [2:0]   selected_class,     // Selected traffic class for TX
    output wire [1:0]   selected_port,      // Selected port for TX
    output wire [31:0]  transmission_time,  // Scheduled transmission time
    
    // Configuration Interface
    input  wire         gcl_enable,         // Enable gate control list
    input  wire [31:0]  cycle_time,         // Base cycle time (nanoseconds)
    input  wire [31:0]  cycle_extension,    // Cycle extension time
    input  wire [63:0]  base_time,          // GCL base time
    
    // Per-class configuration (index by traffic class)
    input  wire [31:0]  gate_duration [0:7], // Gate open duration for each class
    input  wire [7:0]   gate_sequence [0:7], // Gate control sequence
    input  wire [31:0]  cbs_idle_slope [0:7], // CBS idle slope (bits/sec)
    input  wire [31:0]  cbs_send_slope [0:7], // CBS send slope (bits/sec)
    input  wire [31:0]  cbs_hi_credit [0:7],  // CBS high credit limit
    input  wire [31:0]  cbs_lo_credit [0:7],  // CBS low credit limit
    
    // Status and Statistics
    output wire [31:0]  gates_opened [0:7],  // Count of gate openings per class
    output wire [31:0]  frames_blocked [0:7], // Frames blocked per class
    output wire [31:0]  guard_band_hits,     // Guard band violations
    output wire [7:0]   shaper_status        // Overall shaper status
);

    // Internal signals for gate control
    reg [31:0] cycle_counter;
    reg [31:0] gate_timer;
    reg [9:0]  gcl_index;
    reg [7:0]  current_gates [0:3];
    reg        in_cycle;
    
    // Credit-based shaping registers
    reg signed [31:0] credit_accumulator [0:3][0:7]; // Per port, per class
    reg [31:0] last_update_time [0:3][0:7];
    reg        credit_gate [0:3][0:7];
    
    // Frame queue and arbitration
    reg [2:0]  queue_class [0:15];      // Queued frame classes
    reg [1:0]  queue_port [0:15];       // Queued frame ports
    reg [15:0] queue_length [0:15];     // Queued frame lengths
    reg [3:0]  queue_head, queue_tail;  // Queue pointers
    reg        queue_valid [0:15];      // Queue slot valid
    
    // Statistics registers
    reg [31:0] gates_opened_reg [0:7];
    reg [31:0] frames_blocked_reg [0:7];
    reg [31:0] guard_band_hits_reg;
    
    /*
     * Gate Control List (GCL) Engine - IEEE 802.1Qbv
     * Implements time-aware gating for deterministic traffic scheduling
     */
    
    // Calculate current position in cycle
    wire [63:0] time_since_base = ptp_time - base_time;
    wire [31:0] cycle_position = time_since_base % cycle_time;
    
    // Gate Control List Memory (simplified - would use BRAM in real implementation)
    reg [7:0]  gcl_gates [0:1023];      // Gate states for each GCL entry
    reg [31:0] gcl_duration [0:1023];   // Duration for each GCL entry
    reg [9:0]  gcl_length;              // Number of valid GCL entries
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 32'h0;
            gate_timer <= 32'h0;
            gcl_index <= 10'h0;
            in_cycle <= 1'b0;
            
            // Initialize all gates closed
            for (integer p = 0; p < NUM_PORTS; p = p + 1) begin
                current_gates[p] <= 8'h00;
            end
        end else if (time_valid && gcl_enable) begin
            cycle_counter <= cycle_position;
            
            // Update gate timer and GCL index
            if (gate_timer >= gcl_duration[gcl_index]) begin
                gate_timer <= 32'h0;
                gcl_index <= (gcl_index + 1) % gcl_length;
                
                // Update gate states for all ports
                for (integer p = 0; p < NUM_PORTS; p = p + 1) begin
                    current_gates[p] <= gcl_gates[gcl_index];
                end
                
                // Update statistics
                for (integer c = 0; c < NUM_CLASSES; c = c + 1) begin
                    if (gcl_gates[gcl_index][c]) begin
                        gates_opened_reg[c] <= gates_opened_reg[c] + 1;
                    end
                end
            end else begin
                gate_timer <= gate_timer + 8; // 8ns per clock cycle at 125 MHz
            end
            
            in_cycle <= 1'b1;
        end else begin
            // If not synchronized or GCL disabled, open all gates
            for (integer p = 0; p < NUM_PORTS; p = p + 1) begin
                current_gates[p] <= 8'hFF;
            end
            in_cycle <= 1'b0;
        end
    end
    
    /*
     * Credit-Based Shaping (CBS) Engine - IEEE 802.1Qav
     * Implements bandwidth management for streaming traffic classes
     */
    
    genvar port, class;
    generate
        for (port = 0; port < NUM_PORTS; port = port + 1) begin : gen_ports
            for (class = 0; class < NUM_CLASSES; class = class + 1) begin : gen_classes
                
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        credit_accumulator[port][class] <= 32'h0;
                        last_update_time[port][class] <= 32'h0;
                        credit_gate[port][class] <= 1'b1;
                    end else if (time_valid) begin
                        // Calculate time delta since last update
                        wire [31:0] time_delta = ptp_time[31:0] - last_update_time[port][class];
                        wire [31:0] credit_delta;
                        
                        // Update credits based on idle/send slope
                        if (frame_valid && frame_port == port && frame_class == class) begin
                            // Frame being transmitted - use send slope (negative)
                            credit_delta = (time_delta * cbs_send_slope[class]) / 1000000000;
                            credit_accumulator[port][class] <= credit_accumulator[port][class] - credit_delta;
                        end else begin
                            // No transmission - use idle slope (positive)
                            credit_delta = (time_delta * cbs_idle_slope[class]) / 1000000000;
                            credit_accumulator[port][class] <= credit_accumulator[port][class] + credit_delta;
                        end
                        
                        // Clamp credits to hi/lo limits
                        if (credit_accumulator[port][class] > cbs_hi_credit[class]) begin
                            credit_accumulator[port][class] <= cbs_hi_credit[class];
                        end else if (credit_accumulator[port][class] < cbs_lo_credit[class]) begin
                            credit_accumulator[port][class] <= cbs_lo_credit[class];
                        end
                        
                        // Gate control based on credit level
                        credit_gate[port][class] <= (credit_accumulator[port][class] >= 0);
                        
                        last_update_time[port][class] <= ptp_time[31:0];
                    end
                end
            end
        end
    endgenerate
    
    /*
     * Guard Band Implementation
     * Prevents frames from spanning gate closure boundaries
     */
    
    wire [31:0] frame_transmission_time;
    wire [31:0] time_to_gate_close;
    wire        guard_band_violation;
    
    // Calculate frame transmission time (simplified: 8 bits per byte, 1 Gbps)
    assign frame_transmission_time = (frame_length * 8); // nanoseconds at 1 Gbps
    
    // Time until next gate closure for the frame's traffic class
    wire [31:0] remaining_gate_time = gcl_duration[gcl_index] - gate_timer;
    assign time_to_gate_close = remaining_gate_time;
    
    // Check if frame would complete before gate closes (including guard band)
    assign guard_band_violation = (frame_transmission_time + GUARD_BAND_NS) > time_to_gate_close;
    
    always @(posedge clk) begin
        if (guard_band_violation && frame_valid) begin
            guard_band_hits_reg <= guard_band_hits_reg + 1;
        end
    end
    
    /*
     * Traffic Class Arbitration and Selection
     * Implements strict priority with TSN gate and CBS constraints
     */
    
    reg [2:0] selected_class_reg;
    reg [1:0] selected_port_reg;
    reg       transmit_enable_reg;
    reg [31:0] transmission_time_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected_class_reg <= 3'h0;
            selected_port_reg <= 2'h0;
            transmit_enable_reg <= 1'b0;
            transmission_time_reg <= 32'h0;
        end else begin
            transmit_enable_reg <= 1'b0;
            
            if (frame_valid && time_valid) begin
                // Check if frame can be transmitted based on:
                // 1. Gate state (802.1Qbv)
                // 2. Credit availability (802.1Qav for SR classes)
                // 3. Guard band constraints
                
                wire gate_open = current_gates[frame_port][frame_class];
                wire cbs_allowed = credit_gate[frame_port][frame_class];
                wire guard_ok = !guard_band_violation;
                
                // SR classes (typically 4 and 5) use both gate and CBS
                // Other classes use only gate control
                wire can_transmit;
                if (frame_class == 3'd4 || frame_class == 3'd5) begin
                    // Streaming traffic - check both gate and CBS
                    assign can_transmit = gate_open && cbs_allowed && guard_ok;
                end else begin
                    // Other traffic - check only gate and guard band
                    assign can_transmit = gate_open && guard_ok;
                end
                
                if (can_transmit) begin
                    transmit_enable_reg <= 1'b1;
                    selected_class_reg <= frame_class;
                    selected_port_reg <= frame_port;
                    transmission_time_reg <= ptp_time[31:0];
                end else begin
                    // Frame blocked - update statistics
                    frames_blocked_reg[frame_class] <= frames_blocked_reg[frame_class] + 1;
                end
            end
        end
    end
    
    /*
     * Configuration and Control Logic
     * Allows runtime configuration of GCL and CBS parameters
     */
    
    // Initialize default GCL (all gates open with 1ms intervals)
    integer init_i;
    initial begin
        gcl_length = 10'd8; // 8 entries for basic round-robin
        for (init_i = 0; init_i < 8; init_i = init_i + 1) begin
            gcl_gates[init_i] = 8'hFF;      // All gates open
            gcl_duration[init_i] = 32'd125000; // 125µs per slot (1ms total cycle)
        end
    end
    
    /*
     * Status and Debug Interface
     */
    
    wire [7:0] shaper_status_wire = {
        guard_band_violation,       // Bit 7: Guard band violation
        transmit_enable_reg,        // Bit 6: Currently transmitting
        in_cycle,                   // Bit 5: In valid cycle
        time_valid,                 // Bit 4: PTP synchronized
        gcl_enable,                 // Bit 3: GCL enabled
        |current_gates[0],          // Bit 2: Any gate open on port 0
        |current_gates[1],          // Bit 1: Any gate open on port 1
        |current_gates[2]           // Bit 0: Any gate open on port 2
    };
    
    /*
     * Output Assignments
     */
    
    // Gate states
    assign gate_states[0] = current_gates[0];
    assign gate_states[1] = current_gates[1];
    assign gate_states[2] = current_gates[2];
    assign gate_states[3] = current_gates[3];
    
    assign transmission_gate = current_gates[frame_port][frame_class];
    assign current_cycle_time = cycle_counter;
    assign next_gate_event = gcl_duration[gcl_index] - gate_timer;
    
    // Credit-based shaping outputs
    assign credit_sr_a[0] = credit_accumulator[0][4]; // Class A typically uses TC 4
    assign credit_sr_a[1] = credit_accumulator[1][4];
    assign credit_sr_a[2] = credit_accumulator[2][4];
    assign credit_sr_a[3] = credit_accumulator[3][4];
    
    assign credit_sr_b[0] = credit_accumulator[0][5]; // Class B typically uses TC 5
    assign credit_sr_b[1] = credit_accumulator[1][5];
    assign credit_sr_b[2] = credit_accumulator[2][5];
    assign credit_sr_b[3] = credit_accumulator[3][5];
    
    assign cbs_gate_a[0] = credit_gate[0][4];
    assign cbs_gate_a[1] = credit_gate[1][4];
    assign cbs_gate_a[2] = credit_gate[2][4];
    assign cbs_gate_a[3] = credit_gate[3][4];
    
    assign cbs_gate_b[0] = credit_gate[0][5];
    assign cbs_gate_b[1] = credit_gate[1][5];
    assign cbs_gate_b[2] = credit_gate[2][5];
    assign cbs_gate_b[3] = credit_gate[3][5];
    
    // Transmission control
    assign transmit_enable = transmit_enable_reg;
    assign selected_class = selected_class_reg;
    assign selected_port = selected_port_reg;
    assign transmission_time = transmission_time_reg;
    assign frame_ready = !guard_band_violation; // Simplified ready logic
    
    // Statistics
    assign gates_opened[0] = gates_opened_reg[0];
    assign gates_opened[1] = gates_opened_reg[1];
    assign gates_opened[2] = gates_opened_reg[2];
    assign gates_opened[3] = gates_opened_reg[3];
    assign gates_opened[4] = gates_opened_reg[4];
    assign gates_opened[5] = gates_opened_reg[5];
    assign gates_opened[6] = gates_opened_reg[6];
    assign gates_opened[7] = gates_opened_reg[7];
    
    assign frames_blocked[0] = frames_blocked_reg[0];
    assign frames_blocked[1] = frames_blocked_reg[1];
    assign frames_blocked[2] = frames_blocked_reg[2];
    assign frames_blocked[3] = frames_blocked_reg[3];
    assign frames_blocked[4] = frames_blocked_reg[4];
    assign frames_blocked[5] = frames_blocked_reg[5];
    assign frames_blocked[6] = frames_blocked_reg[6];
    assign frames_blocked[7] = frames_blocked_reg[7];
    
    assign guard_band_hits = guard_band_hits_reg;
    assign shaper_status = shaper_status_wire;

endmodule
