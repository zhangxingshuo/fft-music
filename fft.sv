///////////////////////////////////////////////////////////
//
// ENGR155 Final Project
// fft.sv
//
// Created by: 
// Kitty Belling kbelling@hmc.edu
// Andy Zhang    axzhang@hmc.edu
// Date created: November 29, 2017
//
// Reads a square wave from an input pin and calculates the 
// frequency using a hardware fast Fourier transform. Outputs
// the most likely frequency bin through 16 LEDs.
//
///////////////////////////////////////////////////////////

module final_KBAZ(input  logic        clk, reset, data,
                  input  logic [3:0]  rows,
                  output logic        done,
                  output logic [15:0] leds,
                  output logic [3:0]  cols,
                  output logic [2:0]  song);
        
    // Create the 4.9 kHz clock for sampling and FFT      
    logic slowclk;      
    clkdiv div(clk, reset, slowclk);
        
    // FFT module
    fftcontroller control(slowclk, reset, data, done, leds);
        
    // Keypad scanner module
    keypad keypad(rows, clk, reset, cols, song);
        
endmodule


///////////////////////////////////////////////////////////
//
// FAST FOURIER TRANSFORM CONTROLLER
//
// Created by: 
// Andy Zhang    axzhang@hmc.edu
// Date created: November 29, 2017
//
// Samples the input data pin at approximately 4.9 kHz, and
// triggers FFT when sample data is completely loaded. Once
// FFT is done, calculates the maximum energy frequency bin 
// and decodes the bin into a one-hot encoding.
//
///////////////////////////////////////////////////////////

module fftcontroller(input  logic        clk, reset, data,
                     output logic        done,
                     output logic [15:0] leds);

    // Declare FFT signals
    logic               start, loadwrite;
    logic signed [15:0] datar, datai, gr, gi, hr, hi;
    logic        [5:0]  count;
    logic        [4:0]  loadadr, maxadr, adr;
    
    // Count up to 32 samples
    always_ff @ (posedge clk, posedge reset)
        if (reset)           count <= 0;
        else if (done)       count <= 0;
        else if (count < 33) count <= count + 1;    
         
    // Transform single bit input to 16 bit real data
    always_ff @ (posedge clk)
        if (data) datar <= 16'h03ff; // HIGH is 1023
        else      datar <= 16'hfc01; // LOW is -1024
    
    // Imaginary data is always 0
    assign datai = 16'h0000;
    
    // Write into FFT memory for 32 cycles, then pulse start
    assign loadwrite = (count < 32);
    assign loadadr   = count[4:0];
    assign start     = (count == 32);
    
    // FFT module
    fft fft(clk, reset, start, loadwrite, datar, datai, loadadr, done,
            gr, gi, hr, hi, maxadr);
              
    // Maximum frequency bin register
    always_ff @ (posedge clk, posedge reset)
        if (reset)     adr <= 4'd0;
        else if (done) adr <= maxadr;
         
    // Decode frequency into one-hot encoding for LEDs
    decoder dec(adr, leds);

endmodule


///////////////////////////////////////////////////////////
//
// HARDWARE FAST FOURIER TRANSFORM
//
// Created by: 
// Kitty Belling kbelling@hmc.edu
// Andy Zhang    axzhang@hmc.edu
// Date created: November 11, 2017
//
// Implements the Decimation-in-Time 32-point Fast Fourier
// Transform (FFT) using the Cooley-Tukey Radix-2 algorithm
// described in George Slade "The Fast Fourier Transform in 
// Hardware: A Tutorial Based on an FPGA Implementation" 
// (2013). Our implementation uses a two-cycle process to
// calculate the complex butterfly operation, as well as
// to read and write to a ping-pong memory module.
// 
// Link to paper: 
// https://www.researchgate.net/publication/235995761_The_Fast_Fourier_
// Transform_in_Hardware_A_Tutorial_Based_on_an_FPGA_Implementation
// 
///////////////////////////////////////////////////////////

