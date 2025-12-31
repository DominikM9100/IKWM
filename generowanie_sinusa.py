import math


def sv_sin( liczba_bitow=16, liczba_probek=256, amplituda=None, offset=0, ze_znakiem=1):
    if amplituda is None:
        amplituda = 2**(liczba_bitow-1) - 1

    if amplituda > 2**liczba_bitow-1:
        amplituda = 2**(liczba_bitow-1)-1

    print(f"parameter [{liczba_bitow-1}:0] sinus_lut [0:{liczba_probek-1}] = '{{")

    for i in range(liczba_probek):
        faza = (2.0 * math.pi * i) / liczba_probek
        wartosc = int(offset + amplituda * math.sin(faza) + 0.5)

        if i % 16 == 0:
            if i > 0:
                print()
            print("    ", end="")

        if i != liczba_probek-1:
            print(f"{wartosc}, ", end="")
        else:
            print(f"{wartosc} ", end="")

    print("\n};")

################################################################

def vhdl_sin( liczba_bitow=16, liczba_probek=256, amplituda=None, offset=0, ze_znakiem=1):
    if amplituda is None:
        amplituda = 2**(liczba_bitow-1) - 1

    if amplituda > 2**liczba_bitow-1:
        amplituda = 2**(liczba_bitow-1)-1

    print(f"type t_sin_lut is array (natural range <>) of std_logic_vector({liczba_bitow-1} downto 0);")
    print(f"constant sin_lut : t_sin_lut(0 to {liczba_probek-1}) := (")

    for i in range(liczba_probek):
        faza = (2.0 * math.pi * i) / liczba_probek
        wartosc = int(offset + amplituda * math.sin(faza))

        if i % 4 == 0:
            if i > 0:
                print()
            print("    ", end="")

        if ze_znakiem == 1:
            if i != liczba_probek-1:
                print(f"std_logic_vector(to_signed({wartosc}, {liczba_bitow})), ", end="")
            else:
                print(f"std_logic_vector(to_signed({wartosc}, {liczba_bitow})) ", end="")
        else:
            if i != liczba_probek-1:
                print(f"std_logic_vector(to_unsigned({wartosc}, {liczba_bitow})), ", end="")
            else:
                print(f"std_logic_vector(to_unsigned({wartosc}, {liczba_bitow})) ", end="")

    print("\n);")

################################################################

def c_sin( liczba_bitow=16, liczba_probek=256, amplituda=None, offset=0, ze_znakiem=1):
    if amplituda is None:
        amplituda = 2**(liczba_bitow-1) - 1

    if amplituda > 2**liczba_bitow-1:
        amplituda = 2**(liczba_bitow-1)-1

    if liczba_bitow <= 8:
        liczba_bitow = 8
    elif liczba_bitow <= 16:
        liczba_bitow = 16
    else:
        liczba_bitow = 32

    if ze_znakiem == 1:
        print(f"const int{liczba_bitow}_t sinus_lut[{liczba_probek}] = {{")
    else:
        print(f"const uint{liczba_bitow}_t sinus_lut[{liczba_probek}] = {{")

    for i in range(liczba_probek):
        faza = (2.0 * math.pi * i) / liczba_probek
        wartosc = int(offset + amplituda * math.sin(faza))

        if i % 16 == 0:
            if i > 0:
                print()
            print("    ", end="")

        if i != liczba_probek-1:
            print(f"{wartosc:3d}, ", end="")
        else:
            print(f"{wartosc:3d} ", end="")

    print("\n};")

################################################################




# sv_sin( liczba_bitow=16, liczba_probek=256, amplituda=100, offset=0, ze_znakiem=1)
# vhdl_sin( liczba_bitow=8, liczba_probek=8, amplituda=1000, offset=0, ze_znakiem=1)
c_sin( liczba_bitow=8, liczba_probek=256, amplituda=127, offset=127, ze_znakiem=0)