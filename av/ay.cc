enum AY_PARAM
{
    AY_ENV_HOLD     = 1,
    AY_ENV_ALT      = 2,
    AY_ENV_ATTACK   = 4,
    AY_ENV_CONT     = 8
};

// AY-3-8910 Уровни
static const int ay_levels[16] =
{
    0x0000, 0x0385, 0x053D, 0x0770,
    0x0AD7, 0x0FD5, 0x15B0, 0x230C,
    0x2B4C, 0x43C1, 0x5A4B, 0x732F,
    0x9204, 0xAFF1, 0xD921, 0xFFFF
};

class AYChip {

protected:

    int ay_regs[16];
    int ay_amp[3];
    int ay_tone_tick[3],
        ay_tone_period[3],
        ay_tone_high[3],
        ay_tone_levels[16];
    int ay_noise_toggle,
        ay_noise_period,
        ay_noise_tick,
        ay_rng;
    int ay_env_tick,
        ay_env_period,
        ay_env_first,
        ay_env_rev,
        ay_env_counter = 0,
        ay_env_internal_tick = 0,
        ay_env_cycles;
    int ay_mono;
    int cur_cycle;

    // ---
    int frequency = 44100; // 44100, 22050, 11025

public:

    AYChip() {

        int i;

        // Коррекция уровня (128 == 0 уровень)
        for (int i = 0; i < 16; i++) {
            ay_tone_levels[i] = (ay_levels[i]*256 + 0x8000) / 0xFFFF;
        }

        // Первичная инициализация
        for (int i = 0; i < 3; i++) {

            ay_tone_high[i]   = 0;
            ay_tone_tick[i]   = 0;
            ay_tone_period[i] = 1;
        }

        ay_mono     = 0;
        ay_env_tick = 0;
        cur_cycle   = 0;
        ay_rng      = 1;
        ay_env_internal_tick = 0;

        // Инициализация регистров в FFh изначально всех
        for (int i = 0; i < 16; i++) ay_regs[i] = i == 7 ? 0xFF : 0x00;
    }

    // Запись данных в регистр
    void write(int ay_register, int ay_data) {

        int reg_id  = ay_register & 15;
        int tone_id = reg_id >> 1;        // Биты [3:1] Номер частоты тона

        ay_regs[reg_id] = ay_data;

        switch (reg_id) {

            // Тоны (0-2)
            case 0: case 1:
            case 2: case 3:
            case 4: case 5:

                // Получение значения тона из регистров AY
                ay_tone_period[tone_id] = 256*(ay_regs[(reg_id & ~1) | 1] & 15) + ay_regs[reg_id & ~1];

                // Недопуск бесконечной частоты
                if (ay_tone_period[tone_id] == 0)
                    ay_tone_period[tone_id] = 1;

                // Это типа чтобы звук не был такой обалдевший
                if (ay_tone_tick[tone_id] >= 2*ay_tone_period[tone_id])
                    ay_tone_tick[tone_id] %= 2*ay_tone_period[tone_id];

                break;

            // Сброс шума
            case 6:

                ay_noise_tick   = 0;
                ay_noise_period = ay_regs[6] & 0x0F;
                break;

            // Период огибающей
            case 11:
            case 12:

                ay_env_period = ay_regs[11] | (ay_regs[12] << 8);
                break;

            // Запись команды для огибающей, сброс всех счетчиков
            case 13:

                ay_env_first         = 1;
                ay_env_rev           = 0;
                ay_env_internal_tick = 0;
                ay_env_tick          = 0;
                ay_env_cycles        = 0;
                ay_env_counter       = (ay_regs[13] & AY_ENV_ATTACK) ? 0 : 15;
                break;
        }
    }

