/* verilator lint_off WIDTH */

module video
(
    // Опорная частота 25 мгц
    input   wire        clock,

    // Выходные данные
    output  reg  [3:0]  r,          // 4 бит на красный
    output  reg  [3:0]  g,          // 4 бит на зеленый
    output  reg  [3:0]  b,          // 4 бит на синий
    output              hs,         // горизонтальная развертка
    output              vs,         // вертикальная развертка
    output              int,        // Срабатывает на x=0,y=0

    // Доступ к памяти
    output  reg  [16:0] char_address,
    output  reg  [11:0] font_address,
    input        [ 7:0] char_data,
    input        [ 7:0] font_data,

    // Внешний интерфейс
    input        [ 1:0] vmode,      // Видеорежим
    input        [ 2:0] border,     // ZX Border color
    input        [10:0] cursor      // Положение курсора от 0 до 2047
);

// ---------------------------------------------------------------------
// Тайминги для горизонтальной|вертикальной развертки (640x400)
// ---------------------------------------------------------------------

localparam

    hz_visible = 640, vt_visible = 400,
    hz_front   = 16,  vt_front   = 12,
    hz_sync    = 96,  vt_sync    = 2,
    hz_back    = 48,  vt_back    = 35,
    hz_whole   = 800, vt_whole   = 449;

assign hs  = x  < (hz_back + hz_visible + hz_front); // NEG.
assign vs  = y >= (vt_back + vt_visible + vt_front); // POS.
assign int = (x == 0 && y == 0);
// ---------------------------------------------------------------------
wire        xmax = (x == hz_whole - 1);
wire        ymax = (y == vt_whole - 1);
reg  [10:0] x    = 0;
reg  [10:0] y    = 0;
wire [10:0] X    = x - hz_back + 8; // X=[0..639]
wire [10:0] Xg   = x - hz_back + 2;
wire [ 9:0] Y    = y - vt_back;     // Y=[0..399]
wire [ 7:0] Xs   = X[9:1] - 24;
wire [ 7:0] Ys   = Y[9:1] - 4;
// ---------------------------------------------------------------------
reg         flash;
reg  [23:0] timer;
reg  [ 7:0] attr, char, tchr;
// ---------------------------------------------------------------------

wire [10:0] id = X[9:3] + (Y[8:4] * 80);
wire        maskbit = (char[ ~X[2:0] ]) | (flash && (id == cursor + 1) && Y[3:0] >= 14);
wire [ 3:0] kcolor = maskbit ? (attr[7] & flash ? attr[6:4] : attr[3:0]) : attr[6:4];
wire [15:0] color =

    kcolor == 4'h0 ? 12'h111 : // 0 Черный (почти)
    kcolor == 4'h1 ? 12'h008 : // 1 Синий (темный)
    kcolor == 4'h2 ? 12'h080 : // 2 Зеленый (темный)
    kcolor == 4'h3 ? 12'h088 : // 3 Бирюзовый (темный)
    kcolor == 4'h4 ? 12'h800 : // 4 Красный (темный)
    kcolor == 4'h5 ? 12'h808 : // 5 Фиолетовый (темный)
    kcolor == 4'h6 ? 12'h880 : // 6 Коричневый
    kcolor == 4'h7 ? 12'hCCC : // 7 Серый -- тут что-то не то
    kcolor == 4'h8 ? 12'h888 : // 8 Темно-серый
    kcolor == 4'h9 ? 12'h00F : // 9 Синий (темный)
    kcolor == 4'hA ? 12'h0F0 : // 10 Зеленый
    kcolor == 4'hB ? 12'h0FF : // 11 Бирюзовый
    kcolor == 4'hC ? 12'hF00 : // 12 Красный
    kcolor == 4'hD ? 12'hF0F : // 13 Фиолетовый
    kcolor == 4'hE ? 12'hFF0 : // 14 Желтый
                     12'hFFF;  // 15 Белый

// ZX Spectrum
// ---------------------------------------------------------------------

wire        current_bit = char[ 7 ^ Xs[2:0] ];
wire        flashed_bit = (attr[7] & flash) ^ current_bit;
wire        is_paper    = (X >= 64 && X < (64 + 512) && Y >= 8 && Y < (8 + 384));
wire [3:0]  src_color   = is_paper ? {attr[6], flashed_bit ? attr[2:0] : attr[5:3]} : border[2:0];

// Вычисляем цвет. Если бит 3=1, то цвет яркий, иначе обычного оттенка (половинной яркости)
wire [11:0] zxcolor =
{
    /* Красный цвет - это бит 1 */ src_color[1] ? (src_color[3] ? 4'hF : 4'hC) : 4'h01,
    /* Зеленый цвет - это бит 2 */ src_color[2] ? (src_color[3] ? 4'hF : 4'hC) : 4'h01,
    /* Синий цвет   - это бит 0 */ src_color[0] ? (src_color[3] ? 4'hF : 4'hC) : 4'h01
};

// Вывод видеосигнала
always @(posedge clock) begin

    // Кадровая развертка
    x <= xmax ?         0 : x + 1;
    y <= xmax ? (ymax ? 0 : y + 1) : y;

    // Вывод окна видеоадаптера
    if (x >= hz_back && x < hz_visible + hz_back && y >= vt_back && y < vt_visible + vt_back) begin
        case (vmode)
        0: {r, g, b} <= color;
        1: {r, g, b} <= {char[7:5],1'b0, char[4:2],1'b0, char[1:0], 2'b00}; // 3:3:2
        2: {r, g, b} <= zxcolor;
        endcase
    end
    else {r, g, b} <= 12'h000;

    // Выборка данных
    case (vmode)

    // Видеорежим 80x25
    0:  case (X[2:0])
        0: begin char_address <= {6'hF, id[10:0], 1'b0}; end
        2: begin font_address <= {char_data, Y[3:0]}; end
        4: begin char_address <= {6'hF, id[10:0], 1'b1}; end
        7: begin {attr, char} <= {char_data, font_data}; end
        endcase

    // 320x200x256 colors
    1:  case (Xg[0])
        0: begin char_address <= 17'hF000 + Xg[10:1] + Y[9:1]*320; end
        1: begin char <= char_data; end
        endcase

    // ZX Spectrum
    2:  case (X[3:0])
        0:  begin char_address <= 17'hE400 + {Ys[7:6], Ys[2:0], Ys[5:3], Xs[7:3]}; end
        1:  begin char_address <= 17'hE400 + {3'b110,  Ys[7:3],          Xs[7:3]}; tchr <= char_data; end
        15: begin {char, attr} <= {tchr, char_data}; end
        endcase

    endcase

    // Каждые 0,5 секунды перебрасывается регистр flash
    if (timer == 12500000-1) begin
        timer <= 0;
        flash <= ~flash;
    end else
        timer <= timer + 1;

end

endmodule
