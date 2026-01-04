#include <stdio.h>
#include <system.h>
#include <unistd.h>
#include <stdint.h>
#include "altera_avalon_pio_regs.h"


#define SW0                     0
#define SW1                     1
#define SW2                     2
#define SW3                     3
#define SYG_PILA                (1 << SW0)
#define SYG_TROJKAT             (1 << SW1)
#define SYG_PROSTOKAT           (1 << SW2)
#define SYG_SINUS               (1 << SW3)


const uint8_t sinus_lut[256] = {
    128, 131, 134, 137, 140, 143, 146, 149, 152, 155, 158, 162, 165, 167, 170, 173, 
    176, 179, 182, 185, 188, 190, 193, 196, 198, 201, 203, 206, 208, 211, 213, 215, 
    218, 220, 222, 224, 226, 228, 230, 232, 234, 235, 237, 238, 240, 241, 243, 244, 
    245, 246, 248, 249, 250, 250, 251, 252, 253, 253, 254, 254, 254, 255, 255, 255, 
    255, 255, 255, 255, 254, 254, 254, 253, 253, 252, 251, 250, 250, 249, 248, 246, 
    245, 244, 243, 241, 240, 238, 237, 235, 234, 232, 230, 228, 226, 224, 222, 220, 
    218, 215, 213, 211, 208, 206, 203, 201, 198, 196, 193, 190, 188, 185, 182, 179, 
    176, 173, 170, 167, 165, 162, 158, 155, 152, 149, 146, 143, 140, 137, 134, 131, 
    128, 124, 121, 118, 115, 112, 109, 106, 103, 100,  97,  93,  90,  88,  85,  82, 
     79,  76,  73,  70,  67,  65,  62,  59,  57,  54,  52,  49,  47,  44,  42,  40, 
     37,  35,  33,  31,  29,  27,  25,  23,  21,  20,  18,  17,  15,  14,  12,  11, 
     10,   9,   7,   6,   5,   5,   4,   3,   2,   2,   1,   1,   1,   0,   0,   0, 
      0,   0,   0,   0,   1,   1,   1,   2,   2,   3,   4,   5,   5,   6,   7,   9, 
     10,  11,  12,  14,  15,  17,  18,  20,  21,  23,  25,  27,  29,  31,  33,  35, 
     37,  40,  42,  44,  47,  49,  52,  54,  57,  59,  62,  65,  67,  70,  73,  76, 
     79,  82,  85,  88,  90,  93,  97, 100, 103, 106, 109, 112, 115, 118, 121, 124 
};
// const uint8_t sinus_lut[64] = {
//     127, 130, 133, 136, 139, 142, 145, 148, 151, 154, 157, 160, 163, 166, 169, 172, 
//     175, 178, 181, 184, 186, 189, 192, 194, 197, 200, 202, 205, 207, 209, 212, 214, 
//     216, 218, 221, 223, 225, 227, 229, 230, 232, 234, 235, 237, 239, 240, 241, 243, 
//     244, 245, 246, 247, 248, 249, 250, 250, 251, 252, 252, 253, 253, 253, 253, 253
// };


// sw[11:4] == 8'hFF // min f: 256 * 255 us = 65280 us ~ 15,319 Hz
// sw[11:4] == 8'h00 // max f: 256 *   1 us =   256 us ~  3,906 khz
void czekaj (uint16_t liczba_cykli)
{
    uint16_t opoznienie = liczba_cykli;
    if (opoznienie == 0) opoznienie = 1;
    for (uint16_t i = 0; i < opoznienie; i++) {
        usleep(1);
    }
}


int main (void)
{
    uint16_t sw = 0;
    uint16_t typ_sygnalu = 0;
    uint16_t liczba_cykli = 0;
    uint8_t i = 0;

    uint32_t dane = 0;
    uint8_t wartosc = 0;

    while (1)
    {
        sw = IORD_ALTERA_AVALON_PIO_DATA(PIO_SWITCH_BASE);
        typ_sygnalu = sw & 0x000F;
        liczba_cykli = sw >> 4;

        switch (typ_sygnalu)
        {
            case SYG_PILA:
                wartosc = i;
                break;

            case SYG_TROJKAT:
                wartosc = (i < 128) ? i : 255-i;
                break;

            case SYG_PROSTOKAT:
                wartosc = (i < 128) ? 255 : 0;
                break;

            case SYG_SINUS:
                wartosc = sinus_lut[i];
                break;

            // case SYG_SINUS:
            // {
            //     uint8_t cwiartka = i >> 6;
            //     uint8_t indeks = i & 0x3F;
            //     if (cwiartka & 1) indeks = 63 - indeks;     // dla cwiartek 1 i 3
            //     wartosc = sinus_lut[indeks];
            //     if (cwiartka & 2) wartosc = 254 - wartosc;  // dla cwiartek 2 i 3
            //     break;
            // }

            default:
                IOWR_ALTERA_AVALON_PIO_DATA(PIO_VGA_BASE, 0);
                continue;
                break;
        }

        dane = (wartosc << 16) | (wartosc << 8) | wartosc; // wpisz to samo do trzech DAC RGB
        IOWR_ALTERA_AVALON_PIO_DATA(PIO_VGA_BASE, 0x00FFFFFF & dane);
        czekaj(0x00FF & liczba_cykli);
        i++;
    }

    return 0;
}