    // Срабатывает каждые 32 такта Z80 процессора 3.5 Мгц (109.375 Khz)
    int tick() {

        int mixer    = ay_regs[7];
        int envshape = ay_regs[13];

        // Задание уровней звука для тонов
        int levels[3];

        // Генерация начальных значений громкости
        for (int n = 0; n < 3; n++) {

            int g = ay_regs[8 + n];

            // Если на 4-м бите громкости тона стоит единица, то взять громкость огибающей
            levels[n] = ay_tone_levels[(g & 16 ? ay_env_counter : g) & 15];
        }

        // Обработчик "огибающей" (envelope)
        ay_env_tick++;

        // Если резко поменялся period, то может быть несколько проходов
        while (ay_env_tick >= ay_env_period) {

            ay_env_tick -= ay_env_period;

            // Внутренний таймер
            ay_env_internal_tick++;

            // Выполнить первые 1/16 периодический INC/DEC если нужно
            // 1. Это первая запись в регистр r13
            // 2. Или это Cont=1 и Hold=0
            if (ay_env_first || ((envshape & AY_ENV_CONT) && !(envshape & AY_ENV_HOLD))) {

                // Направление движения: вниз (ATTACK=1) или вверх
                if (ay_env_rev)
                     ay_env_counter -= (envshape & AY_ENV_ATTACK) ? 1 : -1;
                else ay_env_counter += (envshape & AY_ENV_ATTACK) ? 1 : -1;

                // Проверка на достижения предела
                if      (ay_env_counter <  0) ay_env_counter = 0;
                else if (ay_env_counter > 15) ay_env_counter = 15;
            }

            // Срабатывает каждые 16 циклов AY
            if (ay_env_internal_tick >= 16) {

                // Сброс счетчика (ay_env_internal_tick -= 16;)
                ay_env_internal_tick = 0;

                // Конец цикла для CONT, если CONT=0, то остановка счетчика
                if ((envshape & AY_ENV_CONT) == 0) {
                    ay_env_counter = 0;

                } else {

                    // Опция HOLD=1
                    if (envshape & AY_ENV_HOLD) {

                        // Пилообразная фигура
                        if (ay_env_first && (envshape & AY_ENV_ALT))
                            ay_env_counter = (ay_env_counter ? 0 : 15);
                    }
                    // Опция HOLD=0
                    else {

                        if (envshape & AY_ENV_ALT)
                             ay_env_rev     = !ay_env_rev;
                        else ay_env_counter = (envshape & AY_ENV_ATTACK) ? 0 : 15;
                    }
                }

                ay_env_first = 0;
            }

            // Выход, если период нулевой
            if (!ay_env_period) break;
        }

        // Обработка тонов
        for (int _tone = 0; _tone < 3; _tone++) {

            int level = levels[_tone];

            // При деактивированном тоне тут будет либо огибающая,
            // либо уровень, указанный в регистре тона
            ay_amp[_tone] = level;

            // Тон активирован
            if ((mixer & (1 << _tone)) == 0) {

                // Счетчик следующей частоты
                ay_tone_tick[_tone] += 2;

                // Переброска состояния 0->1,1->0
                if (ay_tone_tick[_tone] >= ay_tone_period[_tone]) {
                    ay_tone_tick[_tone] %= ay_tone_period[_tone];
                    ay_tone_high[_tone] = !ay_tone_high[_tone];
                }

                // Генерация меандра
                ay_amp[_tone] = ay_tone_high[_tone] ? level : 0;
            }

            // Включен шум на этом канале. Он работает по принципу
            // что если включен тон, и есть шум, то он притягивает к нулю
            if ((mixer & (8 << (_tone))) == 0 && ay_noise_toggle) {
                ay_amp[_tone] = 0;
            }
        }

        // Обновление noise-фильтра
        ay_noise_tick += 1;

        // Использовать генератор шума пока не будет достигнут нужный период
        while (ay_noise_tick >= ay_noise_period) {

            // Если тут 0, то все равно учитывать, чтобы не пропускать шум
            ay_noise_tick -= ay_noise_period;

            // Это псевдогенератор случайных чисел на регистре 17 бит
            // Бит 0: выход; вход: биты 0 xor 3.
            if ((ay_rng & 1) ^ ((ay_rng & 2) ? 1 : 0))
                ay_noise_toggle = !ay_noise_toggle;

            // Обновление значения
            if (ay_rng & 1) ay_rng ^= 0x24000; /* и сдвиг */ ay_rng >>= 1;

            // Если период нулевой, то этот цикл не закончится
            if (!ay_noise_period) break;
        }

        // +32 такта
        cur_cycle += 32*frequency;

        // Частота хост-процессора 3.5 Мгц
        if (cur_cycle  > 3500000) {
            cur_cycle %= 3500000;
            return 0;
        } else {
            return 1;
        }
    }

    // Взять текущий уровень
    void get(int& left, int& right) {

        // Каналы A-слева; B-посередине; C-справа
        left  = 128 + (ay_amp[0] + (ay_amp[1]/2)) / 4;
        right = 128 + (ay_amp[2] + (ay_amp[1]/2)) / 4;

        if (left  > 255) left  = 255; else if (left  < 0) left  = 0;
        if (right > 255) right = 255; else if (right < 0) right = 0;
    }
};
