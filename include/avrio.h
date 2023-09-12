#ifndef __AVRIO_HFILE
#define __AVRIO_HFILE

#include <avr/interrupt.h>
#include <avr/pgmspace.h>

#define LPM(x) pgm_read_byte(&x)
#define LPW(t) pgm_read_word(&t)

// Ссылка на пустой адрес
#define NULL    ((void*)0)
#define brk     asm volatile("sleep"); // break

// Базовые типы данных
#define byte        unsigned char
#define uint        unsigned int
#define word        unsigned int
#define ulong       unsigned long
#define dword       unsigned long

// Описания всех портов
enum PortsID {

    BANK    = 0x00, // RW Банк памяти F000-FFFF
    VMODE   = 0x01, // RW Видеорежим
    KEYB    = 0x02, // R  Символ с клавиатуры
    SDCMD   = 0x0C, // RW Чтение или прием байта SD
    SDCTL   = 0x0D, // RW Команда 1=init, 2=ce0, 3-ce1
    CURX    = 0x0E, // RW Курсор по X
    CURY    = 0x0F, // RW Курсор по Y
    MASKS   = 0x10, // RW Маски прерывания
    ZXBORD  = 0x11, // RW ZX Border
};

// Список видеорежимов
enum VideoModes {

    VM_80x25        = 0,
    VM_320x200      = 1,
    VM_ZXSPECTRUM   = 2
};

enum IntrMasks {

    irq_vsync   = 1,
    irq_keyb    = 2,
};

// Чтение из порта
inline byte inp(int port) {
    return ((volatile byte*)0x20)[port];
}

// Запись в порт
inline void outp(int port, unsigned char val) {
    ((volatile unsigned char*)0x20)[port] = val;
}

// Объявление указателя на память (имя x, адрес a)
#define heap(x, a)  byte* x = (byte*) a
#define heapvm      byte* vm = (byte*) 0xF000
#define heapzx      byte* vm = (byte*) 0xE400
#define bank(x)     outp(BANK, x)
#define vmode(x)    outp(VMODE, x)
#define eoi         outp(KEYB, 255)
#define ei(x)       outp(MASKS, x); sei()

#endif
