/*
 * CLOCK    ____/``\____/``\|____/``\____/``\|____/``\____/``\|____/``\
 * DRAM_CLK /``\____/``\____|/``\____/``\____|/``\____/``\____|/``\____
 * CLK_CPU  ____/``````\____|____/``````\____|____/``````\____|____/```
 */
module sdram
(
    // Физический интерфейс
    input               reset_n,
    input               clock,          // 50 mhz
    input               clk_hi,         // 100 mhz
    output  reg         ce,             // Удержание работы CPU

    // Физический интерфейс DRAM
    output              dram_clk,       // Тактовая частота памяти
    output reg  [ 1:0]  dram_ba,        // 4 банка
    output reg  [12:0]  dram_addr,      // Максимальный адрес 2^13=8192
    inout       [15:0]  dram_dq,        // Ввод-вывод
    output              dram_cas,       // CAS
    output              dram_ras,       // RAS
    output              dram_we,        // WE
    output reg          dram_ldqm,      // Маска для младшего байта
    output reg          dram_udqm,      // Маска для старшего байта

    // Сигналы от процессора
    input               clk_cpu,        // Процессорный CLK
    input       [25:0]  address,        // Запрошенный адрес
    input               mreq,           // =1 Активировать контроллер
    input               read,           // =1 Процессор запросил чтение
    input               write,          // =1 Процессор запросил запись
    input        [7:0]  in,             // Что писать (от процессора)
    output reg   [7:0]  out             // Результат
);

assign dram_clk = ~clock;
assign dram_dq  =  dram_we ? 16'hZZZZ : {data, data};
assign {dram_ras, dram_cas, dram_we} = command;

// Command modes                 RCW
// ---------------------------------------------------------------------
// Команды
localparam

    //                   RCW
    cmd_loadmode    = 3'b000,
    cmd_refresh     = 3'b001,
    cmd_precharge   = 3'b010,
    cmd_activate    = 3'b011,
    cmd_write       = 3'b100,
    cmd_read        = 3'b101,
    cmd_burst_term  = 3'b110,
    cmd_nop         = 3'b111;

localparam
    init_time       = 10000;

// ---------------------------------------------------------------------
reg         init, done;
reg  [14:0] ic;
reg  [1:0]  t;
reg  [2:0]  m;
reg  [2:0]  command;
reg [12:0]  refresh;
reg [25:0]  kaddress;
reg [ 7:0]  data;
// ---------------------------------------------------------------------

always @(negedge clock)
// Сброс PLL
if (reset_n == 1'b0) begin

    ce          <= 0;
    t           <= 0;
    m           <= 0;
`ifdef ICARUS
    ic          <= init_time;
`else
    ic          <= 0;
`endif
    init        <= 1;
    done        <= 0;
    kaddress    <= {26{1'b1}};
    dram_udqm   <= 1;
    dram_ldqm   <= 1;
    command     <= cmd_nop;
    refresh     <= 0;

end
// Инициализация памяти при запуске
else if (init) begin

    case (ic)

        init_time + 2:  begin command <= cmd_precharge; end
        init_time + 8:  begin command <= cmd_refresh; end
        init_time + 36: begin command <= cmd_loadmode; dram_addr[9:0] <= 10'b0_00_010_0_111; end
        init_time + 42: begin init    <= 0; ic <= 0; end
        default:        begin command <= cmd_nop; end

    endcase

    ic <= ic + 1;

end
else begin

    m  <= m + 1;
    ic <= ic + 1;

    case (t)
    // IDLE
    0: if (clk_cpu == 1'b0) begin

        m <= 0;

        // Обновление строки каждые 64 мс (50 mhz / 8192) -> 6103/15
        if (ic >= 406) begin

            t   <= 3;
            ce  <= 0;
            ic  <= 0;

            command     <= cmd_activate;
            dram_addr   <= refresh;
            refresh     <= refresh + 1;

        end
        // Чтение или запись
        else if (!done && mreq && (read || write)) begin

            ce          <= 0;
            t           <= read ? 1 : 2;
            command     <= cmd_activate;
            dram_ba     <= address[25:24];
            dram_addr   <= address[23:11];
            dram_ldqm   <= write &  address[0];
            dram_udqm   <= write & ~address[0];
            kaddress    <= address;
            data        <= in;

        end
        // Активация процессора, сброс DONE на следующий такт
        else begin ce <= 1'b1; done <= 1'b0; end

    end
    // 8T READ
    1: case (m)

        0, 1,
        3, 4:
           begin command <= cmd_nop; end
        2: begin command <= cmd_read;       dram_addr <= {1'b1, kaddress[10:1]}; end
        5: begin command <= cmd_precharge;  out <= kaddress[0] ? dram_dq[15:8] : dram_dq[7:0]; end
        6: begin command <= cmd_nop; t <= 0; done <= 1; end

    endcase
    // 7T WRITE
    2: case (m)

        0, 1:
           begin command <= cmd_nop; end
        2: begin command <= cmd_write;      dram_addr <= {1'b1, kaddress[10:1]}; end
        3: begin command <= cmd_burst_term; end
        4: begin command <= cmd_precharge;  end
        5: begin command <= cmd_nop; t <= 0; done <= 1; end

    endcase
    // REFRESH
    3: case (m)

        0, 1:
            begin command <= cmd_nop; end
        2:  begin command <= cmd_precharge; dram_addr[10] <= 1'b1; end
        3:  begin command <= cmd_nop; t <= 0; end

    endcase

    endcase

end

endmodule
