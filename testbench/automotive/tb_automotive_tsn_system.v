/*
 * Automotive TSN System Testbench
 * 
 * This testbench simulates real automotive use cases for the TSN switch:
 * - ADAS camera data streams (high bandwidth, low latency)
 * - Brake-by-wire critical commands (ultra-low latency)
 * - Infotainment traffic (best effort)
 * - Diagnostic and maintenance data
 * - Time synchronization verification
 * 
 * Author: Sid Kundu
 * Target: NXP Automotive TSN Validation
 */

`timescale 1ns / 1ps

module tb_automotive_tsn_system;

    /*
     * Test Parameters
     */
    parameter CLOCK_PERIOD = 8.0;       // 125 MHz
    parameter SIM_TIME_LIMIT = 2000000; // 2ms simulation
    parameter CRITICAL_LATENCY_MAX = 500; // 500ns max for safety-critical
    
    /*
     * System Signals
     */
    reg         clk_125mhz, clk_25mhz, clk_200mhz;
    reg         rst_n;
    
    // Ethernet interfaces (4 ports)
    reg         gmii_rx_clk [0:3];
    reg         gmii_rx_dv [0:3];
    reg         gmii_rx_er [0:3];
    reg [7:0]   gmii_rxd [0:3];
    wire        gmii_tx_clk [0:3];
    wire        gmii_tx_en [0:3];
    wire        gmii_tx_er [0:3];
    wire [7:0]  gmii_txd [0:3];
    
    // Configuration interface
    reg         cfg_clk, cfg_cs_n, cfg_mosi;
    wire        cfg_miso, cfg_int_n;
    
    // Environmental sensors
    reg [11:0]  temp_sensor, voltage_sensor;
    
    // Debug
    wire [7:0]  debug_leds;
    reg [3:0]   test_mode;
    wire        debug_uart_tx;
    reg         debug_uart_rx;
    
    // Power management
    reg         wake_on_lan;
    wire        power_good;
    wire [3:0]  port_power_ctrl;
    
    /*
     * Test Environment Variables
     */
    integer test_scenario;
    integer frame_count [0:3];           // Frames per port
    real    latency_measurements [0:999]; // Latency storage
    integer latency_index;
    time    critical_frame_times [0:99]; // Critical frame timestamps
    integer critical_frame_index;
    
    // Traffic generation control
    reg [3:0] traffic_enable;            // Enable traffic per port
    reg [2:0] traffic_priority [0:3];    // Priority per port
    reg [15:0] traffic_interval [0:3];   // Interval between frames (cycles)
    reg [15:0] frame_size [0:3];         // Frame size per port
    
    // Performance monitoring
    real throughput_measurements [0:3];
    integer dropped_frame_count [0:3];
    real jitter_measurements [0:99];
    
    /*
     * Device Under Test - Complete TSN Switch System
     */
    automotive_tsn_switch_top #(
        .FPGA_FAMILY("XILINX"),
        .NUM_PORTS(4),
        .ENABLE_SECURITY(1),
        .ENABLE_DIAGNOSTICS(1)
    ) dut (
        .clk_125mhz(clk_125mhz),
        .clk_25mhz(clk_25mhz),
        .clk_200mhz(clk_200mhz),
        .rst_n(rst_n),
        
        // Port 0 - ADAS Camera
        .gmii_rx_clk_0(gmii_rx_clk[0]),
        .gmii_rx_dv_0(gmii_rx_dv[0]),
        .gmii_rx_er_0(gmii_rx_er[0]),
        .gmii_rxd_0(gmii_rxd[0]),
        .gmii_tx_clk_0(gmii_tx_clk[0]),
        .gmii_tx_en_0(gmii_tx_en[0]),
        .gmii_tx_er_0(gmii_tx_er[0]),
        .gmii_txd_0(gmii_txd[0]),
        
        // Port 1 - Brake Control
        .gmii_rx_clk_1(gmii_rx_clk[1]),
        .gmii_rx_dv_1(gmii_rx_dv[1]),
        .gmii_rx_er_1(gmii_rx_er[1]),
        .gmii_rxd_1(gmii_rxd[1]),
        .gmii_tx_clk_1(gmii_tx_clk[1]),
        .gmii_tx_en_1(gmii_tx_en[1]),
        .gmii_tx_er_1(gmii_tx_er[1]),
        .gmii_txd_1(gmii_txd[1]),
        
        // Port 2 - Infotainment
        .gmii_rx_clk_2(gmii_rx_clk[2]),
        .gmii_rx_dv_2(gmii_rx_dv[2]),
        .gmii_rx_er_2(gmii_rx_er[2]),
        .gmii_rxd_2(gmii_rxd[2]),
        .gmii_tx_clk_2(gmii_tx_clk[2]),
        .gmii_tx_en_2(gmii_tx_en[2]),
        .gmii_tx_er_2(gmii_tx_er[2]),
        .gmii_txd_2(gmii_txd[2]),
        
        // Port 3 - Diagnostics
        .gmii_rx_clk_3(gmii_rx_clk[3]),
        .gmii_rx_dv_3(gmii_rx_dv[3]),
        .gmii_rx_er_3(gmii_rx_er[3]),
        .gmii_rxd_3(gmii_rxd[3]),
        .gmii_tx_clk_3(gmii_tx_clk[3]),
        .gmii_tx_en_3(gmii_tx_en[3]),
        .gmii_tx_er_3(gmii_tx_er[3]),
        .gmii_txd_3(gmii_txd[3]),
        
        .cfg_clk(cfg_clk),
        .cfg_cs_n(cfg_cs_n),
        .cfg_mosi(cfg_mosi),
        .cfg_miso(cfg_miso),
        .cfg_int_n(cfg_int_n),
        
        .temp_sensor(temp_sensor),
        .voltage_sensor(voltage_sensor),
        
        .debug_leds(debug_leds),
        .test_mode(test_mode),
        .debug_uart_tx(debug_uart_tx),
        .debug_uart_rx(debug_uart_rx),
        
        .wake_on_lan(wake_on_lan),
        .power_good(power_good),
        .port_power_ctrl(port_power_ctrl),
        
        // DDR interface (not connected in testbench)
        .ddr_addr(),
        .ddr_ba(),
        .ddr_cas_n(),
        .ddr_ck_p(),
        .ddr_ck_n(),
        .ddr_cke(),
        .ddr_cs_n(),
        .ddr_dq(),
        .ddr_dqs_p(),
        .ddr_dqs_n(),
        .ddr_dm(),
        .ddr_odt(),
        .ddr_ras_n(),
        .ddr_reset_n(),
        .ddr_we_n()
    );
    
    /*
     * Clock Generation
     */
    initial begin
        clk_125mhz = 0;
        forever #(CLOCK_PERIOD/2) clk_125mhz = ~clk_125mhz;
    end
    
    initial begin
        clk_25mhz = 0;
        forever #(CLOCK_PERIOD*5/2) clk_25mhz = ~clk_25mhz;
    end
    
    initial begin
        clk_200mhz = 0;
        forever #(CLOCK_PERIOD*125/200/2) clk_200mhz = ~clk_200mhz;
    end
    
    // GMII clocks (125 MHz)
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_gmii_clks
            initial begin
                gmii_rx_clk[i] = 0;
                forever #(CLOCK_PERIOD/2) gmii_rx_clk[i] = ~gmii_rx_clk[i];
            end
        end
    endgenerate
    
    /*
     * Main Test Sequence
     */
    initial begin
        $display("=== Automotive TSN Switch System Testbench ===");
        $display("Simulating real automotive network scenarios");
        $display("Start time: %0t", $time);
        
        // Initialize
        initialize_system();
        
        // Wait for system ready
        wait_for_system_ready();
        
        // Configure automotive traffic patterns
        configure_automotive_scenarios();
        
        // Run automotive test scenarios
        $display("\n=== Running Automotive Test Scenarios ===");
        
        fork
            // Scenario 1: ADAS Camera Data (High bandwidth, low latency)
            automotive_scenario_adas_camera();
            
            // Scenario 2: Brake-by-Wire (Ultra-low latency, safety critical)
            automotive_scenario_brake_control();
            
            // Scenario 3: Infotainment (Best effort)
            automotive_scenario_infotainment();
            
            // Scenario 4: Diagnostics (Periodic, low priority)
            automotive_scenario_diagnostics();
            
            // Monitor system performance
            performance_monitor();
            
            // Environmental stress testing
            environmental_stress_test();
        join_any
        
        // Wait for all traffic to complete
        #100000;
        
        // Analyze results
        analyze_automotive_performance();
        
        $display("\n=== Automotive Test Complete ===");
        $finish;
    end
    
    /*
     * System Initialization
     */
    task initialize_system;
        begin
            $display("Initializing automotive TSN system...");
            
            // Reset all signals
            rst_n = 0;
            cfg_clk = 0;
            cfg_cs_n = 1;
            cfg_mosi = 0;
            temp_sensor = 12'd1024;    // ~25°C
            voltage_sensor = 12'd2730; // ~3.3V
            test_mode = 4'h0;
            debug_uart_rx = 1;
            wake_on_lan = 0;
            
            // Initialize GMII interfaces
            for (integer p = 0; p < 4; p = p + 1) begin
                gmii_rx_dv[p] = 0;
                gmii_rx_er[p] = 0;
                gmii_rxd[p] = 8'h0;
                frame_count[p] = 0;
                dropped_frame_count[p] = 0;
                throughput_measurements[p] = 0.0;
            end
            
            latency_index = 0;
            critical_frame_index = 0;
            
            // Release reset
            #(CLOCK_PERIOD * 20);
            rst_n = 1;
            #(CLOCK_PERIOD * 10);
            
            $display("System initialization complete");
        end
    endtask
    
    /*
     * Wait for System Ready
     */
    task wait_for_system_ready;
        begin
            $display("Waiting for system ready...");
            
            // Wait for power good
            wait(power_good);
            
            // Wait for PTP synchronization (simplified)
            #(CLOCK_PERIOD * 1000);
            
            $display("System ready at time %0t", $time);
        end
    endtask
    
    /*
     * Configure Automotive Scenarios
     */
    task configure_automotive_scenarios;
        begin
            $display("Configuring automotive traffic scenarios...");
            
            // Port 0: ADAS Camera - High bandwidth, Class SR-A
            traffic_enable[0] = 1;
            traffic_priority[0] = 3'd6;    // High priority
            traffic_interval[0] = 16'd125; // 8kHz frame rate (125µs)
            frame_size[0] = 16'd1518;      // Large frames
            
            // Port 1: Brake Control - Ultra-low latency, Class SR-A
            traffic_enable[1] = 1;
            traffic_priority[1] = 3'd7;    // Highest priority
            traffic_interval[1] = 16'd1250; // 800Hz (1.25ms)
            frame_size[1] = 16'd64;        // Small control frames
            
            // Port 2: Infotainment - Best effort
            traffic_enable[2] = 1;
            traffic_priority[2] = 3'd1;    // Low priority
            traffic_interval[2] = 16'd10000; // 100Hz (10ms)
            frame_size[2] = 16'd512;       // Medium frames
            
            // Port 3: Diagnostics - Low priority, periodic
            traffic_enable[3] = 1;
            traffic_priority[3] = 3'd0;    // Lowest priority
            traffic_interval[3] = 16'd125000; // 8Hz (125ms)
            frame_size[3] = 16'd256;       // Small diagnostic frames
            
            $display("Automotive scenarios configured");
        end
    endtask
    
    /*
     * Automotive Scenario: ADAS Camera Data
     */
    task automotive_scenario_adas_camera;
        integer frame_num;
        time start_time, end_time;
        begin
            $display("Starting ADAS Camera scenario on Port 0");
            
            frame_num = 0;
            while ($time < (SIM_TIME_LIMIT - 50000)) begin
                start_time = $time;
                
                // Generate ADAS camera frame
                send_automotive_frame(
                    0,                          // Port 0
                    48'h00_1B_19_CA_00_01,     // Camera MAC
                    48'h00_1B_19_EC_00_01,     // ECU MAC
                    16'h0800,                   // IPv4
                    1,                          // VLAN present
                    12'h100,                    // VLAN 256 (Camera)
                    traffic_priority[0],        // Priority 6
                    frame_size[0],              // 1518 bytes
                    frame_num                   // Sequence number
                );
                
                end_time = $time;
                
                // Record performance metrics
                if (latency_index < 999) begin
                    latency_measurements[latency_index] = end_time - start_time;
                    latency_index = latency_index + 1;
                end
                
                frame_count[0] = frame_count[0] + 1;
                frame_num = frame_num + 1;
                
                // Wait for next frame interval
                #(traffic_interval[0] * CLOCK_PERIOD);
            end
            
            $display("ADAS Camera scenario completed: %0d frames", frame_count[0]);
        end
    endtask
    
    /*
     * Automotive Scenario: Brake-by-Wire Control
     */
    task automotive_scenario_brake_control;
        integer frame_num;
        time start_time, end_time;
        real latency_ns;
        begin
            $display("Starting Brake Control scenario on Port 1");
            
            frame_num = 0;
            while ($time < (SIM_TIME_LIMIT - 50000)) begin
                start_time = $time;
                
                // Generate brake control frame (safety-critical)
                send_automotive_frame(
                    1,                          // Port 1
                    48'h00_1B_19_BR_00_01,     // Brake controller MAC
                    48'h00_1B_19_EC_00_01,     // ECU MAC
                    16'h88CC,                   // Custom automotive protocol
                    1,                          // VLAN present
                    12'h001,                    // VLAN 1 (Safety critical)
                    traffic_priority[1],        // Priority 7 (highest)
                    frame_size[1],              // 64 bytes
                    frame_num                   // Sequence number
                );
                
                end_time = $time;
                latency_ns = end_time - start_time;
                
                // Check critical latency requirement
                if (latency_ns > CRITICAL_LATENCY_MAX) begin
                    $error("CRITICAL: Brake control latency exceeded: %.1f ns > %0d ns", 
                           latency_ns, CRITICAL_LATENCY_MAX);
                end
                
                // Store critical frame timing
                if (critical_frame_index < 99) begin
                    critical_frame_times[critical_frame_index] = latency_ns;
                    critical_frame_index = critical_frame_index + 1;
                end
                
                frame_count[1] = frame_count[1] + 1;
                frame_num = frame_num + 1;
                
                // Wait for next control interval
                #(traffic_interval[1] * CLOCK_PERIOD);
            end
            
            $display("Brake Control scenario completed: %0d frames", frame_count[1]);
        end
    endtask
    
    /*
     * Automotive Scenario: Infotainment Traffic
     */
    task automotive_scenario_infotainment;
        integer frame_num;
        begin
            $display("Starting Infotainment scenario on Port 2");
            
            frame_num = 0;
            while ($time < (SIM_TIME_LIMIT - 50000)) begin
                // Generate infotainment frame
                send_automotive_frame(
                    2,                          // Port 2
                    48'h00_1B_19_IF_00_01,     // Infotainment MAC
                    48'h00_1B_19_EC_00_01,     // ECU MAC
                    16'h0800,                   // IPv4
                    1,                          // VLAN present
                    12'h200,                    // VLAN 512 (Infotainment)
                    traffic_priority[2],        // Priority 1
                    frame_size[2],              // 512 bytes
                    frame_num                   // Sequence number
                );
                
                frame_count[2] = frame_count[2] + 1;
                frame_num = frame_num + 1;
                
                #(traffic_interval[2] * CLOCK_PERIOD);
            end
            
            $display("Infotainment scenario completed: %0d frames", frame_count[2]);
        end
    endtask
    
    /*
     * Automotive Scenario: Diagnostic Traffic
     */
    task automotive_scenario_diagnostics;
        integer frame_num;
        begin
            $display("Starting Diagnostics scenario on Port 3");
            
            frame_num = 0;
            while ($time < (SIM_TIME_LIMIT - 50000)) begin
                // Generate diagnostic frame
                send_automotive_frame(
                    3,                          // Port 3
                    48'h00_1B_19_DG_00_01,     // Diagnostic tool MAC
                    48'h00_1B_19_EC_00_01,     // ECU MAC
                    16'h0800,                   // IPv4
                    1,                          // VLAN present
                    12'h300,                    // VLAN 768 (Diagnostics)
                    traffic_priority[3],        // Priority 0
                    frame_size[3],              // 256 bytes
                    frame_num                   // Sequence number
                );
                
                frame_count[3] = frame_count[3] + 1;
                frame_num = frame_num + 1;
                
                #(traffic_interval[3] * CLOCK_PERIOD);
            end
            
            $display("Diagnostics scenario completed: %0d frames", frame_count[3]);
        end
    endtask
    
    /*
     * Performance Monitor
     */
    task performance_monitor;
        real total_throughput;
        integer total_frames;
        begin
            $display("Starting performance monitoring...");
            
            while ($time < (SIM_TIME_LIMIT - 10000)) begin
                #(CLOCK_PERIOD * 12500); // Check every 100µs
                
                // Calculate instantaneous throughput
                total_frames = 0;
                for (integer p = 0; p < 4; p = p + 1) begin
                    total_frames = total_frames + frame_count[p];
                end
                
                // Check for LED status changes
                if (debug_leds[7:6] != 2'b11) begin
                    $warning("PTP synchronization issue detected");
                end
                
                // Monitor critical alarms
                if (!cfg_int_n) begin
                    $warning("System interrupt detected at time %0t", $time);
                end
            end
            
            $display("Performance monitoring completed");
        end
    endtask
    
    /*
     * Environmental Stress Test
     */
    task environmental_stress_test;
        begin
            $display("Starting environmental stress test...");
            
            // Temperature variation test
            #(CLOCK_PERIOD * 50000);
            temp_sensor = 12'd1400;  // ~40°C
            
            #(CLOCK_PERIOD * 50000);
            temp_sensor = 12'd700;   // ~10°C
            
            #(CLOCK_PERIOD * 50000);
            temp_sensor = 12'd1800;  // ~60°C
            
            // Voltage variation test
            #(CLOCK_PERIOD * 50000);
            voltage_sensor = 12'd2500; // 3.0V (low)
            
            #(CLOCK_PERIOD * 50000);
            voltage_sensor = 12'd2900; // 3.5V (high)
            
            #(CLOCK_PERIOD * 50000);
            voltage_sensor = 12'd2730; // 3.3V (nominal)
            temp_sensor = 12'd1024;     // 25°C (nominal)
            
            $display("Environmental stress test completed");
        end
    endtask
    
    /*
     * Send Automotive Frame
     */
    task send_automotive_frame(
        input integer port,
        input [47:0] src_mac,
        input [47:0] dst_mac,
        input [15:0] ethertype,
        input vlan_present,
        input [11:0] vlan_id,
        input [2:0] priority,
        input [15:0] length,
        input integer seq_num
    );
        
        reg [7:0] frame_data [0:1535];
        integer idx, payload_len, i;
        
        begin
            idx = 0;
            
            // Preamble and SFD
            for (i = 0; i < 7; i = i + 1) begin
                frame_data[idx] = 8'h55; idx = idx + 1;
            end
            frame_data[idx] = 8'hD5; idx = idx + 1;
            
            // Destination MAC
            frame_data[idx] = dst_mac[47:40]; idx = idx + 1;
            frame_data[idx] = dst_mac[39:32]; idx = idx + 1;
            frame_data[idx] = dst_mac[31:24]; idx = idx + 1;
            frame_data[idx] = dst_mac[23:16]; idx = idx + 1;
            frame_data[idx] = dst_mac[15:8];  idx = idx + 1;
            frame_data[idx] = dst_mac[7:0];   idx = idx + 1;
            
            // Source MAC
            frame_data[idx] = src_mac[47:40]; idx = idx + 1;
            frame_data[idx] = src_mac[39:32]; idx = idx + 1;
            frame_data[idx] = src_mac[31:24]; idx = idx + 1;
            frame_data[idx] = src_mac[23:16]; idx = idx + 1;
            frame_data[idx] = src_mac[15:8];  idx = idx + 1;
            frame_data[idx] = src_mac[7:0];   idx = idx + 1;
            
            // VLAN tag
            if (vlan_present) begin
                frame_data[idx] = 8'h81; idx = idx + 1;
                frame_data[idx] = 8'h00; idx = idx + 1;
                frame_data[idx] = {priority, 1'b0, vlan_id[11:8]}; idx = idx + 1;
                frame_data[idx] = vlan_id[7:0]; idx = idx + 1;
            end
            
            // EtherType
            frame_data[idx] = ethertype[15:8]; idx = idx + 1;
            frame_data[idx] = ethertype[7:0];  idx = idx + 1;
            
            // Payload with sequence number and automotive pattern
            payload_len = length - 18 - (vlan_present ? 4 : 0);
            
            // Add sequence number
            frame_data[idx] = seq_num[31:24]; idx = idx + 1;
            frame_data[idx] = seq_num[23:16]; idx = idx + 1;
            frame_data[idx] = seq_num[15:8];  idx = idx + 1;
            frame_data[idx] = seq_num[7:0];   idx = idx + 1;
            
            // Fill rest of payload
            for (i = 4; i < payload_len; i = i + 1) begin
                frame_data[idx] = (i + port) % 256;
                idx = idx + 1;
            end
            
            // CRC (simplified)
            frame_data[idx] = 8'hAA; idx = idx + 1;
            frame_data[idx] = 8'hBB; idx = idx + 1;
            frame_data[idx] = 8'hCC; idx = idx + 1;
            frame_data[idx] = 8'hDD; idx = idx + 1;
            
            // Send frame via GMII
            for (i = 0; i < idx; i = i + 1) begin
                @(posedge gmii_rx_clk[port]);
                gmii_rx_dv[port] = 1;
                gmii_rxd[port] = frame_data[i];
            end
            
            @(posedge gmii_rx_clk[port]);
            gmii_rx_dv[port] = 0;
            gmii_rxd[port] = 8'h00;
            
            // Inter-frame gap
            repeat(12) @(posedge gmii_rx_clk[port]);
        end
    endtask
    
    /*
     * Analyze Automotive Performance
     */
    task analyze_automotive_performance;
        real avg_latency, max_latency, min_latency;
        real critical_avg, critical_max;
        integer total_frames;
        begin
            $display("\n=== Automotive Performance Analysis ===");
            
            // Calculate total frames
            total_frames = 0;
            for (integer p = 0; p < 4; p = p + 1) begin
                total_frames = total_frames + frame_count[p];
                $display("Port %0d: %0d frames transmitted", p, frame_count[p]);
            end
            $display("Total frames: %0d", total_frames);
            
            // Analyze latency measurements
            if (latency_index > 0) begin
                avg_latency = 0;
                max_latency = 0;
                min_latency = latency_measurements[0];
                
                for (integer i = 0; i < latency_index; i = i + 1) begin
                    avg_latency = avg_latency + latency_measurements[i];
                    if (latency_measurements[i] > max_latency) 
                        max_latency = latency_measurements[i];
                    if (latency_measurements[i] < min_latency)
                        min_latency = latency_measurements[i];
                end
                avg_latency = avg_latency / latency_index;
                
                $display("\nLatency Analysis:");
                $display("  Average: %.2f ns", avg_latency);
                $display("  Maximum: %.2f ns", max_latency);
                $display("  Minimum: %.2f ns", min_latency);
            end
            
            // Analyze critical frame timing
            if (critical_frame_index > 0) begin
                critical_avg = 0;
                critical_max = 0;
                
                for (integer i = 0; i < critical_frame_index; i = i + 1) begin
                    critical_avg = critical_avg + critical_frame_times[i];
                    if (critical_frame_times[i] > critical_max)
                        critical_max = critical_frame_times[i];
                end
                critical_avg = critical_avg / critical_frame_index;
                
                $display("\nSafety-Critical Frame Analysis:");
                $display("  Average latency: %.2f ns", critical_avg);
                $display("  Maximum latency: %.2f ns", critical_max);
                $display("  Latency requirement: %0d ns", CRITICAL_LATENCY_MAX);
                
                if (critical_max <= CRITICAL_LATENCY_MAX) begin
                    $display("  ✓ PASSED: All critical frames met timing requirements");
                end else begin
                    $display("  ✗ FAILED: Critical timing requirement violated");
                end
            end
            
            // Performance summary
            $display("\n=== Performance Summary ===");
            $display("System Power: %s", power_good ? "GOOD" : "FAIL");
            $display("PTP Sync: %s", debug_leds[7] ? "LOCKED" : "NOT LOCKED");
            $display("TSN Active: %s", debug_leds[5] ? "YES" : "NO");
            
            // Final verdict
            if (critical_max <= CRITICAL_LATENCY_MAX && total_frames > 100) begin
                $display("\n*** AUTOMOTIVE TSN TEST PASSED ***");
                $display("System meets automotive safety and performance requirements");
            end else begin
                $display("\n*** AUTOMOTIVE TSN TEST FAILED ***");
                $display("System does not meet automotive requirements");
            end
        end
    endtask
    
    /*
     * Simulation Control
     */
    initial begin
        #SIM_TIME_LIMIT;
        $display("Simulation timeout at %0t", $time);
        $finish;
    end
    
    /*
     * Waveform Generation
     */
    initial begin
        $dumpfile("tb_automotive_tsn_system.vcd");
        $dumpvars(0, tb_automotive_tsn_system);
    end

endmodule