module fft(input  logic               clk, reset, start, loadwrite,
           input  logic signed [15:0] datar, datai, 
           input  logic        [4:0]  loadadr, 
           output logic               done,
           output logic signed [15:0] gr, gi, hr, hi,
           output logic        [4:0]  maxadr);
                 
     // Declare signals for FFT
    logic signed [15:0] xr, xi, yr, yi, wre, wim, Are, Aim, Bre, Bim, memAre, memAim, memBre, memBim;
    logic        [4:0]  adra, adrb, twiddleAdr;
    logic               write, bank0write, bank1write, banksel, peaken, clear;
    
    // Address generator unit
    agu agu(clk, reset, start, adra, adrb, write, done, clear, twiddleAdr, banksel, peaken);
    
    // Ping-pong memory write signals
    assign bank0write =  banksel & write;
    assign bank1write = ~banksel & write;
    
    // Data memory unit
    mem mem(clk, loadwrite, bank0write, bank1write, banksel, 
            loadadr, adra, adrb, adra, adrb, 
            datar, datai, memAre, memAim, memBre, memBim, gr, gi, hr, hi);
    
    // Twiddle ROM
    twiddle twid(twiddleAdr, wre, wim);
    
    // Butterfly Unit
    bfu bfu(clk, gr, gi, hr, hi, wre, wim, Are, Aim, Bre, Bim);
     
     // On the last cycle of FFT, clear memory bank for next FFT calculation
     assign memAre = peaken ? 16'd0 : Are;
     assign memAim = peaken ? 16'd0 : Aim;
     assign memBre = peaken ? 16'd0 : Bre;
     assign memBim = peaken ? 16'd0 : Bim;
     
     // Calculate the most likely frequency bin
     peakfind peak(clk, reset, peaken, clear, adra, Are, Aim, maxadr);
    
endmodule


///////////////////////////////////////////////////////////
//
// BUTTERFLY UNIT
//
// Created by: 
// Kitty Belling kbelling@hmc.edu
// Andy Zhang    axzhang@hmc.edu
// Date created: November 11, 2017
//
// Computes the butterfly operation on two complex inputs
// and a complex twiddle factor.
// 
///////////////////////////////////////////////////////////

module bfu(input  logic               clk,
           input  logic signed [15:0] are, aim, bre, bim, wre, wim,
           output logic signed [15:0] Are, Aim, Bre, Bim);
              
    // Temporary multiplication results
    logic signed [35:0] muloutre, muloutim;
    
    assign muloutre = bre * wre - bim * wim;
    assign muloutim = bim * wre + bre * wim;
    
    // Take only bits 30:15, as specified in Slade 2013
    assign Are = are + muloutre[30:15];
    assign Aim = aim + muloutim[30:15];
    assign Bre = are - muloutre[30:15];
    assign Bim = aim - muloutim[30:15];
    
endmodule


///////////////////////////////////////////////////////////
//
// TWIDDLE LOOKUP TABLE
//
// Created by: 
// Kitty Belling kbelling@hmc.edu
// Date created: November 13, 2017
//
// Reads from a text file containing the twiddle factors,
// with the real components addressed first and the
// imaginary components addressed 16 bits offset.
// 
///////////////////////////////////////////////////////////

module twiddle(input  logic        [4:0]  adr,
               output logic signed [15:0] wre, wim);
    
    logic        [4:0]  adrIm;
    logic signed [15:0] twiddleTable[0:31];

    initial   $readmemh("twiddleTable.txt", twiddleTable);
  
    // Calculate imaginary component offset
    assign adrIm = adr + 5'd16; 
    
    assign wre = twiddleTable[adr];
    assign wim = twiddleTable[adrIm];
  
 endmodule


///////////////////////////////////////////////////////////
//
// DATA MEMORY
//
// Created by: 
// Kitty Belling kbelling@hmc.edu
// Andy Zhang    axzhang@hmc.edu
// Date created: November 18, 2017
//
// Implements the data memory module described in the Slade 
// 2013 hardware implementation of FFT. 
// Uses a ping-pong memory scheme to do efficient read-write 
// operations, and supports loading of real-time data.
// 
///////////////////////////////////////////////////////////

