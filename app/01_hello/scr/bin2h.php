<?php

$file = isset($argv[1]) ? $argv[1] : stdin;
$file = file_get_contents($file);
$size = strlen($file);

$out = [];
for ($i = 0; $i < $size; $i++) {
    $out[] = sprintf("0x%02X", ord($file[$i])) . ($i < $size - 1 ? "," : "") . (($i % 16) == 15 ? "\n" : "");
}

$out = "extern const unsigned char WALLPAPER[] PROGMEM;\nconst unsigned char WALLPAPER[] = {\n".join($out)."\n};";
file_put_contents($argv[2], $out);
