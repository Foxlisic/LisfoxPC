#include <string.h>
#include "av.h"

// Прочесть следующий опкод
int AVR::ds_fetch(uint16_t & addr) {

    int r = program[addr];
    addr = (addr + 1) & 0xFFFF;
    return r;
}

// Дизассемблировать адрес
int AVR::ds_decode(uint16_t addr) {

    int pvaddr = addr;

    // Прочесть опкод
    int opcode = ds_fetch(addr);

    // Непосредственное значение, если нужно
    int K = ((opcode & 0xF00) >> 4) | (opcode & 0xF);

    // Номера регистров и портов
    int Rd = (opcode & 0x1F0) >> 4;
    int Rr = (opcode & 0x00F) | ((opcode & 0x200) >> 5);
    int Ap = (opcode & 0x00F) | ((opcode & 0x600) >> 5);
    int Ka = (opcode & 0x00F) | ((opcode & 0x0C0) >> 2);

    // ADDR[7:0] = (~INST[8], INST[8], INST[10], INST[9], INST[3], INST[2], INST[1], INST[0])
    int Ld = (opcode & 0x00F) | ((opcode & 0x600) >> 5) | ((opcode & 0x100) >> 2) | (((~opcode) & 0x100) >> 1);

    // 00q0 qq00 0000 0qqq
    int Qi = (opcode & 0x007) | ((opcode & 0xC00)>>7) | ((opcode & 0x2000) >> 8);

    // Относительный переход
    int Rjmp = addr + ((opcode & 0x800) > 0 ? (opcode & 0x7FF) - 0x800 : (opcode & 0x7FF));
    int Bjmp = addr + ((opcode & 0x200) > 0 ? ((opcode & 0x1F8)>>3) - 0x40 : ((opcode & 0x1F8)>>3) );
    int Bit7 = opcode & 7;
    int bit7s = (opcode & 0x70) >> 4;
    int jmpfar = (((opcode & 0x1F0) >> 3) | (opcode & 1)) << 16;
    int append;

    // Получение всевозможных мнемоник
    char name_Rd[32];   sprintf(name_Rd,    "r%d", Rd);
    char name_Rr[32];   sprintf(name_Rr,    "r%d", Rr);
    char name_Rdi[32];  sprintf(name_Rdi,   "r%d", (0x10 | Rd));
    char name_K[32];    sprintf(name_K,     "$%02X", K);
    char name_Ap[32];   sprintf(name_Ap,    "$%02X", Ap);
    char name_Ap8[32];  sprintf(name_Ap8,   "$%02X", (opcode & 0xF8) >> 3);
    char name_rjmp[32]; sprintf(name_rjmp,  "$%04X", 2*Rjmp);
    char name_bjmp[32]; sprintf(name_bjmp,  "$%04X", 2*Bjmp);
    char name_lds[32];  sprintf(name_lds,   "$%02X", Ld);
    char name_Rd4[32];  sprintf(name_Rd4,   "r%d", (Rd & 0xF)*2);
    char name_Rr4[32];  sprintf(name_Rr4,   "r%d", (Rr & 0xF)*2);
    char name_adiw[32]; sprintf(name_adiw,  "r%d", 24 + ((opcode & 0x30)>>3));
    char name_Ka[32];   sprintf(name_Ka,    "$%02X", Ka);
    char name_bit7[4];  sprintf(name_bit7,  "%d", Bit7);

    // Смещение
    char name_Yq[32];   if (Qi) sprintf(name_Yq, "Y+%d", Qi); else sprintf(name_Yq, "Y");
    char name_Zq[32];   if (Qi) sprintf(name_Zq, "Z+%d", Qi); else sprintf(name_Zq, "Z");
    char name_LDD[32];  if (Qi) sprintf(name_LDD, "LDD"); else sprintf(name_LDD, "LD");
    char name_STD[32];  if (Qi) sprintf(name_STD, "STD"); else sprintf(name_STD, "ST");

    // Условие
    char name_brc[16];  sprintf(name_brc, "%s", ds_brcs[0][Bit7]);
    char name_brs[16];  sprintf(name_brs, "%s", ds_brcs[1][Bit7]);

    // Вывод
    char mnem[32], op1[32], op2[32]; op1[0] = 0; op2[0] = 0; sprintf(mnem, "<unk>");

    // Store/Load indirect LDD, STD
    switch (opcode & 0xD208) {

        case 0x8000: strcpy(mnem, name_LDD); strcpy(op1, name_Rd); strcpy(op2, name_Zq); break;
        case 0x8008: strcpy(mnem, name_LDD); strcpy(op1, name_Rd); strcpy(op2, name_Yq); break;
        case 0x8200: strcpy(mnem, name_STD); strcpy(op1, name_Zq); strcpy(op2, name_Rd); break;
        case 0x8208: strcpy(mnem, name_STD); strcpy(op1, name_Yq); strcpy(op2, name_Rd); break;
    }

    // Immediate
    switch (opcode & 0xF000) {

        case 0xC000: strcpy(mnem, "RJMP");  strcpy(op1, name_rjmp); break; // k
        case 0xD000: strcpy(mnem, "RCALL"); strcpy(op1, name_rjmp); break; // k
        case 0xE000: strcpy(mnem, "LDI");   strcpy(op1, name_Rdi); strcpy(op2, name_K); break; // Rd, K
        case 0x3000: strcpy(mnem, "CPI");   strcpy(op1, name_Rdi); strcpy(op2, name_K); break; // Rd, K
        case 0x4000: strcpy(mnem, "SBCI");  strcpy(op1, name_Rdi); strcpy(op2, name_K); break; // Rd, K
        case 0x5000: strcpy(mnem, "SUBI");  strcpy(op1, name_Rdi); strcpy(op2, name_K); break; // Rd, K
        case 0x6000: strcpy(mnem, "ORI");   strcpy(op1, name_Rdi); strcpy(op2, name_K); break; // Rd, K
        case 0x7000: strcpy(mnem, "ANDI");  strcpy(op1, name_Rdi); strcpy(op2, name_K); break; // Rd, K
    }

    // lds/sts 16 bit, in/out
    switch (opcode & 0xF800) {

        case 0xB000: strcpy(mnem, "IN");  strcpy(op1, name_Rd);  strcpy(op2, name_Ap);  break; // Rd, A
        case 0xB800: strcpy(mnem, "OUT"); strcpy(op1, name_Ap);  strcpy(op2, name_Rd);  break; // A, Rr
    }

    // bset/clr
    switch (opcode & 0xFF8F) {

        case 0x9408: strcpy(mnem, ds_brcs[2][ bit7s ]); break;
        case 0x9488: strcpy(mnem, ds_brcs[3][ bit7s ]); break;
    }

    // alu op1, op2
    switch (opcode & 0xFC00) {

        case 0x0400: strcpy(mnem, "CPC");  strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x0800: strcpy(mnem, "SBC");  strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x0C00: strcpy(mnem, "ADD");  strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x1C00: // Rd, Rr

            strcpy(mnem, Rd == Rr ? "ROL" : "ADC");
            strcpy(op1, name_Rd);
            if (Rr != Rd) { strcpy(op2, name_Rr); }
            break;

        case 0x2C00: strcpy(mnem, "MOV");  strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x9C00: strcpy(mnem, "MUL");  strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x1000: strcpy(mnem, "CPSE"); strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x1400: strcpy(mnem, "CP");   strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x1800: strcpy(mnem, "SUB");  strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x2000: strcpy(mnem, "AND");  strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x2400: strcpy(mnem, "EOR");  strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0x2800: strcpy(mnem, "OR");   strcpy(op1, name_Rd); strcpy(op2, name_Rr); break; // Rd, Rr
        case 0xF000: sprintf(mnem, "BR%s", name_brs); strcpy(op1, name_bjmp); break; // s, k
        case 0xF400: sprintf(mnem, "BR%s", name_brc); strcpy(op1, name_bjmp); break; // s, k
    }

    // Bit operation
    switch (opcode & 0xFE08) {

        case 0xF800: strcpy(mnem, "BLD");   strcpy(op1, name_Rd); strcpy(op2, name_bit7); break; // Rd, b
        case 0xFA00: strcpy(mnem, "BST");   strcpy(op1, name_Rd); strcpy(op2, name_bit7); break; // Rd, b
        case 0xFC00: strcpy(mnem, "SBRC");  strcpy(op1, name_Rd); strcpy(op2, name_bit7); break; // Rr, b
        case 0xFE00: strcpy(mnem, "SBRS");  strcpy(op1, name_Rd); strcpy(op2, name_bit7); break; // Rr, b
    }

    // jmp/call 24 bit
    switch (opcode & 0xFE0E) {

        case 0x940C: strcpy(mnem, "JMP");  append = ds_fetch(addr); sprintf(op1, "%05X", 2*(jmpfar + append)); break; // k2
        case 0x940E: strcpy(mnem, "CALL"); append = ds_fetch(addr); sprintf(op1, "%05X", 2*(jmpfar + append)); break; // k2
    }

    // ST/LD
    switch (opcode & 0xFE0F) {

        case 0x900F: strcpy(mnem, "POP");   strcpy(op1, name_Rd); break; // Rd
        case 0x920F: strcpy(mnem, "PUSH");  strcpy(op1, name_Rd); break; // Rd
        case 0x940A: strcpy(mnem, "DEC");   strcpy(op1, name_Rd); break; // Rd
        case 0x9204: strcpy(mnem, "XCH");   strcpy(op1, name_Rd); break; // Rr
        case 0x9205: strcpy(mnem, "LAS");   strcpy(op1, name_Rd); break; // Rr
        case 0x9206: strcpy(mnem, "LAC");   strcpy(op1, name_Rd); break; // Rr
        case 0x9207: strcpy(mnem, "LAT");   strcpy(op1, name_Rd); break; // Rr
        case 0x9400: strcpy(mnem, "COM");   strcpy(op1, name_Rd); break; // Rd
        case 0x9401: strcpy(mnem, "NEG");   strcpy(op1, name_Rd); break; // Rd
        case 0x9402: strcpy(mnem, "SWAP");  strcpy(op1, name_Rd); break; // Rd
        case 0x9403: strcpy(mnem, "INC");   strcpy(op1, name_Rd); break; // Rd
        case 0x9405: strcpy(mnem, "ASR");   strcpy(op1, name_Rd); break; // Rd
        case 0x9406: strcpy(mnem, "LSR");   strcpy(op1, name_Rd); break; // Rd
        case 0x9407: strcpy(mnem, "ROR");   strcpy(op1, name_Rd); break; // Rd
        case 0x900A: strcpy(mnem, "LD");    strcpy(op1, name_Rd); strcpy(op2, "-Y"); break; // Rd, -Y
        case 0x900C: strcpy(mnem, "LD");    strcpy(op1, name_Rd); strcpy(op2, "X");  break; // Rd, X
        case 0x900D: strcpy(mnem, "LD");    strcpy(op1, name_Rd); strcpy(op2, "X+"); break; // Rd, X+
        case 0x900E: strcpy(mnem, "LD");    strcpy(op1, name_Rd); strcpy(op2, "-X"); break; // Rd, -X
        case 0x9001: strcpy(mnem, "LD");    strcpy(op1, name_Rd); strcpy(op2, "Z+"); break; // Rd, Z+
        case 0x9002: strcpy(mnem, "LD");    strcpy(op1, name_Rd); strcpy(op2, "-Z"); break; // Rd, -Z
        case 0x9004: strcpy(mnem, "LPM");   strcpy(op1, name_Rd); strcpy(op2, "Z");  break; // Rd, Z
        case 0x9005: strcpy(mnem, "LPM");   strcpy(op1, name_Rd); strcpy(op2, "Z+"); break; // Rd, Z+
        case 0x9006: strcpy(mnem, "ELPM");  strcpy(op1, name_Rd); strcpy(op2, "Z");  break; // Rd, Z
        case 0x9007: strcpy(mnem, "ELPM");  strcpy(op1, name_Rd); strcpy(op2, "Z+"); break; // Rd, Z+
        case 0x9009: strcpy(mnem, "LD");    strcpy(op1, name_Rd); strcpy(op2, "Y+"); break; // Rd, Y+
        case 0x920C: strcpy(mnem, "ST");    strcpy(op1, "X");  strcpy(op2, name_Rd); break; // X, Rd
        case 0x920D: strcpy(mnem, "ST");    strcpy(op1, "X+"); strcpy(op2, name_Rd); break; // X+, Rd
        case 0x920E: strcpy(mnem, "ST");    strcpy(op1, "-X"); strcpy(op2, name_Rd); break; // -X, Rd
        case 0x9209: strcpy(mnem, "STD");   strcpy(op1, "Y+"); strcpy(op2, name_Rd); break; // Y+, Rd
        case 0x920A: strcpy(mnem, "STD");   strcpy(op1, "-Y"); strcpy(op2, name_Rd); break; // -Y, Rd
        case 0x9201: strcpy(mnem, "STD");   strcpy(op1, "Z+"); strcpy(op2, name_Rd); break; // Z+, Rd
        case 0x9202: strcpy(mnem, "STD");   strcpy(op1, "-Z"); strcpy(op2, name_Rd); break; // -Z, Rd

        case 0x9000:
        case 0x9200:

            strcpy(mnem, opcode & 0x0200 ? "STS" : "LDS");
            strcpy(op1, name_Rd);
            sprintf(op2, "$%04X", ds_fetch(addr));
            break;
    }

    // Word Ops
    switch (opcode & 0xFF00) {

        case 0x0100: strcpy(mnem, "MOVW"); strcpy(op1, name_Rd4);  strcpy(op2, name_Rr4);  break; // Rd+1:Rd, Rr+1:Rr
        case 0x0200: strcpy(mnem, "MULS"); strcpy(op1, name_Rd);   strcpy(op2, name_Rr);   break; // Rd, Rr
        case 0x9A00: strcpy(mnem, "SBI");  strcpy(op1, name_Ap8);  strcpy(op2, name_bit7); break; // A, b
        case 0x9B00: strcpy(mnem, "SBIS"); strcpy(op1, name_Ap8);  strcpy(op2, name_bit7); break; // A, b
        case 0x9600: strcpy(mnem, "ADIW"); strcpy(op1, name_adiw); strcpy(op2, name_Ka);   break; // Rd+1:Rd, K
        case 0x9700: strcpy(mnem, "SBIW"); strcpy(op1, name_adiw); strcpy(op2, name_Ka);   break; // Rd+1:Rd, K
        case 0x9800: strcpy(mnem, "CBI");  strcpy(op1, name_Ap8);  strcpy(op2, name_bit7); break; // A, b
        case 0x9900: strcpy(mnem, "SBIC"); strcpy(op1, name_Ap8);  strcpy(op2, name_bit7); break; // A, b
    }

    // DES
    switch (opcode & 0xFF0F) {

        case 0x940B: strcpy(mnem, "DES");  sprintf(op1, "$%02X", (opcode & 0xF0) >> 4); break; // K
    }

    // Multiply
    switch (opcode & 0xFF88) {

        case 0x0300: strcpy(mnem, "MULSU");  strcpy(op1, name_Rd); strcpy(op1, name_Rr); break; // Rd, Rr
        case 0x0308: strcpy(mnem, "FMUL");   strcpy(op1, name_Rd); strcpy(op1, name_Rr); break; // Rd, Rr
        case 0x0380: strcpy(mnem, "FMULS");  strcpy(op1, name_Rd); strcpy(op1, name_Rr); break; // Rd, Rr
        case 0x0388: strcpy(mnem, "FMULSU"); strcpy(op1, name_Rd); strcpy(op1, name_Rr); break; // Rd, Rr
    }

    // Одиночные
    switch (opcode & 0xFFFF) {

        case 0x0000: strcpy(mnem, "NOP");   break;
        case 0x95A8: strcpy(mnem, "WDR");   break;
        case 0x95C8: strcpy(mnem, "LPM");   strcpy(op1, "r0"); strcpy(op2, "Z"); break; // R0, Z
        case 0x95D8: strcpy(mnem, "ELPM");  strcpy(op1, "r0"); strcpy(op2, "Z"); break; // R0, Z
        case 0x9409: strcpy(mnem, "IJMP");  break;
        case 0x9419: strcpy(mnem, "EIJMP"); break;
        case 0x9508: strcpy(mnem, "RET");   break;
        case 0x9509: strcpy(mnem, "ICALL"); break;
        case 0x9518: strcpy(mnem, "RETI");  break;
        case 0x9519: strcpy(mnem, "EICALL"); break;
        case 0x95E8: strcpy(mnem, "SPM");   break;
        case 0x95F8: strcpy(mnem, "SPM.2"); break;
        case 0x9588: strcpy(mnem, "SLEEP"); break;
        case 0x9598: strcpy(mnem, "BREAK"); break;
    }

    // Дополнить пробелами
    int l_mnem = strlen(mnem);
    int l_op1  = strlen(op1);
    int l_op2  = strlen(op2);

    for (int i = l_mnem; i < 8; i++) strcat(mnem, " ");

    // Вывести строку
    if (l_op1 && l_op2) {
        sprintf(ds_line, "%s %s, %s", mnem, op1, op2);
    } else if (l_op1) {
        sprintf(ds_line, "%s %s", mnem, op1);
    } else {
        sprintf(ds_line, "%s", mnem);
    }

    return addr - pvaddr;
}