module mem(input  logic               clk, loadwrite, bank0write, bank1write, banksel,
           input  logic        [4:0]  loadadr, readgadr, readhadr, writegadr, writehadr,
           input  logic signed [15:0] datar, datai, xr, xi, yr, yi,
           output logic signed [15:0] gr, gi, hr, hi); 

     // Declare addresses, data, and write signals
    logic        [4:0]  adra0, adra1, adrb0, adrb1, flippedadr;
    logic signed [15:0] datainr, dataini, g0r, g0i, g1r, g1i, h0r, h0i, h1r, h1i;
    logic               bank0awrite, bank1awrite;

    // Write to Bank0A if loading data, or if writing to that block directly
    assign bank0awrite = loadwrite | bank0write;
    assign bank1awrite = bank1write;
     
    // Function for reversing the number of bits in a parallel bus.
    // See https://electronics.stackexchange.com/a/191125
    function [4:0] bitreverse (
        input [4:0] data
    );
         integer i;
         begin
              for (i=0; i < 5; i=i+1) begin : reverse
                    bitreverse[4-i] = data[i]; 
              end
         end
    endfunction
    
    // Load data in bit-reversed order 
    assign flippedadr = bitreverse(loadadr);

    // Multiplexers to choose the RAM address
    assign adra0 = loadwrite ? flippedadr : (bank0write ? writegadr : readgadr); 
    assign adrb0 = bank0write ? writehadr : readhadr;
    assign adra1 = bank1write ? writegadr : readgadr;
    assign adrb1 = bank1write ? writehadr : readhadr;

    // Multiplexer to choose BFU output or loading data
    assign datainr = loadwrite ? datar : xr;
    assign dataini = loadwrite ? datai : xi;

    // Ping-pong memory banks
    ram ram0r(clk, datainr, yr, adra0, adrb0, bank0awrite, bank0write, g0r, h0r);
    ram ram0i(clk, dataini, yi, adra0, adrb0, bank0awrite, bank0write, g0i, h0i);
    ram ram1r(clk, xr, yr, adra1, adrb1, bank1awrite, bank1write, g1r, h1r);
    ram ram1i(clk, xi, yi, adra1, adrb1, bank1awrite, bank1write, g1i, h1i);

    // Output multiplexer based on current FFT level from bankselect signal
    assign gr = banksel ? g1r : g0r;
    assign gi = banksel ? g1i : g0i;
    assign hr = banksel ? h1r : h0r;
    assign hi = banksel ? h1i : h0i;
     
endmodule


///////////////////////////////////////////////////////////
//
// TWO-PORT RANDOM ACCESS MEMORY
//
// Adapted from Altera software web page, "Verilog HDL:
// True Dual-Port RAM with a Single Clock".
// 
// Link to web page:
// https://www.altera.com/support/support-resources/design-examples/
// design-software/verilog/ver-true-dual-port-ram-sclk.html
//
///////////////////////////////////////////////////////////

module ram(input  logic               clk,
           input  logic signed [15:0] data_a, data_b,
           input  logic        [4:0]  addr_a, addr_b,
           input  logic               we_a, we_b,
           output logic signed [15:0] q_a, q_b);
    
    // Declare the RAM variable
    logic [15:0] ram[0:31];
    
    // Port A
    always @ (posedge clk) begin
        if (we_a) begin
            ram[addr_a] <= data_a;
            q_a         <= data_a;
        end
        else begin
            q_a         <= ram[addr_a];
        end
    end
    
    // Port B
    always @ (posedge clk) begin
        if (we_b) begin
            ram[addr_b] <= data_b;
            q_b         <= data_b;
        end
        else begin
            q_b         <= ram[addr_b];
        end
    end
    
endmodule


///////////////////////////////////////////////////////////
//
// ADDRESS GENERATION UNIT
//
// Created by: 
// Kitty Belling kbelling@hmc.edu
// Andy Zhang    axzhang@hmc.edu
// Date created: November 16, 2017
//
// Implements the address generating unit described in Slade 
// 2013 hardware implementation of FFT. 
// Uses a finite state machine to iterate through the FFT 
// levels and calculate the address pairs, as well as determine 
// when to write to which memory block.
//
///////////////////////////////////////////////////////////

