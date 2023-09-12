#include <stdio.h>
#include <stdlib.h>

/**
 * Программа предназначена для конвертирования файлов в MIF 8/16
 */

int main(int argc, char** argv) {

    unsigned char*  binbyte = (unsigned char*)  malloc(256*1024);
    unsigned short* bin     = (unsigned short*) malloc(128*1024*2);

    for (int i = 0; i < 128*1024; i++) bin[i] = 0;

    if (argc < 5) {

        printf("USAGE: bin2mif.exe items bits in.bin out.mif\n");
        printf("WHERE:\n");
        printf("  items     -- count of byte/words (kiloword)\n");
        printf("  bits      -- 8 or 16\n");
        printf("  in.bin    -- INPUT file\n");
        printf("  out.mif   -- OUTPUT file\n");

    } else {

        int size = atoi(argv[1]) * 1024; // Kb
        int bits = atoi(argv[2]);        // 8 | 16

        FILE* fi = fopen(argv[3], "rb");
        FILE* fo = fopen(argv[4], "w");

        if (fi) {

            fprintf(fo, "WIDTH=%d;\n", bits);
            fprintf(fo, "DEPTH=%d;\n", size);
            fprintf(fo, "ADDRESS_RADIX=HEX;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n");

            int a = 0, asize;

            // Разный уровень загрузки
            if (bits == 8) {
                asize = fread(binbyte, 1, 256*1024, fi);
                for (int i = 0; i < asize; i++) bin[i] = binbyte[i];
            } else {
                asize = fread(bin, 2, 128*1024, fi);
            }

            fclose(fi);

            // RLE-кодирование
            while (a < asize) {

                // Поиск однотонных блоков
                int b; for (b = a + 1; b < asize && bin[a] == bin[b]; b++);

                // Если найденный блок длиной до 0 до 2 одинаковых символов
                if (b - a < 3) {
                    for (int i = a; i < b; i++) fprintf(fo, "  %X: %X;\n", a++, bin[i]);
                } else {
                    fprintf(fo, "  [%X..%X]: %X;\n", a, b - 1, bin[a]);
                    a = b;
                }
            }

            if (asize < size) fprintf(fo, "  [%X..%X]: 0;\n", asize, size - 1);
            fprintf(fo, "END\n", bits);

        } else {
            printf("FILE %s :: 404 NOT FOUND\n", argv[2]);
        }
    }

    return 0;
}
