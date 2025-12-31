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


const uint8_t sinus_lut[64] = {
    127, 130, 133, 136, 139, 142, 145, 148, 151, 154, 157, 160, 163, 166, 169, 172, 
    175, 178, 181, 184, 186, 189, 192, 194, 197, 200, 202, 205, 207, 209, 212, 214, 
    216, 218, 221, 223, 225, 227, 229, 230, 232, 234, 235, 237, 239, 240, 241, 243, 
    244, 245, 246, 247, 248, 249, 250, 250, 251, 252, 252, 253, 253, 253, 253, 253
};


void czekaj(uint16_t liczba_cykli)
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
            {
                uint8_t cwiartka = i >> 6;
                uint8_t indeks = i & 0x3F;
                if (cwiartka & 1) indeks = 63 - indeks;     // dla cwiartek 1 i 3
                wartosc = sinus_lut[indeks];
                if (cwiartka & 2) wartosc = 254 - wartosc;  // dla cwiartek 2 i 3
                break;
            }

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