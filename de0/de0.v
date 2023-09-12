module de0
(
    // Reset
    input              RESET_N,

    // Clocks
    input              CLOCK_50,
    input              CLOCK2_50,
    input              CLOCK3_50,
    input              CLOCK4_50,

    // DRAM
    output             DRAM_CKE,
    output             DRAM_CLK,
    output      [1:0]  DRAM_BA,
    output      [12:0] DRAM_ADDR,
    inout       [15:0] DRAM_DQ,
    output             DRAM_CAS_N,
    output             DRAM_RAS_N,
    output             DRAM_WE_N,
    output             DRAM_CS_N,
    output             DRAM_LDQM,
    output             DRAM_UDQM,

    // GPIO
    inout       [35:0] GPIO_0,
    inout       [35:0] GPIO_1,

    // 7-Segment LED
    output      [6:0]  HEX0,
    output      [6:0]  HEX1,
    output      [6:0]  HEX2,
    output      [6:0]  HEX3,
    output      [6:0]  HEX4,
    output      [6:0]  HEX5,

    // Keys
    input       [3:0]  KEY,

    // LED
    output      [9:0]  LEDR,

    // PS/2
    inout              PS2_CLK,
    inout              PS2_DAT,
    inout              PS2_CLK2,
    inout              PS2_DAT2,

    // SD-Card
    output             SD_CLK,
    inout              SD_CMD,
    inout       [3:0]  SD_DATA,

    // Switch
    input       [9:0]  SW,

    // VGA
    output      [3:0]  VGA_R,
    output      [3:0]  VGA_G,
    output      [3:0]  VGA_B,
    output             VGA_HS,
    output             VGA_VS
);

// MISO: Input Port
assign SD_DATA[0] = 1'bZ;

// SDRAM Enable
assign DRAM_CKE  = 1;   // ChipEnable
assign DRAM_CS_N = 0;   // ChipSelect

// Z-state
assign DRAM_DQ = 16'hzzzz;
assign GPIO_0  = 36'hzzzzzzzz;
assign GPIO_1  = 36'hzzzzzzzz;

// LED OFF
assign HEX0 = 7'b1111111;
assign HEX1 = 7'b1111111;
assign HEX2 = 7'b1111111;
assign HEX3 = 7'b1111111;
assign HEX4 = 7'b1111111;
assign HEX5 = 7'b1111111;

// --------------------------------------------------------------
// Генератор частот
// --------------------------------------------------------------

wire locked;
wire clock_12, clock_25, clock_50, clock_100;

pll PLL0
(
    .clkin     (CLOCK_50),
    .m12       (clock_12),
    .m25       (clock_25),
    .m50       (clock_50),
    .m100      (clock_100),
    .locked    (locked)
);


// -----------------------------------------------------------------------------
// ПАМЯТЬ
// -----------------------------------------------------------------------------

// Память программ 128K
mem_prg M0
(
    .clock  (clock_100),
    .a0     (pc),
    .q0     (ir)
);

// Общая видеопамять 128K
mem_ram M1
(
    .clock  (clock_100),
    .a0     (A26[16:0]),
    .q0     (data_m1),
    .d0     (data_o),
    .w0     (we && !mreq),
    .a1     (char_address),
    .q1     (char_data)
);

// Шрифты 2K
mem_font M2
(
    .clock  (clock_100),
    .a0     (font_address),
    .q0     (font_data)
);

// -----------------------------------------------------------------------------
// КОНТРОЛЛЕР ПОРТОВ
// -----------------------------------------------------------------------------

reg [7:0]   bank;
reg [1:0]   vmode;
reg [2:0]   zxborder;

// SD
reg         sd_signal;  // Если 1, то команда отправлена
reg  [1:0]  sd_cmd;     // 0-PUT, 1-INIT, 2-CE0, 3-CE1
reg  [7:0]  sd_out;
wire [7:0]  sd_din;
wire        sd_busy, sd_timeout;

// IRQ
reg         irq_ack;    // =1 Прерывание обрабатывается
reg [2:0]   irq_queue;  // Очередь прерываний
reg [2:0]   intmask;    // =1 Разрешить прерывания
reg         intr;       // -> К процессору
reg [ 2:0]  vect;       // Номер текущего прерывания

