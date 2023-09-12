`timescale 10ns / 1ns
module tb;

// ---------------------------------------------------------------------
reg clock;
reg clock_25;
reg clock_50;
reg reset_n;

always #0.5 clock    = ~clock;
always #1.0 clock_50 = ~clock_50;
always #2.0 clock_25 = ~clock_25;
// ---------------------------------------------------------------------
initial begin reset_n = 0; clock = 1; clock_25 = 0; clock_50 = 0; #3.5 reset_n = 1; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
initial begin $readmemh("tb.hex", pgm); end
// ---------------------------------------------------------------------
reg  [15:0] pgm[65536];
reg  [ 7:0] mem[128*1024];

always @(posedge clock) begin

    ir      <= pgm[pc];
    data_i  <= mem[address];

    if (we) mem[address] <= data_o;

end

// Роутер памяти и портов
wire [ 7:0] in =
    address == 16'h2C ? sd_din      :
    address == 16'h2D ? {sd_timeout, sd_busy} :
                        data_i;

// ---------------------------------------------------------------------

reg         intr = 1'b0;
reg  [ 2:0] vect = 3'h0;
wire [15:0] pc, address;
reg  [15:0] ir;
reg  [ 7:0] data_i;
wire [ 7:0] data_o, sdram_out;
wire        we, read, mreq, ce;
wire        clk_out;
wire [26:0] sdram_address = address;

core COREAVR
(
    .clock      (clock_25),
    .reset_n    (reset_n),
    .ce         (ce),
    // Программная память
    .pc         (pc),           // Программный счетчик
    .ir         (ir),          // Инструкция из памяти
    // Оперативная память
    .address    (address),      // Указатель на память RAM (sram)
    .data_i     (in),           // = memory[ address ]
    .data_o     (data_o),       // Запись в память по address
    .read       (read),         // Чтение из памяти
    .we         (we),           // Разрешение записи в память
    // Внешнее прерывание #0..7
    .intr       (intr),
    .vect       (vect)
);

// ---------------------------------------------------------------------
// ПОРТЫ
// ---------------------------------------------------------------------

always @(posedge clock_25)
begin

    sd_signal <= 0;

    if (we)
    case (address)

        16'h2C: begin sd_signal <= 1; sd_cmd <= 0;      sd_out <= data_o; end
        16'h2D: begin sd_signal <= 1; sd_cmd <= data_o; sd_out <= 8'hFF; end

    endcase

end

// ---------------------------------------------------------------------
// КОНТРОЛЛЕРЫ
// ---------------------------------------------------------------------

wire SD_CS, SD_CLK, SD_MOSI;
wire SD_MISO = 1'b1;
wire sd_busy, sd_timeout;

reg         sd_signal;
reg  [1:0]  sd_cmd;
reg  [7:0]  sd_out;
wire [7:0]  sd_din;

sd UnitSPI
(
    // 50 Mhz
    .clock      (clock_25),
    .reset_n    (reset_n),

    // Физический интерфейс
    .SPI_CS     (SD_CS),        // Выбор чипа
    .SPI_SCLK   (SD_CLK),       // Тактовая частота
    .SPI_MISO   (SD_MISO),      // Входящие данные
    .SPI_MOSI   (SD_MOSI),      // Исходящие

    // Ввод
    .sd_signal  (sd_signal),
    .sd_cmd     (sd_cmd),
    .sd_out     (sd_out),

    // Вывод
    .sd_din     (sd_din),
    .sd_busy    (sd_busy),
    .sd_timeout (sd_timeout)
);

// ---------------------------------------------------------------------
// SDRAM
// ---------------------------------------------------------------------

sdram SDRAM
(
    // Физический интерфейс
    .reset_n        (reset_n),
    .clock          (clock_50),
    .clk_hi         (clock),
    .dram_clk       (clk_out),

    // Сигналы от процессора
    .clk_cpu        (clock_25),
    .ce             (ce),
    .address        (sdram_address),
    .in             (data_o),
    .out            (sdram_out),
    .mreq           (1'b1),
    .read           (read),
    .write          (we)
);

endmodule
