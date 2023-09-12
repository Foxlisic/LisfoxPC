FILES=avemu.o av.o cpu.o io.o assign.o sd.o disasm.o
CONF=-lSDL2 -Wall -lm

all: win
lin: $(FILES)
	g++ $(FILES) $(CONF) -o avemu

win: $(FILES)
	g++ $(FILES) -mwindows $(CONF) -o avemu.exe
	strip avemu.exe

# Общее правило для файлов
%.o: %.cc av.h
	g++ -c $< -O3 -o $@

clean:
	rm -f avemu avemu.exe *.o