// Учесть банки памяти
wire [25:0] A26  = address + (address >= 16'hF000 ?  bank*4096 : 0);

// Все что выше 128K RAM, относится к SDRAM
wire mreq = (A26 >= 26'h20000);

// Роутер памяти и портов
wire [ 7:0] data_i =
    address == 16'h20 ? bank        :
    address == 16'h21 ? vmode       :
    address == 16'h22 ? kb_data_in  :
    address == 16'h2C ? sd_din      :
    address == 16'h2D ? {sd_timeout, sd_busy} :
    address == 16'h2E ? curx        :
    address == 16'h2F ? cury        :
    address == 16'h30 ? intmask     :
    address == 16'h31 ? zxborder    :
    // Либо 128К, либо SDRAM
        (mreq ? sdram_out : data_m1);

always @(posedge clock_25)
begin

    sd_signal <= 0;

    if (we)
    case (address)

        16'h20: begin bank      <= data_o; end
        16'h21: begin vmode     <= data_o[1:0]; end
        16'h22: begin irq_ack   <= 0; end
        16'h2C: begin sd_signal <= 1; sd_cmd <= 0;      sd_out <= data_o; end
        16'h2D: begin sd_signal <= 1; sd_cmd <= data_o; sd_out <= 8'hFF; end
        16'h2E: begin cursor    <= data_o + 80*cury;    curx <= data_o; end
        16'h2F: begin cursor    <= curx   + 80*data_o;  cury <= data_o; end
        16'h30: begin intmask   <= data_o; end
        16'h31: begin zxborder  <= data_o; end

    endcase

    // Прерывание от видеоадаптера, каждые 1/60 секунд
    if (ga_int)  begin irq_queue[1] <= intmask[0]; end

    // Пришли новые данные от клавиатуры
    if (kb_done) begin irq_queue[2] <= intmask[1]; kb_data_in <= kb_data; end

    // Предыдущее прерывание либо не было, либо уже отработало
    if (!irq_ack) begin

        // При наличии прерываний в очереди, включается IRQ_ACK=1, чтобы заблокировать
        // следующие прерывания из очереди
        if (irq_queue) begin intr <= ~intr; irq_ack <= 1; end

        // Активация прерывания по приоритету
        if      (irq_queue[1]) begin vect <= 1; irq_queue[1] <= 1'b0; end // TIMER
        else if (irq_queue[2]) begin vect <= 2; irq_queue[2] <= 1'b0; end // KEYBOARD

    end

end

// -----------------------------------------------------------------------------
// ВИДЕОАДАПТЕР
// -----------------------------------------------------------------------------

wire [16:0] char_address;           // 128K
wire [11:0] font_address;
wire [ 7:0] char_data;
wire [ 7:0] font_data;
reg  [10:0] cursor;
reg  [ 7:0] curx, cury;
wire        ga_int;

video U1
(
    // Опорная частота 25 мгц
    .clock      (clock_25),

    // Настройки
    .vmode      (vmode),
    .cursor     (cursor),
    .border     (zxborder),

    // Выходные данные
    .r          (VGA_R),
    .g          (VGA_G),
    .b          (VGA_B),
    .hs         (VGA_HS),
    .vs         (VGA_VS),
    .int        (ga_int),

    // Доступ к памяти
    .char_address   (char_address),
    .font_address   (font_address),
    .char_data      (char_data),
    .font_data      (font_data)
);

// -----------------------------------------------------------------------------
// КЛАВИАТУРА
// -----------------------------------------------------------------------------

wire        kb_done;
wire [7:0]  kb_data;
reg  [7:0]  kb_data_in;

ps2 PS2KEYB
(
    .clock      (clock_25),
    .ps_clock   (PS2_CLK),
    .ps_data    (PS2_DAT),
    .done       (kb_done),
    .data       (kb_data)
);

// -----------------------------------------------------------------------------
// КОНТРОЛЛЕР SD
// -----------------------------------------------------------------------------

sd UnitSPI
(
    // 50 Mhz
    .clock      (clock_25),
    .reset_n    (locked),

    // Физический интерфейс
    .SPI_CS     (SD_DATA[3]),  // Выбор чипа
    .SPI_SCLK   (SD_CLK),      // Тактовая частота
    .SPI_MISO   (SD_DATA[0]),  // Входящие данные
    .SPI_MOSI   (SD_CMD),      // Исходящие

    // Ввод
    .sd_signal  (sd_signal),
    .sd_cmd     (sd_cmd),
    .sd_out     (sd_out),

    // Вывод
    .sd_din     (sd_din),
    .sd_busy    (sd_busy),
    .sd_timeout (sd_timeout),
);

// -----------------------------------------------------------------------------
// ПАМЯТЬ SDRAM
// -----------------------------------------------------------------------------

sdram SDRAMUnit
(
    // Физический интерфейс
    .reset_n        (locked),
    .clock          (clock_50),
    .clk_hi         (clock_100),
    .clk_cpu        (clock_25),
    .ce             (ce),

    // Физический интерфейс DRAM
    .dram_clk       (DRAM_CLK),
    .dram_ba        (DRAM_BA),
    .dram_addr      (DRAM_ADDR),
    .dram_dq        (DRAM_DQ),
    .dram_cas       (DRAM_CAS_N),
    .dram_ras       (DRAM_RAS_N),
    .dram_we        (DRAM_WE_N),
    .dram_ldqm      (DRAM_LDQM),
    .dram_udqm      (DRAM_UDQM),

    // Сигналы от процессора
    .address        (A26),
    .mreq           (mreq),
    .read           (read),
    .write          (we),
    .in             (data_o),
    .out            (sdram_out)
);

// -----------------------------------------------------------------------------
// ЦЕНТРАЛЬНЫЙ ПРОЦЕССОР
// -----------------------------------------------------------------------------

wire [15:0] pc, ir;
wire [15:0] address;
wire [ 7:0] data_o, data_m1, sdram_out;
wire        ce, we, read;

core COREAVR
(
    .clock      (clock_25),
    .reset_n    (locked),
    .ce         (ce),
    // Программная память
    .pc         (pc),           // Программный счетчик
    .ir         (ir),           // Инструкция из памяти
    // Оперативная память
    .address    (address),      // Указатель на память RAM (sram)
    .data_i     (data_i),       // = memory[ address ]
    .data_o     (data_o),       // Запись в память по address
    .read       (read),         // Запрос на чтение из памяти
    .we         (we),           // Разрешение записи в память
    // Внешнее прерывание #0..7
    .intr       (intr),
    .vect       (vect)
);

endmodule
