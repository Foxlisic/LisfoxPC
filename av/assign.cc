#include "av.h"

// Применение маски к опкоду
void AVR::assign_mask(const char* mask, int opcode) {

    int i, j;
    int mk[16], nmask = 0, baseop = 0;

    // Расчет позиции, где находится маска
    for (i = 0; i < 16; i++) {

        int ch = mask[15-i];
        if (ch == '0' || ch == '1')
            baseop |= (ch == '1' ? 1 << i : 0);
        else
            mk[nmask++] = i;
    }

    // Перебрать 2^nmask вариантов, по количеству битов и назначить всем опкод
    for (i = 0; i < (1<<nmask); i++) {

        int instn = baseop;
        for (j = 0; j < nmask; j++) if (i & (1 << j)) instn |= (1 << mk[j]);
        map[instn] = opcode;
    }
}

// Создание инструкции
void AVR::assign() {

    int i;

    for (i = 0; i < 65536; i++) { sram[i] = i < 32 ? 0xFF : 0; program[i] = 0; }
    for (i = 0; i < 65536; i++) { map[i] = UNDEFINED; }

    sram[0x5D] = 0xFF;
    sram[0x5E] = 0xEF;
    sram[0x5F] = 0x00; // SREG

    // Очистка флагов
    flag.c = 0; flag.s = 0;
    flag.z = 0; flag.h = 0;
    flag.n = 0; flag.t = 0;
    flag.v = 0; flag.i = 0;

    // Копировать DOS палитру
    for (i = 0; i < 16; i++) {

        int bc = (DOS_13[i] & 0xF0) >> 4;
        int gc = (DOS_13[i] & 0xF000) >> 8;
        int rc = (DOS_13[i] & 0xF00000) >> 20;

        sram[0xFFA0 + 2*i] = bc | gc;
        sram[0xFFA1 + 2*i] = rc;
    }

    // Арифметические на 2 регистра
    assign_mask("000001rdddddrrrr", CPC);   // +
    assign_mask("000010rdddddrrrr", SBC);   // +
    assign_mask("000011rdddddrrrr", ADD);   // +
    assign_mask("000101rdddddrrrr", CP);    // +
    assign_mask("000110rdddddrrrr", SUB);   // +
    assign_mask("000111rdddddrrrr", ADC);   // +
    assign_mask("001000rdddddrrrr", AND);   // +
    assign_mask("001001rdddddrrrr", EOR);   // +
    assign_mask("001010rdddddrrrr", OR);    // +

    // Арифметика регистр + операнд K
    assign_mask("0011KKKKddddKKKK", CPI);   // +
    assign_mask("0100KKKKddddKKKK", SBCI);  // +
    assign_mask("0101KKKKddddKKKK", SUBI);  // +
    assign_mask("0110KKKKddddKKKK", ORI);   // +
    assign_mask("0111KKKKddddKKKK", ANDI);  // +
    assign_mask("10010110KKddKKKK", ADIW);  // +
    assign_mask("10010111KKddKKKK", SBIW);  // +

    // Условные и безусловные переходы
    assign_mask("1100kkkkkkkkkkkk", RJMP);  // +
    assign_mask("1101kkkkkkkkkkkk", RCALL); // +
    assign_mask("1001010100001000", RET);   // +
    assign_mask("1001010100011000", RETI);  // +
    assign_mask("111100kkkkkkksss", BRBS);  // +
    assign_mask("111101kkkkkkksss", BRBC);  // +
    assign_mask("1111110ddddd0bbb", SBRC);  // +
    assign_mask("1111111ddddd0bbb", SBRS);  // +
    assign_mask("10011001AAAAAbbb", SBIC);  // +
    assign_mask("10011011AAAAAbbb", SBIS);  // +
    assign_mask("000100rdddddrrrr", CPSE);  // +

    // Непрямые и длинные переходы
    assign_mask("1001010100001001", ICALL); // +
    assign_mask("1001010100011001", EICALL);// +
    assign_mask("1001010000001001", IJMP);  // +
    assign_mask("1001010000011001", EIJMP); // +
    assign_mask("1001010kkkkk111k", CALL);  // +
    assign_mask("1001010kkkkk110k", JMP);   // +

    // Перемещения
    assign_mask("1110KKKKddddKKKK", LDI);   // +
    assign_mask("001011rdddddrrrr", MOV);   // +
    assign_mask("1001000ddddd0000", LDS);   // +
    assign_mask("1001001ddddd0000", STS);   // +
    assign_mask("00000001ddddrrrr", MOVW);  // +
    assign_mask("1111100ddddd0bbb", BLD);   // +
    assign_mask("1111101ddddd0bbb", BST);   // +
    assign_mask("1001001ddddd0100", XCH);   // +

    // Однооперандные
    assign_mask("1001010ddddd0011", INC);   // +
    assign_mask("1001010ddddd1010", DEC);   // +
    assign_mask("1001010ddddd0110", LSR);   // +
    assign_mask("1001010ddddd0101", ASR);   // +
    assign_mask("1001010ddddd0111", ROR);   // +
    assign_mask("1001010ddddd0001", NEG);   // +
    assign_mask("1001010ddddd0000", COM);   // +
    assign_mask("1001010ddddd0010", SWAP);  // +
    assign_mask("1001001ddddd0110", LAC);   // +
    assign_mask("1001001ddddd0101", LAS);   // +
    assign_mask("1001001ddddd0111", LAT);   // +
    assign_mask("100101001sss1000", BCLR);  // +
    assign_mask("100101000sss1000", BSET);  // +
    assign_mask("10011000AAAAAbbb", CBI);   // +
    assign_mask("10011010AAAAAbbb", SBI);   // +

    // Косвенная загрузка из памяти
    assign_mask("1001000ddddd1100", LDX);   // +
    assign_mask("1001000ddddd1101", LDX_);  // +
    assign_mask("1001000ddddd1110", LD_X);  // +
    assign_mask("1001000ddddd1001", LDY_);  // +
    assign_mask("1001000ddddd1010", LD_Y);  // +
    assign_mask("10q0qq0ddddd1qqq", LDYQ);  // +
    assign_mask("1001000ddddd0001", LDZ_);  // +
    assign_mask("1001000ddddd0010", LD_Z);  // +
    assign_mask("10q0qq0ddddd0qqq", LDZQ);  // +

    // Косвенное сохранение
    assign_mask("1001001ddddd1100", STX);   // +
    assign_mask("1001001ddddd1101", STX_);  // +
    assign_mask("1001001ddddd1110", ST_X);  // +
    assign_mask("1001001ddddd1001", STY_);  // +
    assign_mask("1001001ddddd1010", ST_Y);  // +
    assign_mask("10q0qq1ddddd1qqq", STYQ);  // +
    assign_mask("1001001ddddd0001", STZ_);  // +
    assign_mask("1001001ddddd0010", ST_Z);  // +
    assign_mask("10q0qq1ddddd0qqq", STZQ);  // +

    // Загрузка из запись в память программ
    assign_mask("1001010111001000", LPM0Z);  // +
    assign_mask("1001000ddddd0100", LPMRZ);  // +
    assign_mask("1001000ddddd0101", LPMRZ_); // +
    assign_mask("1001010111101000", SPM);
    assign_mask("1001010111111000", SPM2);

    // Особые инструкции расширенной загрузки из памяти
    assign_mask("1001010111011000", ELPM0Z);  // +
    assign_mask("1001000ddddd0110", ELPMRZ);  // +
    assign_mask("1001000ddddd0111", ELPMRZ_); // +

    // Специальные
    assign_mask("1001010110001000", SLEEP); // +
    assign_mask("1001010110101000", WDR);   // +
    assign_mask("1001010110011000", BREAK); // +
    assign_mask("0000000000000000", NOP);   // +
    assign_mask("10110AAdddddAAAA", IN);    // +
    assign_mask("10111AAdddddAAAA", OUT);   // +
    assign_mask("1001001ddddd1111", PUSH);  // +
    assign_mask("1001000ddddd1111", POP);   // +
    assign_mask("10010100KKKK1011", DES);

    // Расширенные
    assign_mask("100111rdddddrrrr", MUL);
    assign_mask("00000010ddddrrrr", MULS);
    assign_mask("000000110ddd0rrr", MULSU);
    assign_mask("000000110ddd1rrr", FMUL);
}
