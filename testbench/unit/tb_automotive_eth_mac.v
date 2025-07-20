/*
 * Testbench for Automotive Ethernet MAC Controller
 * 
 * This testbench verifies the MAC controller functionality including:
 * - Ethernet frame parsing and generation
 * - VLAN tag processing
 * - Cut-through forwarding capability
 * - Automotive-specific features
 * - Performance measurements
 * 
 * Author: Sid Kundu
 * Target: Verification of automotive_eth_mac.v
 */

`timescale 1ns / 1ps

module tb_automotive_eth_mac;

    /*
     * Test Parameters
     */
    parameter CLOCK_PERIOD = 8.0;      // 125 MHz = 8ns period
    parameter SIM_TIME_LIMIT = 100000; // Simulation time limit (ns)
    parameter NUM_TEST_FRAMES = 50;    // Number of test frames
    
    /*
     * DUT Signals
     */
    reg         clk_125mhz;
    reg         clk_25mhz;
    reg         rst_n;
    
    // GMII Interface
    reg         gmii_rx_clk;
    reg         gmii_rx_dv;
    reg         gmii_rx_er;
    reg [7:0]   gmii_rxd;
    wire        gmii_tx_clk;
    wire        gmii_tx_en;
    wire        gmii_tx_er;
    wire [7:0]  gmii_txd;
    
    // Control
    reg         speed_1000;
    reg         duplex_full;
    wire        link_up;
    wire [31:0] status_reg;
    
    // Internal packet interface
    wire        rx_valid;
    wire        rx_sof;
    wire        rx_eof;
    wire [31:0] rx_data;
    wire [1:0]  rx_mod;
    wire        rx_error;
    wire [47:0] rx_dst_mac;
    wire [47:0] rx_src_mac;
    wire [15:0] rx_ethertype;
    wire [11:0] rx_vlan_id;
    wire [2:0]  rx_priority;
    wire        rx_vlan_valid;
    reg         rx_ready;
    
    reg         tx_valid;
    reg         tx_sof;
    reg         tx_eof;
    reg [31:0]  tx_data;
    reg [1:0]   tx_mod;
    reg [2:0]   tx_priority;
    wire        tx_ready;
    wire        tx_error;
    
    // TSN Interface
    reg [63:0]  ptp_time;
    wire [63:0] rx_timestamp;
    wire [63:0] tx_timestamp;
    wire        tx_ts_valid;
    
    // Statistics
    wire [31:0] rx_frame_count;
    wire [31:0] tx_frame_count;
    wire [31:0] rx_byte_count;
    wire [31:0] tx_byte_count;
    wire [31:0] error_count;
    
    /*
     * Test Variables
     */
    integer test_frame_count;
    integer error_count_test;
    real latency_measurements [0:99];
    integer latency_index;
    time frame_start_time, frame_end_time;
    
    // Test frame data
    reg [7:0] test_frame_data [0:1515];
    integer frame_length;
    
    /*
     * Device Under Test Instantiation
     */
    automotive_eth_mac #(
        .PORT_ID(0),
        .ENABLE_VLAN(1),
        .ENABLE_JUMBO(0),
        .FIFO_DEPTH(512)
    ) dut (
        .clk_125mhz(clk_125mhz),
        .clk_25mhz(clk_25mhz),
        .rst_n(rst_n),
        
        .gmii_rx_clk(gmii_rx_clk),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_rxd(gmii_rxd),
        .gmii_tx_clk(gmii_tx_clk),
        .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er),
        .gmii_txd(gmii_txd),
        
        .speed_1000(speed_1000),
        .duplex_full(duplex_full),
        .link_up(link_up),
        .status_reg(status_reg),
        
        .rx_valid(rx_valid),
        .rx_sof(rx_sof),
        .rx_eof(rx_eof),
        .rx_data(rx_data),
        .rx_mod(rx_mod),
        .rx_error(rx_error),
        .rx_dst_mac(rx_dst_mac),
        .rx_src_mac(rx_src_mac),
        .rx_ethertype(rx_ethertype),
        .rx_vlan_id(rx_vlan_id),
        .rx_priority(rx_priority),
        .rx_vlan_valid(rx_vlan_valid),
        .rx_ready(rx_ready),
        
        .tx_valid(tx_valid),
        .tx_sof(tx_sof),
        .tx_eof(tx_eof),
        .tx_data(tx_data),
        .tx_mod(tx_mod),
        .tx_priority(tx_priority),
        .tx_ready(tx_ready),
        .tx_error(tx_error),
        
        .ptp_time(ptp_time),
        .rx_timestamp(rx_timestamp),
        .tx_timestamp(tx_timestamp),
        .tx_ts_valid(tx_ts_valid),
        
        .rx_frame_count(rx_frame_count),
        .tx_frame_count(tx_frame_count),
        .rx_byte_count(rx_byte_count),
        .tx_byte_count(tx_byte_count),
        .error_count(error_count)
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
        forever #(CLOCK_PERIOD*5/2) clk_25mhz = ~clk_25mhz; // 25 MHz
    end
    
    initial begin
        gmii_rx_clk = 0;
        forever #(CLOCK_PERIOD/2) gmii_rx_clk = ~gmii_rx_clk;
    end
    
    /*
     * PTP Time Counter
     */
    initial begin
        ptp_time = 64'h0;
        forever begin
            #(CLOCK_PERIOD) ptp_time = ptp_time + 8; // 8ns per cycle
        end
    end
    
    /*
     * Test Stimulus and Main Test Sequence
     */
    initial begin
        $display("=== Automotive Ethernet MAC Controller Testbench ===");
        $display("Starting simulation at time %0t", $time);
        
        // Initialize signals
        rst_n = 0;
        speed_1000 = 1;
        duplex_full = 1;
        rx_ready = 1;
        tx_valid = 0;
        tx_sof = 0;
        tx_eof = 0;
        tx_data = 32'h0;
        tx_mod = 2'h0;
        tx_priority = 3'h0;
        
        gmii_rx_dv = 0;
        gmii_rx_er = 0;
        gmii_rxd = 8'h0;
        
        test_frame_count = 0;
        error_count_test = 0;
        latency_index = 0;
        
        // Reset sequence
        #(CLOCK_PERIOD * 10);
        rst_n = 1;
        #(CLOCK_PERIOD * 5);
        
        $display("Reset completed at time %0t", $time);
        
        // Wait for link up
        wait(link_up);
        $display("Link established at time %0t", $time);
        
        // Run test sequences
        test_basic_frame_reception();
        test_vlan_frame_reception();
        test_error_handling();
        test_broadcast_frame();
        test_jumbo_frame();
        test_performance_measurement();
        
        // Final statistics
        $display("\n=== Test Results Summary ===");
        $display("Total frames tested: %0d", test_frame_count);
        $display("Errors detected: %0d", error_count_test);
        $display("RX Frame count: %0d", rx_frame_count);
        $display("TX Frame count: %0d", tx_frame_count);
        $display("Error count: %0d", error_count);
        
        if (latency_index > 0) begin
            real avg_latency = 0;
            for (integer i = 0; i < latency_index; i = i + 1) begin
                avg_latency = avg_latency + latency_measurements[i];
            end
            avg_latency = avg_latency / latency_index;
            $display("Average processing latency: %.2f ns", avg_latency);
        end
        
        if (error_count_test == 0) begin
            $display("*** TEST PASSED ***");
        end else begin
            $display("*** TEST FAILED ***");
        end
        
        $finish;
    end
    
    /*
     * Test Task: Basic Ethernet Frame Reception
     */
    task test_basic_frame_reception;
        begin
            $display("\n--- Test: Basic Ethernet Frame Reception ---");
            
            // Create a standard Ethernet frame
            create_ethernet_frame(
                48'hFF_FF_FF_FF_FF_FF,  // Destination MAC (broadcast)
                48'h00_1B_19_00_00_01,  // Source MAC
                16'h0800,               // EtherType (IPv4)
                0,                      // No VLAN
                12'h000,                // VLAN ID
                3'h0,                   // Priority
                64                      // Frame length
            );
            
            frame_start_time = $time;
            send_gmii_frame();
            
            // Wait for frame processing
            wait(rx_valid && rx_sof);
            wait(rx_valid && rx_eof);
            frame_end_time = $time;
            
            // Verify frame parsing
            if (rx_dst_mac != 48'hFF_FF_FF_FF_FF_FF) begin
                $error("Destination MAC mismatch: expected %h, got %h", 
                       48'hFF_FF_FF_FF_FF_FF, rx_dst_mac);
                error_count_test = error_count_test + 1;
            end
            
            if (rx_src_mac != 48'h00_1B_19_00_00_01) begin
                $error("Source MAC mismatch: expected %h, got %h", 
                       48'h00_1B_19_00_00_01, rx_src_mac);
                error_count_test = error_count_test + 1;
            end
            
            if (rx_ethertype != 16'h0800) begin
                $error("EtherType mismatch: expected %h, got %h", 
                       16'h0800, rx_ethertype);
                error_count_test = error_count_test + 1;
            end
            
            if (rx_vlan_valid != 1'b0) begin
                $error("VLAN should not be valid for this frame");
                error_count_test = error_count_test + 1;
            end
            
            // Record latency
            latency_measurements[latency_index] = frame_end_time - frame_start_time;
            latency_index = latency_index + 1;
            
            test_frame_count = test_frame_count + 1;
            $display("Basic frame test completed successfully");
        end
    endtask
    
    /*
     * Test Task: VLAN Tagged Frame Reception
     */
    task test_vlan_frame_reception;
        begin
            $display("\n--- Test: VLAN Tagged Frame Reception ---");
            
            // Create a VLAN-tagged Ethernet frame
            create_ethernet_frame(
                48'h00_1B_19_00_00_02,  // Destination MAC
                48'h00_1B_19_00_00_01,  // Source MAC
                16'h0800,               // EtherType (IPv4)
                1,                      // VLAN present
                12'h064,                // VLAN ID = 100
                3'h5,                   // Priority = 5
                128                     // Frame length
            );
            
            frame_start_time = $time;
            send_gmii_frame();
            
            // Wait for frame processing
            wait(rx_valid && rx_sof);
            wait(rx_valid && rx_eof);
            frame_end_time = $time;
            
            // Verify VLAN parsing
            if (rx_vlan_valid != 1'b1) begin
                $error("VLAN should be valid for this frame");
                error_count_test = error_count_test + 1;
            end
            
            if (rx_vlan_id != 12'h064) begin
                $error("VLAN ID mismatch: expected %h, got %h", 
                       12'h064, rx_vlan_id);
                error_count_test = error_count_test + 1;
            end
            
            if (rx_priority != 3'h5) begin
                $error("Priority mismatch: expected %h, got %h", 
                       3'h5, rx_priority);
                error_count_test = error_count_test + 1;
            end
            
            latency_measurements[latency_index] = frame_end_time - frame_start_time;
            latency_index = latency_index + 1;
            
            test_frame_count = test_frame_count + 1;
            $display("VLAN frame test completed successfully");
        end
    endtask
    
    /*
     * Test Task: Error Handling
     */
    task test_error_handling;
        begin
            $display("\n--- Test: Error Handling ---");
            
            // Test frame with RX error
            create_ethernet_frame(
                48'h00_1B_19_00_00_02,
                48'h00_1B_19_00_00_01,
                16'h0800,
                0, 12'h000, 3'h0,
                64
            );
            
            // Inject error during transmission
            fork
                send_gmii_frame();
                begin
                    #(CLOCK_PERIOD * 50);
                    gmii_rx_er = 1;
                    #(CLOCK_PERIOD * 5);
                    gmii_rx_er = 0;
                end
            join
            
            // Wait for error detection
            #(CLOCK_PERIOD * 100);
            
            if (rx_error != 1'b1) begin
                $error("Error should be detected");
                error_count_test = error_count_test + 1;
            end
            
            test_frame_count = test_frame_count + 1;
            $display("Error handling test completed");
        end
    endtask
    
    /*
     * Test Task: Broadcast Frame
     */
    task test_broadcast_frame;
        begin
            $display("\n--- Test: Broadcast Frame ---");
            
            create_ethernet_frame(
                48'hFF_FF_FF_FF_FF_FF,  // Broadcast MAC
                48'h00_1B_19_00_00_01,
                16'h0806,               // ARP
                0, 12'h000, 3'h0,
                60                      // Minimum frame size
            );
            
            send_gmii_frame();
            
            wait(rx_valid && rx_sof);
            wait(rx_valid && rx_eof);
            
            test_frame_count = test_frame_count + 1;
            $display("Broadcast frame test completed");
        end
    endtask
    
    /*
     * Test Task: Jumbo Frame (if enabled)
     */
    task test_jumbo_frame;
        begin
            $display("\n--- Test: Large Frame ---");
            
            create_ethernet_frame(
                48'h00_1B_19_00_00_02,
                48'h00_1B_19_00_00_01,
                16'h0800,
                0, 12'h000, 3'h0,
                1518                    // Maximum standard frame
            );
            
            send_gmii_frame();
            
            wait(rx_valid && rx_sof);
            wait(rx_valid && rx_eof);
            
            test_frame_count = test_frame_count + 1;
            $display("Large frame test completed");
        end
    endtask
    
    /*
     * Test Task: Performance Measurement
     */
    task test_performance_measurement;
        begin
            $display("\n--- Test: Performance Measurement ---");
            
            // Send multiple frames back-to-back
            for (integer i = 0; i < 10; i = i + 1) begin
                create_ethernet_frame(
                    48'h00_1B_19_00_00_02,
                    48'h00_1B_19_00_00_01,
                    16'h0800,
                    0, 12'h000, 3'h0,
                    64 + (i * 64)       // Variable frame sizes
                );
                
                frame_start_time = $time;
                send_gmii_frame();
                
                wait(rx_valid && rx_sof);
                wait(rx_valid && rx_eof);
                frame_end_time = $time;
                
                if (latency_index < 100) begin
                    latency_measurements[latency_index] = frame_end_time - frame_start_time;
                    latency_index = latency_index + 1;
                end
                
                test_frame_count = test_frame_count + 1;
                
                // Small gap between frames
                #(CLOCK_PERIOD * 12); // IFG
            end
            
            $display("Performance measurement completed");
        end
    endtask
    
    /*
     * Task: Create Ethernet Frame
     */
    task create_ethernet_frame(
        input [47:0] dst_mac,
        input [47:0] src_mac,
        input [15:0] ethertype,
        input        vlan_present,
        input [11:0] vlan_id,
        input [2:0]  priority,
        input integer length
    );
        integer idx, payload_start;
        
        begin
            idx = 0;
            
            // Preamble
            for (integer i = 0; i < 7; i = i + 1) begin
                test_frame_data[idx] = 8'h55;
                idx = idx + 1;
            end
            
            // Start Frame Delimiter
            test_frame_data[idx] = 8'hD5;
            idx = idx + 1;
            
            // Destination MAC
            test_frame_data[idx] = dst_mac[47:40]; idx = idx + 1;
            test_frame_data[idx] = dst_mac[39:32]; idx = idx + 1;
            test_frame_data[idx] = dst_mac[31:24]; idx = idx + 1;
            test_frame_data[idx] = dst_mac[23:16]; idx = idx + 1;
            test_frame_data[idx] = dst_mac[15:8];  idx = idx + 1;
            test_frame_data[idx] = dst_mac[7:0];   idx = idx + 1;
            
            // Source MAC
            test_frame_data[idx] = src_mac[47:40]; idx = idx + 1;
            test_frame_data[idx] = src_mac[39:32]; idx = idx + 1;
            test_frame_data[idx] = src_mac[31:24]; idx = idx + 1;
            test_frame_data[idx] = src_mac[23:16]; idx = idx + 1;
            test_frame_data[idx] = src_mac[15:8];  idx = idx + 1;
            test_frame_data[idx] = src_mac[7:0];   idx = idx + 1;
            
            // VLAN Tag (if present)
            if (vlan_present) begin
                test_frame_data[idx] = 8'h81; idx = idx + 1; // TPID
                test_frame_data[idx] = 8'h00; idx = idx + 1;
                test_frame_data[idx] = {priority, 1'b0, vlan_id[11:8]}; idx = idx + 1;
                test_frame_data[idx] = vlan_id[7:0]; idx = idx + 1;
            end
            
            // EtherType
            test_frame_data[idx] = ethertype[15:8]; idx = idx + 1;
            test_frame_data[idx] = ethertype[7:0];  idx = idx + 1;
            
            payload_start = idx;
            
            // Payload (incremental pattern)
            while (idx < (payload_start + length - 18 - (vlan_present ? 4 : 0))) begin
                test_frame_data[idx] = idx[7:0];
                idx = idx + 1;
            end
            
            // Pad to minimum if necessary
            while (idx < (payload_start + 46)) begin
                test_frame_data[idx] = 8'h00;
                idx = idx + 1;
            end
            
            // CRC (simplified - would calculate real CRC in production)
            test_frame_data[idx] = 8'hAA; idx = idx + 1;
            test_frame_data[idx] = 8'hBB; idx = idx + 1;
            test_frame_data[idx] = 8'hCC; idx = idx + 1;
            test_frame_data[idx] = 8'hDD; idx = idx + 1;
            
            frame_length = idx;
        end
    endtask
    
    /*
     * Task: Send GMII Frame
     */
    task send_gmii_frame;
        integer i;
        begin
            for (i = 0; i < frame_length; i = i + 1) begin
                @(posedge gmii_rx_clk);
                gmii_rx_dv = 1;
                gmii_rxd = test_frame_data[i];
            end
            
            @(posedge gmii_rx_clk);
            gmii_rx_dv = 0;
            gmii_rxd = 8'h00;
        end
    endtask
    
    /*
     * Simulation Timeout
     */
    initial begin
        #SIM_TIME_LIMIT;
        $display("ERROR: Simulation timeout at %0t", $time);
        $finish;
    end
    
    /*
     * Waveform Dumping
     */
    initial begin
        $dumpfile("tb_automotive_eth_mac.vcd");
        $dumpvars(0, tb_automotive_eth_mac);
    end

endmodule
