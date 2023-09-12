/* verilator lint_off WIDTH */
/* verilator lint_off CASEX */
/* verilator lint_off CASEINCOMPLETE */
/* verilator lint_off UNOPTFLAT */
module core
(
    input               clock,      // 25 MHZ
    input               reset_n,    // =0 Сброс
    input               ce,         // =1 Процессор работает
    // Программная память
    output reg  [15:0]  pc,         // Программный счетчик
    input       [15:0]  ir,         // Инструкция из памяти
    // Оперативная память
    output reg  [15:0]  address,    // Указатель на память RAM (sram)
    input       [ 7:0]  data_i,     // = memory[ address ]
    output reg  [ 7:0]  data_o,     // Запись в память по address
    output reg          we,         // =1 Запись в память
    output reg          read,       // =1 Запрос чтения из памяти
    // Внешнее прерывание #0..7
    input               intr,
    input       [ 2:0]  vect
);
initial begin
    address = 1'b0;
    pc      = 1'b0;
    we      = 1'b0;
    data_o  = 1'b0;
    read    = 1'b0;
    // Регистры 0-15
    r[0] = 8'h00; r[4] = 8'h00; r[8]  = 8'h00; r[12] = 8'h01;
    r[1] = 8'h00; r[5] = 8'h00; r[9]  = 8'h00; r[13] = 8'h00;
    r[2] = 8'h00; r[6] = 8'h00; r[10] = 8'h00; r[14] = 8'h00;
    r[3] = 8'h00; r[7] = 8'h00; r[11] = 8'h00; r[15] = 8'h00;
    // Регистры 16-31
    r[16] = 8'h00; r[20] = 8'h00; r[24] = 8'h00; r[28] = 8'h00;
    r[17] = 8'h00; r[21] = 8'h00; r[25] = 8'h00; r[29] = 8'h00;
    r[18] = 8'h00; r[22] = 8'h00; r[26] = 8'h00; r[30] = 8'h05;
    r[19] = 8'h00; r[23] = 8'h00; r[27] = 8'h00; r[31] = 8'hFA;
end
localparam SPDEC = 1, SPINC = 2;
// ---------------------------------------------------------------------
// Проксирование памяти
// ---------------------------------------------------------------------
reg [7:0] din;
always @* begin
    casex (address)
        // Регистры
        16'b0000_0000_000x_xxxx: din = r[ address[4:0] ];
        // Процессор
        16'h005B: din = rampz;
        16'h005D: din = sp[ 7:0];
        16'h005E: din = sp[15:8];
        16'h005F: din = sreg;
        // Память
        default:  din = data_i;
    endcase
