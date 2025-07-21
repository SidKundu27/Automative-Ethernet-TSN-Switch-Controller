/*
 * Cut-Through Switching Matrix
 * 
 * This module implements a high-performance switching matrix optimized for
 * automotive applications with ultra-low latency requirements. Features:
 * - Cut-through forwarding for minimum latency (< 500ns target)
 * - MAC address learning and forwarding database
 * - VLAN-aware switching with isolation
 * - Broadcast/multicast handling
 * - Automotive-specific security features
 * 
 * Author: Sid Kundu
 * Target: NXP Automotive TSN Switch Applications
 * Compliance: IEEE 802.1D, IEEE 802.1Q, IEEE 802.1CB
 */

module switching_matrix #(
    parameter NUM_PORTS = 4,                // Number of switch ports
    parameter MAC_TABLE_SIZE = 1024,        // MAC address table entries
    parameter VLAN_TABLE_SIZE = 256,        // VLAN table entries
    parameter CUT_THROUGH_THRESHOLD = 64    // Bytes before cut-through decision
) (
    // Clock and Reset
    input  wire         clk,                // System clock (125 MHz)
    input  wire         rst_n,              // Active-low reset
    
    // Input from MAC Controllers (4 ports)
    input  wire [3:0]   rx_valid,           // Frame valid from each port
    input  wire [3:0]   rx_sof,             // Start of frame
    input  wire [3:0]   rx_eof,             // End of frame
    input  wire [127:0] rx_data,            // 32-bit data from each port (4x32)
    input  wire [7:0]   rx_mod,             // Modulo for last word (2 bits per port)
    input  wire [3:0]   rx_error,           // Frame error indication
    
    // Header information from MAC parsers
    input  wire [191:0] rx_dst_mac,         // Destination MAC (48 bits x 4 ports)
    input  wire [191:0] rx_src_mac,         // Source MAC (48 bits x 4 ports)
    input  wire [63:0]  rx_ethertype,       // EtherType (16 bits x 4 ports)
    input  wire [47:0]  rx_vlan_id,         // VLAN ID (12 bits x 4 ports)
    input  wire [11:0]  rx_priority,        // Priority (3 bits x 4 ports)
    input  wire [3:0]   rx_vlan_valid,      // VLAN tag present
    
    // Output to MAC Controllers
    output wire [3:0]   tx_valid,           // Frame valid to each port
    output wire [3:0]   tx_sof,             // Start of frame
    output wire [3:0]   tx_eof,             // End of frame
    output wire [127:0] tx_data,            // 32-bit data to each port
    output wire [7:0]   tx_mod,             // Modulo for last word
    output wire [11:0]  tx_priority,        // Frame priority for shaping
    input  wire [3:0]   tx_ready,           // MAC ready to accept data
    
    // TSN Integration
    input  wire [63:0]  ptp_time,           // Current PTP time
    input  wire         time_valid,         // PTP synchronized
    output wire [63:0]  frame_timestamp,    // Frame timestamp for latency measurement
    
    // Configuration Interface
    input  wire         learning_enable,    // Enable MAC learning
    input  wire         cut_through_enable, // Enable cut-through forwarding
    input  wire [15:0]  default_vlan,       // Default VLAN for untagged frames
    input  wire [3:0]   port_enable,        // Enable per port
    
    // Security and Filtering
    input  wire         security_enable,    // Enable security features
    input  wire [47:0]  allowed_mac_base,   // Base MAC for automotive security
    input  wire [15:0]  allowed_mac_mask,   // MAC address mask
    input  wire [15:0]  blocked_ethertypes, // Blocked EtherTypes bitmap
    
    // VLAN Configuration
    input  wire [1023:0] vlan_member_packed,   // VLAN membership per port (256x4-bit)
    input  wire [1023:0] vlan_untag_packed,    // VLAN untagging per port (256x4-bit)
    
    // Statistics and Status
    output wire [127:0]  forwarded_frames_packed, // Forwarded frames per port (4x32-bit)
    output wire [127:0]  dropped_frames_packed,   // Dropped frames per port (4x32-bit)
    output wire [31:0]  learned_addresses,      // Total learned MAC addresses
    output wire [31:0]  security_violations,    // Security violation count
    output wire [15:0]  switch_status,          // Overall switch status
    
    // Debug Interface
    output wire [31:0]  cut_through_count,      // Cut-through forwards
    output wire [31:0]  store_forward_count,    // Store-and-forward count
    output wire [15:0]  latency_measurement     // Current latency (microseconds)
);

    /*
     * Internal Signal Declarations
     */
    
    // MAC Address Learning Table
    reg [47:0]  mac_table_addr [0:1023];    // MAC addresses
    reg [1:0]   mac_table_port [0:1023];    // Associated port
    reg [11:0]  mac_table_vlan [0:1023];    // Associated VLAN
    reg [31:0]  mac_table_timestamp [0:1023]; // Learning timestamp
    reg         mac_table_valid [0:1023];   // Entry valid
    reg [9:0]   mac_table_next_free;        // Next free entry pointer
    
    // Forwarding Decision Engine
    reg [3:0]   forward_port_mask [0:3];    // Output port mask for each input
    reg [2:0]   forward_priority [0:3];     // Frame priority
    reg         forward_valid [0:3];        // Forward decision valid
    reg         forward_drop [0:3];         // Drop frame
    reg         forward_cut_through [0:3];  // Use cut-through forwarding
    
    // Frame Buffering (for store-and-forward mode)
    reg [31:0]  frame_buffer [0:3][0:511];  // Frame storage per port
    reg [8:0]   buffer_write_ptr [0:3];     // Write pointer per port
    reg [8:0]   buffer_read_ptr [0:3];      // Read pointer per port
    reg         buffer_full [0:3];          // Buffer full flag
    reg         buffer_empty [0:3];         // Buffer empty flag
    
    // Cut-through Control
    reg [7:0]   cut_through_count_reg [0:3]; // Bytes received before decision
    reg         cut_through_active [0:3];    // Cut-through mode active
    reg [63:0]  frame_start_time [0:3];      // Frame arrival timestamp
    
    // Statistics
    reg [31:0]  forwarded_frames_reg [0:3];
    reg [31:0]  dropped_frames_reg [0:3];
    reg [31:0]  learned_addresses_reg;
    reg [31:0]  security_violations_reg;
    reg [31:0]  cut_through_count_reg_total;
    reg [31:0]  store_forward_count_reg;
    
    // Unpack input arrays from packed vectors
    wire [3:0] vlan_member [0:255];
    wire [3:0] vlan_untag [0:255];
    
    genvar v;
    generate
        for (v = 0; v < 256; v = v + 1) begin : unpack_vlan
            assign vlan_member[v] = vlan_member_packed[4*v+3:4*v];
            assign vlan_untag[v] = vlan_untag_packed[4*v+3:4*v];
        end
    endgenerate
    
    /*
     * MAC Address Learning Engine
     * Learns source MAC addresses and associates them with input ports
     */
    
    genvar port;
    generate
        for (port = 0; port < NUM_PORTS; port = port + 1) begin : gen_learning
            
            // Wire declarations for learning engine
            wire [47:0] src_mac = rx_src_mac[(port*48) +: 48];
            wire [11:0] vlan_id = rx_vlan_valid[port] ? rx_vlan_id[(port*12) +: 12] : default_vlan;
            
            // Register declarations for learning engine
            reg [9:0] lookup_index;
            reg found;
            integer i;
            
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    // Reset handled in separate initial block
                end else if (learning_enable && rx_valid[port] && rx_sof[port]) begin
                    // Look up source MAC in table
                    
                    // Search for existing entry
                    found = 1'b0;
                    for (i = 0; i < MAC_TABLE_SIZE; i = i + 1) begin
                        if (mac_table_valid[i] && 
                            mac_table_addr[i] == src_mac && 
                            mac_table_vlan[i] == vlan_id) begin
                            // Update existing entry
                            mac_table_port[i] <= port[1:0];
                            mac_table_timestamp[i] <= ptp_time[31:0];
                            found = 1'b1;
                            lookup_index = i[9:0];
                        end
                    end
                    
                    // Add new entry if not found
                    if (!found && mac_table_next_free < MAC_TABLE_SIZE) begin
                        mac_table_addr[mac_table_next_free] <= src_mac;
                        mac_table_port[mac_table_next_free] <= port[1:0];
                        mac_table_vlan[mac_table_next_free] <= vlan_id;
                        mac_table_timestamp[mac_table_next_free] <= ptp_time[31:0];
                        mac_table_valid[mac_table_next_free] <= 1'b1;
                        mac_table_next_free <= mac_table_next_free + 1;
                        learned_addresses_reg <= learned_addresses_reg + 1;
                    end
                end
            end
        end
    endgenerate
    
    /*
     * Forwarding Decision Engine
     * Determines output port(s) based on destination MAC and VLAN
     */
    
    generate
        for (port = 0; port < NUM_PORTS; port = port + 1) begin : gen_forwarding
            
            // Wire declarations for forwarding engine
            wire [47:0] dst_mac = rx_dst_mac[(port*48) +: 48];
            wire [47:0] src_mac = rx_src_mac[(port*48) +: 48];
            wire [11:0] vlan_id = rx_vlan_valid[port] ? rx_vlan_id[(port*12) +: 12] : default_vlan;
            wire [15:0] ethertype = rx_ethertype[(port*16) +: 16];
            wire [2:0]  priority = rx_priority[(port*3) +: 3];
            
            // Register declarations for forwarding engine
            reg [3:0] output_ports;
            reg drop_frame;
            reg security_violation;
            reg lookup_found;
            integer i;
            
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    forward_port_mask[port] <= 4'h0;
                    forward_priority[port] <= 3'h0;
                    forward_valid[port] <= 1'b0;
                    forward_drop[port] <= 1'b0;
                    forward_cut_through[port] <= 1'b0;
                end else if (rx_valid[port] && rx_sof[port] && !rx_error[port]) begin
                    
                    // Initialize
                    output_ports = 4'h0;
                    drop_frame = 1'b0;
                    security_violation = 1'b0;
                    
                    // Security checks (automotive-specific)
                    if (security_enable) begin
                        // Check if source MAC is within allowed range
                        if ((src_mac & {32'hFFFFFFFF, allowed_mac_mask}) != 
                            (allowed_mac_base & {32'hFFFFFFFF, allowed_mac_mask})) begin
                            security_violation = 1'b1;
                            drop_frame = 1'b1;
                        end
                        
                        // Check for blocked EtherTypes
                        if (blocked_ethertypes[ethertype[3:0]]) begin
                            drop_frame = 1'b1;
                        end
                    end
                    
                    if (!drop_frame) begin
                        // Check if destination is multicast/broadcast
                        if (dst_mac[40]) begin // Multicast bit
                            if (dst_mac == 48'hFFFFFFFFFFFF) begin
                                // Broadcast - flood to all ports except input
                                output_ports = vlan_member[vlan_id] & ~(1 << port);
                            end else begin
                                // Multicast - flood to VLAN members except input
                                output_ports = vlan_member[vlan_id] & ~(1 << port);
                            end
                        end else begin
                            // Unicast - lookup in MAC table
                            
                            lookup_found = 1'b0;
                            
                            for (i = 0; i < MAC_TABLE_SIZE; i = i + 1) begin
                                if (mac_table_valid[i] && 
                                    mac_table_addr[i] == dst_mac && 
                                    mac_table_vlan[i] == vlan_id) begin
                                    // Found - forward to specific port
                                    if (mac_table_port[i] != port) begin // Don't loop back
                                        output_ports = 1 << mac_table_port[i];
                                    end
                                    lookup_found = 1'b1;
                                end
                            end
                            
                            if (!lookup_found) begin
                                // Unknown unicast - flood to VLAN members except input
                                output_ports = vlan_member[vlan_id] & ~(1 << port);
                            end
                        end
                    end
                    
                    // Apply port enable mask
                    output_ports = output_ports & port_enable;
                    
                    // Update forwarding decision
                    forward_port_mask[port] <= output_ports;
                    forward_priority[port] <= priority;
                    forward_valid[port] <= 1'b1;
                    forward_drop[port] <= drop_frame;
                    
                    // Cut-through decision based on frame size and policy
                    forward_cut_through[port] <= cut_through_enable && 
                                               (cut_through_count_reg[port] >= CUT_THROUGH_THRESHOLD) &&
                                               !drop_frame;
                    
                    // Update statistics
                    if (drop_frame) begin
                        dropped_frames_reg[port] <= dropped_frames_reg[port] + 1;
                        if (security_violation) begin
                            security_violations_reg <= security_violations_reg + 1;
                        end
                    end else if (|output_ports) begin
                        forwarded_frames_reg[port] <= forwarded_frames_reg[port] + 1;
                    end
                    
                    // Record frame start time for latency measurement
                    frame_start_time[port] <= ptp_time;
                    
                end else if (rx_eof[port]) begin
                    forward_valid[port] <= 1'b0;
                    cut_through_count_reg[port] <= 8'h0;
                end else if (rx_valid[port]) begin
                    // Count bytes for cut-through threshold
                    if (cut_through_count_reg[port] < 8'hFF) begin
                        cut_through_count_reg[port] <= cut_through_count_reg[port] + 4;
                    end
                end
            end
        end
    endgenerate
    
    /*
     * Frame Forwarding and Buffering
     * Handles both cut-through and store-and-forward modes
     */
    
    reg [3:0] output_arbitration [0:3]; // Round-robin arbitration per output port
    
    generate
        for (port = 0; port < NUM_PORTS; port = port + 1) begin : gen_output
            
            reg [1:0] current_input; // Currently selected input for this output
            reg       output_active;
            reg [31:0] output_data;
            reg        output_valid, output_sof, output_eof;
            reg [1:0]  output_mod;
            reg [2:0]  output_priority;
            
            // Register declarations for output arbitration
            reg [1:0] selected_input;
            reg found;
            integer i, check_port;
            
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    current_input <= 2'h0;
                    output_active <= 1'b0;
                    output_valid <= 1'b0;
                    output_sof <= 1'b0;
                    output_eof <= 1'b0;
                    output_data <= 32'h0;
                    output_mod <= 2'h0;
                    output_priority <= 3'h0;
                    output_arbitration[port] <= 4'h1; // Start with port 0 priority
                end else begin
                    
                    output_sof <= 1'b0;
                    output_eof <= 1'b0;
                    
                    if (!output_active && tx_ready[port]) begin
                        // Look for new frame to forward (round-robin arbitration)
                        
                        found = 1'b0;
                        selected_input = 2'h0;
                        
                        // Check each input port based on arbitration order
                        for (i = 0; i < NUM_PORTS; i = i + 1) begin
                            check_port = (i + output_arbitration[port]) % NUM_PORTS;
                            if (!found && forward_valid[check_port] && 
                                forward_port_mask[check_port][port] && 
                                !forward_drop[check_port]) begin
                                selected_input = check_port[1:0];
                                found = 1'b1;
                            end
                        end
                        
                        if (found) begin
                            current_input <= selected_input;
                            output_active <= 1'b1;
                            output_priority <= forward_priority[selected_input];
                            output_sof <= 1'b1;
                            output_valid <= 1'b1;
                            
                            // Update arbitration for fairness
                            output_arbitration[port] <= (output_arbitration[port] + 1) % NUM_PORTS;
                            
                            // Start forwarding data
                            output_data <= rx_data[(selected_input*32) +: 32];
                            
                            // Update cut-through statistics
                            if (forward_cut_through[selected_input]) begin
                                cut_through_count_reg_total <= cut_through_count_reg_total + 1;
                            end else begin
                                store_forward_count_reg <= store_forward_count_reg + 1;
                            end
                        end
                        
                    end else if (output_active) begin
                        // Continue forwarding current frame
                        output_valid <= rx_valid[current_input];
                        output_data <= rx_data[(current_input*32) +: 32];
                        output_mod <= rx_mod[(current_input*2) +: 2];
                        
                        if (rx_eof[current_input]) begin
                            output_eof <= 1'b1;
                            output_active <= 1'b0;
                        end
                    end else begin
                        output_valid <= 1'b0;
                    end
                end
            end
            
            // Connect to output ports
            assign tx_valid[port] = output_valid;
            assign tx_sof[port] = output_sof;
            assign tx_eof[port] = output_eof;
            assign tx_data[(port*32) +: 32] = output_data;
            assign tx_mod[(port*2) +: 2] = output_mod;
            assign tx_priority[(port*3) +: 3] = output_priority;
        end
    endgenerate
    
    /*
     * Latency Measurement
     * Measures port-to-port latency for TSN compliance
     */
    
    reg [15:0] latency_measurement_reg;
    reg [63:0] latency_accumulator;
    reg [15:0] latency_count;
    
    // Latency measurement variables
    reg [31:0] latency_ns;
    integer p;
    
    always @(posedge clk) begin
        // Calculate average latency based on frame timestamps
        if (|tx_eof) begin
            // Frame completed transmission
            for (p = 0; p < NUM_PORTS; p = p + 1) begin
                if (tx_eof[p]) begin
                    latency_ns = ptp_time[31:0] - frame_start_time[p][31:0];
                    latency_accumulator <= latency_accumulator + {32'h0, latency_ns};
                    latency_count <= latency_count + 1;
                    
                    // Convert to microseconds and update running average
                    if (latency_count > 0) begin
                        latency_measurement_reg <= (latency_accumulator / latency_count) / 1000;
                    end
                end
            end
        end
    end
    
    /*
     * Initialization and Reset Logic
     */
    
    integer init_i;
    initial begin
        // Initialize MAC table
        for (init_i = 0; init_i < MAC_TABLE_SIZE; init_i = init_i + 1) begin
            mac_table_valid[init_i] = 1'b0;
            mac_table_addr[init_i] = 48'h0;
            mac_table_port[init_i] = 2'h0;
            mac_table_vlan[init_i] = 12'h0;
            mac_table_timestamp[init_i] = 32'h0;
        end
        mac_table_next_free = 10'h0;
        
        // Initialize statistics
        for (init_i = 0; init_i < NUM_PORTS; init_i = init_i + 1) begin
            forwarded_frames_reg[init_i] = 32'h0;
            dropped_frames_reg[init_i] = 32'h0;
            cut_through_count_reg[init_i] = 8'h0;
        end
        learned_addresses_reg = 32'h0;
        security_violations_reg = 32'h0;
        cut_through_count_reg_total = 32'h0;
        store_forward_count_reg = 32'h0;
        latency_measurement_reg = 16'h0;
        latency_accumulator = 64'h0;
        latency_count = 16'h0;
    end
    
    /*
     * Output Assignments
     */
    
    // Statistics outputs
    assign forwarded_frames_packed = {forwarded_frames_reg[3], forwarded_frames_reg[2], 
                                     forwarded_frames_reg[1], forwarded_frames_reg[0]};
    
    assign dropped_frames_packed = {dropped_frames_reg[3], dropped_frames_reg[2], 
                                   dropped_frames_reg[1], dropped_frames_reg[0]};
    
    assign learned_addresses = learned_addresses_reg;
    assign security_violations = security_violations_reg;
    assign cut_through_count = cut_through_count_reg_total;
    assign store_forward_count = store_forward_count_reg;
    assign latency_measurement = latency_measurement_reg;
    
    // Status register
    assign switch_status = {
        security_violations_reg[31],     // Bit 15: Security violations detected
        |dropped_frames_reg[0],          // Bit 14: Port 0 drops
        |dropped_frames_reg[1],          // Bit 13: Port 1 drops  
        |dropped_frames_reg[2],          // Bit 12: Port 2 drops
        |dropped_frames_reg[3],          // Bit 11: Port 3 drops
        cut_through_enable,              // Bit 10: Cut-through enabled
        learning_enable,                 // Bit 9: Learning enabled
        security_enable,                 // Bit 8: Security enabled
        port_enable                      // Bits 7-4: Port enable status
                                        // Bits 3-0: Reserved
    };
    
    assign frame_timestamp = frame_start_time[0]; // Simplified - would mux based on active port

endmodule
