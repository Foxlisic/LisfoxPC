DEVICE = atmega128
CLOCK  = 25000000
COMPILE = avr-gcc \
	-I../../include \
	-I../../include \
	-Wall \
	-Os \
	-DF_CPU=$(CLOCK) \
	-mmcu=$(DEVICE) \
	-fdata-sections \
	-Wl,--gc-sections,--defsym=__stack=0x80e3ff,--defsym=__heap_end=0x80e3ff

all: com win

win:
	make.bat
lin:
	../../av/avemu
com:
	$(COMPILE) main.cpp -o main.elf
	avr-objcopy -j .text -j .data -O binary main.elf main.bin
	avr-objdump -S main.elf > main.lst
	avr-size -C --mcu=$(DEVICE) main.elf > mem.map
	rm main.elf

clean:
	rm -f *.o rm *.elf *.lst *.bin *.map