module agu(input  logic       clk, reset, start, 
           output logic [4:0] adra, adrb,  
           output logic       write, done, clear,
           output logic [4:0] twiddleAdr,
           output logic       banksel, peaken);
                
    // Declare states for FSM
    typedef enum logic [3:0] {WAIT, CLEAR, READ, WRITE, DONE} statetype;
    statetype state, nextstate;
    
    // i is outer loop index, j is inner loop index
    logic [2:0] i, next_i;
    logic [4:0] j, next_j, j_shift;
    
    // Next state register
    always_ff @ (posedge clk, posedge reset)
        if (reset) begin 
            state <= WAIT;
            i     <= 0;
            j     <= 0;
        end 
        else if (clear) begin 
            state <= nextstate;
            i     <= 0;
            j     <= 0;
        end 
        else begin 
            state <= nextstate;
            i     <= next_i;
            j     <= next_j;
        end
         
    // Next state logic
    always_comb
        case(state)
            WAIT: if (start)              nextstate = CLEAR;
                  else                    nextstate = WAIT;
            CLEAR:                        nextstate = READ;
            READ:                         nextstate = WRITE;
            WRITE: if (i == 4 && j == 15) nextstate = DONE;
                   else                   nextstate = READ;
            DONE:                         nextstate = WAIT;
        endcase 
        
    // Increment logic
    always_comb
        case(state)
            WRITE: // Only increment in WRITE state
                begin 
                    if (j == 15) begin
                        next_j = 0;
                        next_i = i + 1;
                    end 
                    else begin
                        next_j = j + 1;
                        next_i = i;
                    end 
                end 
            default: 
                begin
                    next_i = i;
                    next_j = j;
                end
        endcase 
    
    // Calculate addresses using algorithm outlined in paper
    assign j_shift    = j << 1;
    assign adra       = (j_shift << i) | (j_shift >> (5 - i));
    assign adrb       = ((j_shift + 1) << i) | ((j_shift + 1) >> (5 - i));
    assign twiddleAdr = (32'hfffffff0 >> i) & j;
                     
    // Output signals based on state 
    assign write = (state == WRITE);
    assign done  = (state == DONE);
    assign clear = (state == CLEAR);
    
    // Enable max finding on the last cycle of FFT
    assign peaken = (state == WRITE && i == 4);
    
    // Switch read and write banks every cycle for ping-pong memory
    assign banksel = i[0];
    
endmodule


///////////////////////////////////////////////////////////
//
// PEAK FINDING MODULE
//
// Created by: 
// Andy Zhang    axzhang@hmc.edu
// Date created: November 24, 2017
//
// Iterates through the results of the last block of FFT and 
// calculates the bin with the highest energy. This bin is
// the most likely frequency range.
//
///////////////////////////////////////////////////////////

module peakfind(input  logic               clk, reset, enable, clear,
                input  logic        [4:0]  adr,
                input  logic signed [15:0] re, im,
                output logic        [4:0]  maxadr);
    
    // Declare local maximum and intermediate result
    logic signed [31:0] maxresult, result;
    
    // Update the maximum value
    always_ff @ (posedge clk, posedge reset, posedge clear)
        if (reset | clear) begin 
            maxadr    <= 4'd0;
            maxresult <= 32'd0;
        end
        else if (enable && ~clear && result > maxresult) begin 
            maxadr    <= adr;
            maxresult <= result;
        end 
    
    // Calculate the intermediate result
    assign result = re*re + im*im;
                     
endmodule


///////////////////////////////////////////////////////////
//
// ADDRESS DECODER
//
// Created by: 
// Andy Zhang    axzhang@hmc.edu
// Date created: November 27, 2017
//
// Transforms a 5-bit address from the FFT module into a 
// 16-bit one-hot encoding to send to LEDs on the board.
//
///////////////////////////////////////////////////////////

module decoder(input  logic [4:0]  a,
               output logic [15:0] y);

    // Only use addresses less than 16
    assign y = (a < 16) ? (1 << a) : 16'd0;
                    
endmodule

///////////////////////////////////////////////////////////
//
// CLOCK DIVIDER
//
// Created by: 
// Andy Zhang    axzhang@hmc.edu
// Date created: November 27, 2017
//
// Uses the FPGA onboard clock of 40 MHz to create a slower
// clock for a samplng rate of 4.9 kHz for FFT.
//
///////////////////////////////////////////////////////////

module clkdiv(input  logic clk, reset,
              output logic slowclk);
                  
    logic [13:0] q; 
    always_ff @ (posedge clk, posedge reset)
       if (reset) q <= 0;
       else       q <= q + 1;
        
    assign slowclk = q[13];
    
endmodule


///////////////////////////////////////////////////////////
//
// KEYPAD MODULE
//
// Created by: 
// Kitty Belling kbelling@hmc.edu
// Date created: November 27, 2017
//
// Implements a scanner for a 4x4 keypad.
//
///////////////////////////////////////////////////////////

module keypad(input  logic [3:0] R,
              input  logic       clk, reset,
              output logic [3:0] C,
              output logic [2:0] song);
    
    // Create a new clock that will run the rest of the code.
    // This slower clock allows for values to stabilize before
    // the clock edges. 
    logic nclk;
    freqChange newClk(clk, reset, nclk);
    
    // Find out which button is being pressed. 
    logic [4:0] numbPressed;
    whichButtonPressed setNum(R, nclk, reset, C, numbPressed);
    
    // Hold number in a register; only change the number if
    // a new key is pressed.
    logic [4:0] oldNum;
    
    always_ff @ (posedge nclk, posedge reset)
        if (reset) begin 
            oldNum <= numbPressed; 
        end
        else if (oldNum !== numbPressed) begin
            oldNum = numbPressed;
        end
        else begin
            oldNum <= oldNum;
        end
        
    always_comb
        case(oldNum[3:0])
            4'b1110: song = 3'b000; //reset if * is played
            4'b0001: song = 3'b001; //song 1
            4'b0010: song = 3'b010; //song 2
            4'b0011: song = 3'b100; //song 3
            default: song = 3'b000; //nothing
        endcase
    
endmodule


///////////////////////////////////////////////////////////
//
// BUTTON DECODER
//
// Created by: 
// Kitty Belling kbelling@hmc.edu
// Date created: November 27, 2017
//
// Takes in the values of the rows, clock and reset and outputs
// and outputs the last number that has been pressed by setting
// the columns.
//
///////////////////////////////////////////////////////////

module whichButtonPressed(input  logic [3:0] R,
                          input  logic       clk, reset,
                          output logic [3:0] C,
                          output logic [4:0] numberPressed);
        
        logic [3:0] state, nextstate;
        
        assign C = state;
        
        logic [7:0] tracked, ntracked;
        
        always_ff @ (posedge clk, posedge reset)
            if (reset) begin 
                state   <= 4'b0000; 
                tracked <= 8'd0; 
            end 
            else begin 
                state   <= nextstate; 
                tracked <= ntracked; 
            end
        
        always_comb
            case(state)
                4'b0000: nextstate = 4'b0001;
                4'b0001: nextstate = 4'b0010;
                4'b0010: nextstate = 4'b0100;
                4'b0100: nextstate = 4'b1000;
                4'b1000: nextstate = 4'b0000;
                default: nextstate = 4'b0000;
            endcase

        always_comb
            case(state)
                4'b0001: if(|R)    ntracked = {R, C};
                         else      ntracked = tracked; 
                4'b0010: if(|R)    ntracked = {R, C};
                         else      ntracked = tracked;
                4'b0100: if(|R)    ntracked = {R, C}; 
                         else      ntracked = tracked; 
                4'b1000: if(|R)    ntracked = {R, C};
                         else      ntracked = tracked;
                default:           ntracked = tracked;
            endcase
        
        always_comb
            case(ntracked)
                8'b10000010: numberPressed = 5'd0;
                8'b00010001: numberPressed = 5'd1;
                8'b00010010: numberPressed = 5'd2;
                8'b00010100: numberPressed = 5'd3;
                8'b00100001: numberPressed = 5'd4;
                8'b00100010: numberPressed = 5'd5;
                8'b00100100: numberPressed = 5'd6;
                8'b01000001: numberPressed = 5'd7;
                8'b01000010: numberPressed = 5'd8;
                8'b01000100: numberPressed = 5'd9;
                8'b00011000: numberPressed = 5'd10;
                8'b00101000: numberPressed = 5'd11;
                8'b01001000: numberPressed = 5'd12;
                8'b10001000: numberPressed = 5'd13;
                8'b10000001: numberPressed = 5'd14;
                8'b10000100: numberPressed = 5'd15;
                default:     numberPressed = 5'd0;
            endcase
    
endmodule       


///////////////////////////////////////////////////////////
//
// CLOCK DIVIDER
//
// Created by: 
// Kitty Belling kbelling@hmc.edu
// Date created: November 27, 2017
//
// Takes in the clock, which has a frequency of 
// about 40 MHz, and output a new clock that has 
// a frequency of about 153 Hz. 
//
///////////////////////////////////////////////////////////

module freqChange(input  logic clk, reset,
                  output logic newclk);
        
    logic [18:0] q; 
    always_ff @ (posedge clk, posedge reset)
       if (reset) q <= 0;
       else       q <= q + 1;
        
    assign newclk = q[18];
    
endmodule
