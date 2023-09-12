@echo off

..\util\bin2mif\bin2mif.exe 64 16 main.bin ..\de0\mem_prg.mif
..\av\avemu.exe main.bin
