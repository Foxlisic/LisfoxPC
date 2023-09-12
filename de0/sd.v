module sd
(
    // 25 Mhz
    input               clock,
    input               reset_n,

    // Интерфейс с SPI
    output reg          SPI_CS,
    output reg          SPI_SCLK,
    input               SPI_MISO,
    output reg          SPI_MOSI,

    // Интерфейс
    input               sd_signal,  // =1 Прием команды
    input       [ 1:0]  sd_cmd,     // ID команды
    input       [ 7:0]  sd_out,     // Входящие данные из процессора
    output reg  [ 7:0]  sd_din,     // Исходящие данные в процессор
    output reg          sd_busy,    // =1 Устройство занято
    output              sd_timeout  // =1 Вышел таймаут
);

`define SPI_TIMEOUT_CNT     2500000

assign sd_timeout = (sd_timeout_cnt == `SPI_TIMEOUT_CNT);

reg  [24:0] sd_timeout_cnt;
reg  [2:0]  spi_process     = 0;
reg  [3:0]  spi_cycle       = 0;
reg  [7:0]  spi_data_w      = 0;
reg  [7:0]  spi_counter     = 0;
reg  [7:0]  spi_slow_tick   = 0;

always @(posedge clock)
if (reset_n == 1'b0) begin

    spi_process     <= 0;
    sd_timeout_cnt  <= `SPI_TIMEOUT_CNT;
    SPI_CS          <= 1'b1;
    SPI_SCLK        <= 1'b0;
    SPI_MOSI        <= 1'b0;
    sd_din          <= 8'h00;
    sd_busy         <= 1'b0;

end else begin

    if (sd_timeout_cnt < `SPI_TIMEOUT_CNT && spi_process == 0)
        sd_timeout_cnt <= sd_timeout_cnt + 1;

    case (spi_process)

        // Ожидание команды
        0: if (sd_signal) begin

            spi_process     <= 1 + sd_cmd;
            spi_counter     <= 0;
            spi_cycle       <= 0;
            spi_data_w      <= sd_out;
            sd_busy         <= 1;
            sd_timeout_cnt  <= 0;
            SPI_SCLK        <= 0;

        end

        // Command 1: Read/Write SPI
        1: case (spi_cycle)

            // CLK-DN
            0: begin

                SPI_SCLK    <= 0;
                spi_cycle   <= 1;
                SPI_MOSI    <= spi_data_w[7];
                spi_data_w  <= {spi_data_w[6:0], 1'b0};

            end
            1: begin spi_cycle <= 2; SPI_SCLK <= 1; end
            // CLK-UP
            2: begin spi_cycle <= 3; sd_din <= {sd_din[6:0], SPI_MISO}; end
            3: begin

                SPI_SCLK    <= 0;
                spi_cycle   <= 0;
                spi_counter <= spi_counter + 1;

                if (spi_counter == 7) begin

                    SPI_MOSI    <= 0;
                    sd_busy     <= 0;
                    spi_counter <= 0;
                    spi_process <= 0;

                end
            end

        endcase

        // INIT
        2: begin

            SPI_CS   <= 1;
            SPI_MOSI <= 1;

            // 125*100`000
            if (spi_slow_tick == (125 - 1)) begin

                SPI_SCLK      <= ~SPI_SCLK;
                spi_slow_tick <= 0;
                spi_counter   <= spi_counter + 1;

                // 80 ticks
                if (spi_counter == (2*80 - 1)) begin

                    SPI_SCLK    <= 0;
                    spi_process <= 0;
                    sd_busy     <= 0;

                end

            end
            // Оттикивание таймера
            else begin spi_slow_tick <= spi_slow_tick + 1; end

        end

        // CE0, CE1
        3, 4: begin SPI_CS <= ~spi_process[0]; spi_process <= 0; sd_busy <= 0; end

    endcase

end

endmodule