end
// ---------------------------------------------------------------------
// Регистры процессора, в том числе системные
// ---------------------------------------------------------------------
// Регистры
reg [ 7:0]  r[32];                      // Регистры
reg [ 1:0]  tstate  = 0;                // Машинное состояние
reg [15:0]  latch   = 0;                // Записанный опкод
reg [15:0]  pclatch = 0;                // Для LPM / SPM
reg [15:0]  sp      = 16'h1FFF;         // Stack Pointer 8k
reg [ 7:0]  sreg    = 8'b0000_0000;     // Status Register
reg [ 4:0]  alu     = 0;                // Режим работы АЛУ
// Команды на обратном фронте
reg         reg_w   = 0;                // Писать в регистр
reg         sreg_w  = 0;                // Писать в SREG из АЛУ
reg [ 4:0]  reg_id  = 0;                // В какой регистр писать
reg [ 1:0]  sp_mth  = 0;                // Увеличение или уменьшение стека
// 16 битные регистры
reg         reg_ww  = 1'b0;             // Писать в X,Y,Z
reg         reg_ws  = 1'b0;             // =1 Источник АЛУ; =0 Источник регистр `wb2`
reg         reg_wm  = 1'b0;             // Запись в 1:0
reg [ 1:0]  reg_idw = 1'b0;             // Номер 16-битного регистра
reg [15:0]  wb2     = 1'b0;             // Данные для записи в X,Y,Z
reg [ 7:0]  rampz   = 1'b0;             // Верхняя память для E-функции
// Провода
wire [15:0] opcode = tstate ? latch : ir;
wire [15:0] X   = {r[27], r[26]};
wire [15:0] Y   = {r[29], r[28]};
wire [15:0] Z   = {r[31], r[30]};
wire [15:0] Xm  = X - 1'b1;
wire [15:0] Xp  = X + 1'b1;
wire [15:0] Ym  = Y - 1'b1;
wire [15:0] Yp  = Y + 1'b1;
wire [15:0] Zm  = Z - 1'b1;
wire [15:0] Zp  = Z + 1'b1;
wire [ 5:0] q   = {opcode[13], opcode[11:10], opcode[2:0]};
wire [ 4:0] rd  =  opcode[8:4];
wire [ 4:0] rr  = {opcode[9], opcode[3:0]};
wire [ 4:0] rdi = {1'b1, opcode[7:4]};
wire [ 4:0] rri = {1'b1, opcode[3:0]};
wire [ 7:0] K   = {opcode[11:8], opcode[3:0]};
// Управление счетчиком
reg         skip_instr  = 1'b0;
wire [15:0] pcnext      = pc + 1'h1;
wire [15:0] pcnext2     = pc + 2'h2;
wire        en_int      = (tstate == 0 && sreg[7]);
wire        is_call     = {opcode[14], opcode[3:1]} == 4'b0111;
// ---------------------------------------------------------------------
// Арифметико-логическое устройство
// ---------------------------------------------------------------------
reg  [ 7:0] op1;      reg  [ 7:0] op2;
wire [ 7:0] alu_res;  wire [ 7:0] alu_sreg;
reg  [15:0] op1w;     wire [15:0] resw;
alu UnitALU
(
    .mode (alu),
    .d    (op1),
    .r    (op2),
    .s    (sreg),
    .R    (alu_res),
    .S    (alu_sreg),
    .op1w (op1w),
    .resw (resw)
);
// Таймер прерываний
reg        intr_trigger = 1'b0;
reg        intr_prev    = 1'b0;
reg [2:0]  intr_vect    = 1'b0;
// ---------------------------------------------------------------------
// Главное исполнительное устройство
// ---------------------------------------------------------------------
always @(posedge clock)
// Сброс процессора
if (reset_n == 1'b0) begin
    pc      <= 1'b0;
    tstate  <= 1'b0;
    read    <= 1'b0;
    we      <= 1'b0;
end
// Рабочее состояние
else if (ce) begin
    we     <= 1'b0;
    read   <= 1'b0; // Чтение из памяти
    reg_w  <= 1'b0;
    sreg_w <= 1'b0;
    sp_mth <= 1'b0; // Ничего не делать с SP
    reg_ww <= 1'b0; // Ничего не делать с X,Y,Z
    reg_ws <= 1'b0; // Источник регистр wb2
    reg_wm <= 1'b0; // Источник регистр resw
    if (tstate == 0) latch <= ir;
    // Код пропуска инструкции (JMP, CALL, LDS, STS)
    if (skip_instr) begin
        casex (opcode)
            16'b1001_010x_xxxx_11xx, // CALL | JMP
            16'b1001_00xx_xxxx_0000: // LDS  | STS
                pc <= pcnext + 1;
            default:
                pc <= pcnext;
        endcase
        skip_instr <= 0;
    end
    // Вызов прерывания таймера
    // -----------------------------------------------------------------
    else if (intr_trigger) begin
        case (tstate)
            // Запись PCL
            0: begin
                tstate  <= 1;
                address <= sp;
                data_o  <= pc[7:0];
                we      <= 1'b1;
                sp_mth  <= SPDEC;
            end
            // Запись PCH
            1: begin
                tstate  <= 0;
                address <= sp;
                data_o  <= pc[15:8];
                we      <= 1'b1;
                sp_mth  <= SPDEC;
                pc      <= {intr_vect, 1'b0}; // ISR(INTx_vect)
                intr_trigger <= 0;            // Переход к обычному исполнению
                // Сброс флага I->0 (sreg)
                alu     <= 11;
                op2     <= {1'b0, sreg[6:0]};
                sreg_w  <= 1'b1;
            end
        endcase
    end
    // Вызов прерывания IRQ#x срабатывает на переключении intr
    // -----------------------------------------------------------------
    else if (en_int && tstate == 0 && intr ^ intr_prev) begin
        intr_vect    <= vect; // Вектор 0..7
        intr_prev    <= intr; // Сохранить предыдущее состояние
        intr_trigger <= 1'b1; // Вызов прерывания
    end
    // Исполнение опкодов
    // -----------------------------------------------------------------
    else casex (opcode)
        // NOP, BREAK
        16'b0000_0000_0000_0000: pc <= pcnext;
        16'b1001_0101_1001_1000: pc <= pcnext;
        // [1T] LDI Rd, K
        16'b1110_xxxx_xxxx_xxxx: begin
            pc      <= pcnext;
            alu     <= 0;       // Инструкция LDI
            op2     <= K;
            reg_w   <= 1'b1;
            reg_id  <= rdi;
        end
        // [1T] RJMP k | IJMP | EIJMP
        16'b1100_xxxx_xxxx_xxxx: pc <= pcnext + {{4{opcode[11]}}, opcode[11:0]};
        16'b1001_0100_000x_1001: pc <= Z;
        // [2T] JMP k
        16'b1001_010x_xxxx_110x:
        case (tstate)
            0: begin tstate <= 1; pc <= pcnext; end
            1: begin tstate <= 0; pc <= ir; end
        endcase
        // [1T] <ALU> Rd, Rr
        16'b000x_01xx_xxxx_xxxx, // 1 CPC, 5 CP
        16'b000x_1xxx_xxxx_xxxx, // 2 SBC, 3 ADD, 6 SUB, 7 ADC
        16'b0010_0xxx_xxxx_xxxx, // 8 AND, 9 EOR
        16'b0010_10xx_xxxx_xxxx: // A OR
        begin
            pc      <= pcnext;
            alu     <= opcode[13:10];
            op1     <= r[rd];
            op2     <= r[rr];
            reg_id  <= rd;
            // CP, CPС не писать
            reg_w   <= (opcode[13:10] != 4'b0001 && opcode[13:10] != 4'b0101);
            sreg_w  <= 1'b1;
        end
        // [1T] BRB[C/S] k
        16'b1111_0xxx_xxxx_xxxx:
        begin
            if (sreg[ opcode[2:0] ] ^ opcode[10])
                pc <= pcnext + {{9{opcode[9]}}, opcode[9:3]};
            else
                pc <= pcnext;
        end
        // [1T] АЛУ с непосредственным операндом
        16'b0011_xxxx_xxxx_xxxx, // CPI
        16'b0100_xxxx_xxxx_xxxx, // SBCI
        16'b0101_xxxx_xxxx_xxxx, // SUBI
        16'b0110_xxxx_xxxx_xxxx, // ORI
        16'b0111_xxxx_xxxx_xxxx: // ANDI
        begin
            pc      <= pcnext;
            op1     <= r[rdi];
            op2     <= K;
            reg_id  <= rdi;
            reg_w   <= (opcode[15:12] != 4'b0011); // CPI не писать
            sreg_w  <= 1'b1;
            case (opcode[15:12])
                4'b0011: alu <= 5;  // CPI
                4'b0100: alu <= 2;  // SBCI
                4'b0101: alu <= 6;  // SUBI
                4'b0110: alu <= 10; // ORI
                4'b0111: alu <= 8;  // ANDI
            endcase
        end
        // [1T] MOV Rd, Rr
        16'b0010_11xx_xxxx_xxxx:
        begin
            pc      <= pcnext;
            alu     <= 0;
            op2     <= r[rr];
            reg_id  <= rd;
            reg_w   <= 1'b1;
        end
        // [2T] RCALL k | ICALL | EICALL | CALL
        16'b1101_xxxx_xxxx_xxxx,
        16'b1001_0101_000x_1001,
        16'b1001_010x_xxxx_111x:
        case (tstate)
            // Запись PCL
            0: begin
                tstate  <= 1;
                address <= sp;
                data_o  <= is_call ? pcnext2[7:0] : pcnext[7:0];
                we      <= 1'b1;
                sp_mth  <= SPDEC;
                pc      <= pcnext;
            end
            // Запись PCH
            1: begin
                tstate  <= 0;
                address <= sp;
                data_o  <= is_call ? pcnext[15:8] : pc[15:8];
                we      <= 1'b1;
                sp_mth  <= SPDEC;
                // Метод вызова
                /* CALL */       if (is_call)    pc <= ir;
                /* RCALL */ else if (opcode[14]) pc <= (pc + {{4{opcode[11]}}, opcode[11:0]});
                /* ICALL */ else                 pc <= Z;
            end
        endcase
        // [3T] 9508 RET | 9518 RETI
        16'b1001_0101_000x_1000:
        case (tstate)
            // Указатель адреса
            0: begin
                tstate   <= 1;
                read     <= 1;
                address  <= sp + 1;
                sp_mth   <= SPINC;
            end
            // Чтение PCH
            1: begin
                tstate   <= 2;
                read     <= 1;
                pc[15:8] <= din;
                address  <= sp + 1;
                sp_mth   <= SPINC;
            end
            // Чтение PCL
            2: begin
                tstate   <= 0;
                pc[ 7:0] <= din;
                alu      <= 11;
                op2      <= {sreg[7] | opcode[4], sreg[6:0]};
                sreg_w   <= 1;
            end
        endcase
        // [2T] LD Rd, (X|Y|Z)+
        // [1T] ST Rd, (X|Y|Z)+
        16'b1001_00xx_xxxx_1100, // X
        16'b1001_00xx_xxxx_1101, // X+
        16'b1001_00xx_xxxx_1110, // -X
        16'b1001_00xx_xxxx_1001, // Y+
        16'b1001_00xx_xxxx_1010, // -Y
        16'b1001_00xx_xxxx_0001, // Z+
        16'b1001_00xx_xxxx_0010: // -Z
        case (tstate)
            // Установка указателя на память
            0: begin
                tstate <= opcode[9] ? 0 : 1;
                pc     <= pcnext;
                data_o <= r[rd];
                we     <=  opcode[9];
                read   <= !opcode[9];
                // Выбор адреса
                case (opcode[3:0])
                    4'b11_00: begin address <= X;  end
                    4'b11_01: begin address <= X;  wb2 <= Xp; reg_idw <= 2'b01; reg_ww <= 1; end
                    4'b11_10: begin address <= Xm; wb2 <= Xm; reg_idw <= 2'b01; reg_ww <= 1; end
                    4'b10_01: begin address <= Y;  wb2 <= Yp; reg_idw <= 2'b10; reg_ww <= 1; end
                    4'b10_10: begin address <= Ym; wb2 <= Ym; reg_idw <= 2'b10; reg_ww <= 1; end
                    4'b00_01: begin address <= Z;  wb2 <= Zp; reg_idw <= 2'b11; reg_ww <= 1; end
                    4'b00_10: begin address <= Zm; wb2 <= Zm; reg_idw <= 2'b11; reg_ww <= 1; end
                endcase
            end
            // Запись в регистр Rd (LD)
            1: begin
                tstate  <= 0;
                alu     <= 0;
                op2     <= din;
                reg_w   <= 1;
                reg_id  <= rd;
            end
        endcase
        // [2T] LDD Y+q, Z+q
        // [1T] STD Y+q, Z+q
        16'b10x0_xxxx_xxxx_xxxx: // Y,Z
        case (tstate)
            // Установка указателя на память
            0: begin
                tstate  <= opcode[9] ? 0 : 1;
                pc      <= pcnext;
                address <= (opcode[3] ? Y : Z) + q;
                data_o  <= r[rd];
                we      <=  opcode[9];
                read    <= !opcode[9];
            end
            // Запись в регистр Rd
            1: begin
                tstate  <= 0;
                alu     <= 0;
                op2     <= din;
                reg_w   <= 1;
                reg_id  <= rd;
            end
        endcase
        // [1T] 0=COM, 1=NEG, 2=SWAP, 3=INC, 5=ASR, 6=LSR, 7=ROR, 10=DEC
        16'b1001_010x_xxxx_00xx,
        16'b1001_010x_xxxx_011x,
        16'b1001_010x_xxxx_0101,
        16'b1001_010x_xxxx_1010: begin
            pc      <= pcnext;
            op1     <= r[rd];   // Rd
            reg_w   <= 1;
            sreg_w  <= 1;
            reg_id  <= rd;
            case (opcode[3:0])
                4'b0000: alu <= 5'h0C; // COM
                4'b0001: alu <= 5'h0D; // NEG
                4'b0010: alu <= 5'h0E; // SWAP
                4'b0011: alu <= 5'h0F; // INC
                4'b0101: alu <= 5'h10; // ASR
                4'b0110: alu <= 5'h11; // LSR
                4'b0111: alu <= 5'h12; // ROR
                4'b1010: alu <= 5'h13; // DEC
            endcase
        end
        // [2T] MOVW Rd, Rr
        16'b0000_0001_xxxx_xxxx:
        case (tstate)
            // LO регистр
            0: begin
                tstate  <= 1;
                pc      <= pcnext;
                alu     <= 0;
                op2     <= r[ {opcode[3:0], 1'b0} ];
                reg_id  <=    {opcode[7:4], 1'b0};
                reg_w   <= 1;
            end
            // HI регистр
            1: begin
                tstate  <= 0;
                alu     <= 0;
                op2     <= r[ {opcode[3:0], 1'b1} ];
                reg_id  <=    {opcode[7:4], 1'b1};
                reg_w   <= 1;
            end
        endcase
        // [1T] <ADIW|SBIW> Rd, K
        16'b1001_0110_xxxx_xxxx, // ADIW
        16'b1001_0111_xxxx_xxxx: // SBIW
        begin
            pc      <= pcnext;
            alu     <= opcode[8] ? 5'h15 : 5'h14;
            case (opcode[5:4])
                0: op1w <= {r[25], r[24]};
                1: op1w <= {r[27], r[26]};
                2: op1w <= {r[29], r[28]};
                3: op1w <= {r[31], r[30]};
            endcase
            op2     <= {opcode[7:6], opcode[3:0]};
            reg_idw <= opcode[5:4];
            reg_ww  <= 1;
            reg_ws  <= 1;
            sreg_w  <= 1;
        end
        // [2T] LPM Rd, Z
        16'b1001_0101_110x_1000, // LPM R0, Z  | ELPM R0, Z
        16'b1001_000x_xxxx_01x0, // LPM Rd, Z  | ELPM Rd, Z
        16'b1001_000x_xxxx_01x1: // LPM Rd, Z+ | ELPM Rd, Z+
        case (tstate)
            // Считывание байта
            0: begin
                tstate  <= 1;
                pclatch <= pcnext;
                // Если ELPM, то записать в старший бит rampz[0]
                if (opcode[1] || (opcode[10] && opcode[4]))
                     pc <= {rampz[0], Z[15:1]}; // ELPM
                else pc <= Z[15:1];             // LPM
            end
            // Запись
            1: begin
                tstate  <= 0;
                pc      <= pclatch;
                alu     <= 0;       // LDI
                reg_idw <= 2'b11;   // Z
                reg_ww  <= (!opcode[10] & opcode[0]); // Z+
                wb2     <= Zp;
                reg_w   <= 1;
                reg_id  <= opcode[10] ? 0 : rd;         // R0, Rd
                op2     <= Z[0] ? ir[15:8] : ir[7:0];   // Hi, Lo
            end
        endcase
        // [2T] IN  Rd, A
        // [1T] OUT A, Rd
        16'b1011_xxxx_xxxx_xxxx:
        case (tstate)
            // Установка адреса
            0: begin
                tstate  <= opcode[11] ? 0 : 1;
                pc      <= pcnext;
                data_o  <= r[rd];
                we      <=  opcode[11];
                read    <= !opcode[11];
                address <= {opcode[10:9], opcode[3:0]} + 16'h20;
            end
            // Запись регистра
            1: begin
                tstate  <= 0;
                alu     <= 0;
                op2     <= din;
                reg_id  <= rd;
                reg_w   <= 1;
            end
        endcase
        // [1T] SBR[C,S] Rd, b
        // [1T] SBRS Rd, b
        16'b1111_11xx_xxxx_0xxx: begin
            pc <= pcnext;
            if (r[rd][ opcode[2:0] ] == opcode[9])
                skip_instr <= 1;
        end
        // [2T] SBI[C,S] A, b
        // [2T] SBIS A, b
        16'b1001_10x1_xxxx_xxxx: // C=0,S=1
        casex (tstate)
            // Запрос чтения
            0: begin
                tstate  <= 1;
                read    <= 1;
                address <= opcode[7:3] + 16'h20;
            end
            // Вычисление бита
            1: begin
                tstate  <= 0;
                pc      <= pcnext;
                if (din[ opcode[2:0] ] == opcode[9])
                    skip_instr <= 1;
            end
        endcase
        // [1T] CPSE Rd, Rr
        16'b0001_00xx_xxxx_xxxx: begin
            if (r[rd] == r[rr]) skip_instr <= 1;
            pc <= pcnext;
        end
        // [3T] LDS Rd, Mem
        // [2T] STS Mem, Rd
        16'b1001_00xx_xxxx_0000: // 0=lds, 1=sts
        case (tstate)
            // К следующему коду
            0: begin
                tstate  <= 1;
                pc      <= pcnext;
            end
            // Запись в память или выбор регистра
            1: begin
                tstate  <= opcode[9] ? 0 : 2; // 1=STS, 0=LDS
                pc      <= pcnext;
                reg_id  <= rd;
                address <= ir;
                data_o  <= r[rd];
                we      <=  opcode[9];
                read    <= !opcode[9];
            end
            // Запись в регистр
            2: begin
                tstate <= 0;
                alu    <= 0;
                reg_w  <= 1;
                op2    <= din;
            end
        endcase
        // [1T] BCLR, BSET
        16'b1001_0100_xxxx_1000: begin
            case (opcode[6:4])
                0: op2 <= {sreg[7:1], !opcode[7]};
                1: op2 <= {sreg[7:2], !opcode[7], sreg[0]};
                2: op2 <= {sreg[7:3], !opcode[7], sreg[1:0]};
                3: op2 <= {sreg[7:4], !opcode[7], sreg[2:0]};
                4: op2 <= {sreg[7:5], !opcode[7], sreg[3:0]};
                5: op2 <= {sreg[7:6], !opcode[7], sreg[4:0]};
                6: op2 <= {sreg[7],   !opcode[7], sreg[5:0]};
                7: op2 <= {!opcode[7],            sreg[6:0]};
            endcase
            alu     <= 11;
            sreg_w  <= 1;
            pc      <= pcnext;
        end
        // [1T] PUSH Rd
        16'b1001_001x_xxxx_1111: begin
            pc      <= pcnext;
            data_o  <= r[rd];
            we      <= 1'b1;
            address <= sp;
            sp_mth  <= SPDEC;
        end
        // [2T] POP Rd
        16'b1001_000x_xxxx_1111:
        case (tstate)
            // Указатель адреса
            0: begin
                tstate  <= 1;
                pc      <= pcnext;
                address <= sp + 1;
                sp_mth  <= SPINC;
                read    <= 1;
            end
            // Запись в регистр
            1: begin
                tstate  <= 0;
                alu     <= 0;
                op2     <= din;
                reg_id  <= rd;
                reg_w   <= 1;
            end
        endcase
        // [1T] BST Rd, b
        16'b1111_101x_xxxx_0xxx: begin
            pc      <= pcnext;
            alu     <= 11;
            op2     <= {sreg[7], r[rd][ opcode[2:0] ], sreg[5:0]};
            sreg_w  <= 1;
        end
        // [1T] BLD Rd, b
        16'b1111_100x_xxxx_0xxx: begin
            pc      <= pcnext;
            alu     <= 22;  // BLD
            op1     <= r[rd];
            op2     <= opcode[2:0];
            reg_id  <= rd;
            reg_w   <= 1;
        end
        // [2T] CBI / SBI A, b
        16'b1001_10x0_xxxx_xxxx:
        case (tstate)
            // Чтение из порта
            0: begin
                tstate  <= 1;
                read    <= 1;
                pc      <= pcnext;
                address <= opcode[7:3] + 16'h20;
            end
            // Запись в порт
            1: begin
                tstate <= 1'b0;
                we     <= 1'b1;
                case (opcode[2:0])
                    0: data_o <= {din[7:1], opcode[9]};
                    1: data_o <= {din[7:2], opcode[9], din[0]};
                    2: data_o <= {din[7:3], opcode[9], din[1:0]};
                    3: data_o <= {din[7:4], opcode[9], din[2:0]};
                    4: data_o <= {din[7:5], opcode[9], din[3:0]};
                    5: data_o <= {din[7:6], opcode[9], din[4:0]};
                    6: data_o <= {din[  7], opcode[9], din[5:0]};
                    7: data_o <= {          opcode[9], din[6:0]};
                endcase
            end
        endcase
        // MUL
        16'b1001_11xx_xxxx_xxxx: begin
            pc      <= pcnext;
            alu     <= 23;
            op1     <= r[rd];
            op2     <= r[rr];
            reg_wm  <= 1;
        end
        // MULS d16..31, r16..31
        16'b0000_0010_xxxx_xxxx: begin
            pc      <= pcnext;
            alu     <= 24;
            op1     <= r[ {1'b1, opcode[7:4]} ];
            op2     <= r[ {1'b1, opcode[3:0]} ];
            reg_wm  <= 1;
        end
        // MULSU d16..23, r16..23
        16'b0000_0011_0xxx_0xxx: begin
            pc      <= pcnext;
            alu     <= 25;
            op1     <= r[ {2'b10, opcode[6:4]} ];
            op2     <= r[ {2'b10, opcode[2:0]} ];
            reg_wm  <= 1;
        end
    endcase
end
// Запись в регистры
always @(negedge clock)
if (ce) begin
    // Запись в регистр
    if (reg_w) r[ reg_id ] <= alu_res;
    // Запись в SREG
    if (sreg_w) sreg <= alu_sreg;
    // Инкремент или декремент
    case (sp_mth)
        SPDEC: sp <= sp - 1'b1;
        SPINC: sp <= sp + 1'b1;
    endcase
    // Автоинкремент или декремент X,Y,Z
    if (reg_ww) begin
        case (reg_idw)
            0: {r[25], r[24]} <= reg_ws ? resw : wb2; // W
            1: {r[27], r[26]} <= reg_ws ? resw : wb2; // X
            2: {r[29], r[28]} <= reg_ws ? resw : wb2; // Y
            3: {r[31], r[30]} <= reg_ws ? resw : wb2; // Z
        endcase
    end
    // Инструкции MUL
    if (reg_wm) {r[1], r[0]} <= resw;
    // Запись в порты или регистры
    if (we) begin
        case (address)
            // Системные регистры
            16'h005B: rampz         <= data_o; // Верхняя память ROM
            16'h005D: sp[ 7:0]      <= data_o; // SPL
            16'h005E: sp[15:8]      <= data_o; // SPH
            16'h005F: sreg          <= data_o; // SREG
            // Запись в регистры как в память
            default:  if (address < 16'h20) r[ address[4:0] ] <= data_o;
        endcase
    end
end
endmodule
// Режим работы АЛУ
// ---------------------------------------------------------------------
// 0 LDI    9  EOR      11 LSR      19 MULSU
// 1 CPC    A  OR       12 ROR
// 2 SBC    B  <SREG>   13 DEC
// 3 ADD    C  COM      14 ADIW
// 5 CP     D  NEG      15 SBIW
// 6 SUB    E  SWAP     16 BLD
// 7 ADC    F  INC      17 MUL
// 8 AND    10 ASR      18 MULS
// ---------------------------------------------------------------------
module alu
(
    // Ввод
    input      [4:0]  mode,         // режим
    input      [7:0]  d,            // dst
    input      [7:0]  r,            // src
    input      [7:0]  s,            // входящий s
    // Вывод
    output reg [7:0]  R,            // результат
    output reg [7:0]  S,            // s (новый)
    // 16 bit
    input      [15:0] op1w,
    output reg [15:0] resw
);
// Вычисления
wire [7:0] sub = d - r;
wire [7:0] add = d + r;
wire [8:0] sbc = d - r - s[0];
wire [7:0] adc = d + r + s[0];
wire [7:0] lsr = {1'b0, d[7:1]};
wire [7:0] ror = {s[0], d[7:1]};
wire [7:0] asr = {d[7], d[7:1]};
wire [7:0] neg = -d;
wire [7:0] inc = d + 1;
wire [7:0] dec = d - 1;
wire [7:0] com = d ^ 8'hFF;
wire [7:0] swap = {d[3:0], d[7:4]};
// 16 битные вычисления
wire [15:0] adiw  = op1w + r;
wire [15:0] sbiw  = op1w - r;
wire [15:0] mul   = d[7:0] * r[7:0];
wire [15:0] mulsu = {{8{d[7]}}, d[7:0]} * r[7:0];
wire [15:0] muls  = {{8{d[7]}}, d[7:0]} * {{8{r[7]}}, r[7:0]};
// Флаги переполнения после сложения и вычитания
wire add_flag_v = (d[7] &  r[7] & !R[7]) | (!d[7] & !r[7] & R[7]);
wire sub_flag_v = (d[7] & !r[7] & !R[7]) | (!d[7] &  r[7] & R[7]);
wire neg_flag_v =  R == 8'h80;
// Флаги половинного переполнения после сложения и вычитания
wire add_flag_h = ( d[3] & r[3]) | (r[3] & !R[3]) | (!R[3] &  d[3]);
wire sub_flag_h = (!d[3] & r[3]) | (r[3] &  R[3]) | ( R[3] & !d[3]);
wire neg_flag_h =   d[3] | (d[3] & R[3]) | R[3];
// Флаги ADIW, SBIW
wire adiw_c =  op1w[15] & !resw[15];
wire adiw_v = !op1w[15] &  resw[15];
// Логические флаги
wire [7:0] set_logic_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ s[5],
    /* s */ R[7],
    /* v */ 1'b0,
    /* n */ R[7],
    /* z */ R[7:0] == 0,
    /* c */ s[0]
};
// Флаги после вычитания с переносом
wire [7:0] set_subcarry_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ sub_flag_h,
    /* s */ sub_flag_v ^ R[7],
    /* v */ sub_flag_v,
    /* n */ R[7],
    /* z */ (R[7:0] == 0) & s[1],
    /* c */ sbc[8]
};
// Флаги после вычитания
wire [7:0] set_subtract_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ sub_flag_h,
    /* s */ sub_flag_v ^ R[7],
    /* v */ sub_flag_v,
    /* n */ R[7],
    /* z */ (R[7:0] == 0),
    /* c */ d < r
};
// Флаги после COM
wire [7:0] set_com_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ s[5],
    /* s */ R[7],
    /* v */ 1'b0,
    /* n */ R[7],
    /* z */ (R[7:0] == 0),
    /* c */ 1'b1
};
// Флаги после NEG
wire [7:0] set_neg_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ neg_flag_h,
    /* s */ neg_flag_v ^ R[7],
    /* v */ neg_flag_v,
    /* n */ R[7],
    /* z */ (R[7:0] == 0),
    /* c */ d != 0
};
// Флаги после сложения
wire [7:0] set_add_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ add_flag_h,
    /* s */ add_flag_v ^ R[7],
    /* v */ add_flag_v,
    /* n */ R[7],
    /* z */ (R[7:0] == 0),
    /* c */ d + r >= 9'h100
};
// Флаги после сложения с переносом
wire [7:0] set_adc_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ add_flag_h,
    /* s */ add_flag_v ^ R[7],
    /* v */ add_flag_v,
    /* n */ R[7],
    /* z */ (R[7:0] == 0),
    /* c */ d + r + s[0] >= 9'h100
};
// Флаги после логической операции сдвига вправо
wire [7:0] set_lsr_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ s[5],
    /* s */ d[0],
    /* v */ R[7] ^ d[0],
    /* n */ R[7],
    /* z */ (R[7:0] == 0),
    /* c */ d[0]
};
// Флаги после INC
wire [7:0] set_inc_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ s[5],
    /* s */ (R == 8'h80) ^ R[7],
    /* v */ (R == 8'h80),
    /* n */ R[7],
    /* z */ (R[7:0] == 0),
    /* c */ s[0]
};
// Флаги после DEC
wire [7:0] set_dec_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ s[5],
    /* s */ (R == 8'h7F) ^ R[7],
    /* v */ (R == 8'h7F),
    /* n */ R[7],
    /* z */ (R[7:0] == 0),
    /* c */ s[0]
};
// Флаги после ADIW
wire [7:0] set_adiw_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ s[5],
    /* s */ adiw_v ^ resw[15],
    /* v */ adiw_v,
    /* n */ resw[15],
    /* z */ (resw[15:0] == 0),
    /* c */ adiw_c
};
// Флаги после SBIW
wire [7:0] set_sbiw_flag = {
    /* i */ s[7],
    /* t */ s[6],
    /* h */ s[5],
    /* s */ adiw_c ^ resw[15],
    /* v */ adiw_c,
    /* n */ resw[15],
    /* z */ (resw[15:0] == 0),
    /* c */ adiw_v
};
// Флаги после MUL, MULS, MULSU
wire [7:0] set_mul_flag   = { s[7:2], /* z */ (mul  [15:0] == 0), /* c */ mul  [15]};
wire [7:0] set_muls_flag  = { s[7:2], /* z */ (muls [15:0] == 0), /* c */ muls [15]};
wire [7:0] set_mulsu_flag = { s[7:2], /* z */ (mulsu[15:0] == 0), /* c */ mulsu[15]};
always @(*) begin
    S = s;
    case (mode)
        /* LDI   */ 0:  begin R = r; end
        /* CPC   */ 1:  begin R = sbc[7:0]; S = set_subcarry_flag; end
        /* SBC   */ 2:  begin R = sbc[7:0]; S = set_subcarry_flag; end
        /* ADD   */ 3:  begin R = add;      S = set_add_flag;      end
        /* CP    */ 5:  begin R = sub;      S = set_subtract_flag; end
        /* SUB   */ 6:  begin R = sub;      S = set_subtract_flag; end
        /* ADC   */ 7:  begin R = adc;      S = set_adc_flag;      end
        /* AND   */ 8:  begin R = d & r;    S = set_logic_flag; end
        /* EOR   */ 9:  begin R = d ^ r;    S = set_logic_flag; end
        /* OR    */ 10: begin R = d | r;    S = set_logic_flag; end
        /* SREG  */ 11: begin S = r;        end
        /* COM   */ 12: begin R = com;      S = set_com_flag; end
        /* NEG   */ 13: begin R = neg;      S = set_neg_flag; end
        /* SWAP  */ 14: begin R = swap;     end
        /* INC   */ 15: begin R = inc;      S = set_inc_flag; end
        /* ASR   */ 16: begin R = asr;      S = set_lsr_flag; end
        /* LSR   */ 17: begin R = lsr;      S = set_lsr_flag; end
        /* ROR   */ 18: begin R = ror;      S = set_lsr_flag; end
        /* DEC   */ 19: begin R = dec;      S = set_dec_flag; end
        /* ADIW  */ 20: begin resw = adiw;  S = set_adiw_flag; end
        /* SBIW  */ 21: begin resw = sbiw;  S = set_sbiw_flag; end
        /* BLD   */ 22: begin
            case (r[2:0])
                0: R = {d[7:1], s[6]};
                1: R = {d[7:2], s[6], d[0]};
                2: R = {d[7:3], s[6], d[1:0]};
                3: R = {d[7:4], s[6], d[2:0]};
                4: R = {d[7:5], s[6], d[3:0]};
                5: R = {d[7:6], s[6], d[4:0]};
                6: R = {d[  7], s[6], d[5:0]};
                7: R = {        s[6], d[6:0]};
            endcase
        end
        /* MUL   */ 23: begin resw = mul;   S = set_mul_flag; end
        /* MULS  */ 24: begin resw = muls;  S = set_muls_flag; end
        /* MULSU */ 25: begin resw = mulsu; S = set_mulsu_flag; end
        default: R = 8'hFF;
    endcase
end
endmodule
