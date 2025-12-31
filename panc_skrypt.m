%% Badanie Przetworników DAC (R, G, B)

clc; clear; close all;


%% 1. Wczytanie danych

fprintf('1. Wczytanie danych\n\n');

kanaly = {'r', 'g', 'b'};
predkosci = {'wolne', 'szybkie'};
sygnaly = {'pila', 'trojkat', 'prostokat', 'sinus'};
% sygnaly = {'pila', 'prostokat', 'sinus'};

for k = 1:length(kanaly)
    for p = 1:length(predkosci)
        for s = 1:length(sygnaly)
            nazwa_pliku = sprintf('%s_%s_%s.txt', kanaly{k}, sygnaly{s}, predkosci{p});
            
            % wczytanie danych
            if isfile(nazwa_pliku) % czy plik istnieje?
                temp_dane = load(nazwa_pliku); 
                
                % przypisz dane do struktury
                if size(temp_dane, 2) >= 2 % czy ma wiecej niz 1 kolumne
                    s_dane.(kanaly{k}).(predkosci{p}).(sygnaly{s}) = temp_dane(:, 2);
                else % czy jest tylko jedna kolumna
                    s_dane.(kanaly{k}).(predkosci{p}).(sygnaly{s}) = temp_dane;
                end
            else
                warning('Nie znaleziono pliku: %s', nazwa_pliku);
            end
        end
    end
end

fprintf('\n  Pomyślnie wczytano dane\n');


%% 2. Porównanie wartości skrajnych pomiędzy kanałami RGB

fprintf('\n\n\n2. Porównanie wartości skrajnych pomiędzy kanałami RGB\n\n');
max_kanal = zeros(1,3);
for k = 1:length(kanaly)
    max_kanal(k) = max(s_dane.(kanaly{k}).wolne.pila);
    fprintf('  Max wartosc w kanał %s: %.3f\n', upper(kanaly{k}), max_kanal(k));
end
fprintf('\n    Maksymalna rozbieznosc wartości maksymalnej pomiędzy kanałami: %.2f%%\n\n', (max(max_kanal)-min(max_kanal))/max(max_kanal)*100);

min_kanal = zeros(1,3);
for k = 1:length(kanaly)
    min_kanal(k) = min(s_dane.(kanaly{k}).wolne.pila);
    fprintf('  Min wartosc w kanał %s: %.3f\n', upper(kanaly{k}), min_kanal(k));
end
fprintf('\n    Maksymalna rozbieznosc wartości minimalnej pomiędzy kanałami: %.2f%%\n', (max(min_kanal)-min(min_kanal))/max(min_kanal)*100);


%% 3. Porównanie: wolne vs szybkie

fprintf('\n\n\n3. Porównanie: wolne vs szybkie\n\n');
fprintf('  Rzeczywiste poziomy maksymalny i minimalny\n');
figure('Name', 'Porownanie czasu ustalenia wartości sygnału (wolne vs szybkie)');

for k = 1:length(kanaly)
    dane_wolne = s_dane.(kanaly{k}).wolne.prostokat;
    dane_szybkie = s_dane.(kanaly{k}).szybkie.prostokat;
    x_min_wolne = dane_wolne(dane_wolne < 5);
    x_max_wolne = dane_wolne(dane_wolne > 250);
    x_min_szybkie = dane_szybkie(dane_szybkie < 5);
    x_max_szybkie = dane_szybkie(dane_szybkie > 250);

    x_min_wolne_srednie(1,k) = mean(x_min_wolne);
    x_max_wolne_srednie(1,k) = mean(x_max_wolne);
    x_min_szybkie_srednie(1,k) = mean(x_min_szybkie);
    x_max_szybkie_srednie(1,k) = mean(x_max_szybkie);
    fprintf('\n    Średnia wartość maksymalna dla sygnału wolnego w kanale %s:     %.3f\n', upper(kanaly{k}), x_max_wolne_srednie(k));
    fprintf('    Średnia wartość minimalna  dla sygnału wolnego w kanale %s:     %.3f\n', upper(kanaly{k}), x_min_wolne_srednie(k));
    fprintf('\n    Średnia wartość maksymalna dla sygnału szybkiego w kanale %s:   %.3f\n', upper(kanaly{k}), x_max_szybkie_srednie(k));
    fprintf('    Średnia wartość minimalna  dla sygnału szybkiego w kanale %s:   %.3f\n', upper(kanaly{k}), x_min_szybkie_srednie(k));

    subplot(1, 3, k);
    hold on;
    plot(dane_wolne, 'b', 'DisplayName', 'Wolne');
    plot(dane_szybkie, 'r', 'DisplayName', 'Szybkie');
    title(['Porownanie czasu narastania ' upper(kanaly{k})]);
    legend; grid on;
    hold off;
end


%% 4. Badanie Nieliniowości (DNL i INL) - Sygnał: PIŁA (wolne)

fprintf('\n\n\n4. Badanie nieliniowości (DNL i INL) - Sygnał: PIŁA (wolne)\n\n');
figure('Name', 'Analiza Nieliniowosci DNL/INL - Sygnał: PIŁA (wolne))');

for k = 1:length(kanaly)
    y = s_dane.(kanaly{k}).wolne.pila;
    
    kroki = diff(y); % wyznacz szerokosci przedzialow
    LSB = (x_max_wolne_srednie(k) - x_min_wolne_srednie(k)) / 255;
    
    % obliczenia
    DNL = (kroki / LSB) - 1;
    INL = cumsum(DNL);
    
    % DNL
    subplot(2, 3, k);
    bar(DNL); grid on;
    title(['DNL Kanał ' upper(kanaly{k})]);
    ylabel('DNL [LSB]'); xlabel('kwantyzacji');
    ylim([-100 100]);
    
    % INL
    subplot(2, 3, k+3);
    % plot(INL, 'LineWidth', 1.5); grid on;
    bar(INL); grid on;
    title(['INL Kanał ' upper(kanaly{k})]);
    ylabel('INL [LSB]'); xlabel('Przedział kwantyzacji');
    
    fprintf('  Kanał %s: Max DNL = %.2f, Max INL = %.2f\n', upper(kanaly{k}), max(abs(DNL)), max(abs(INL)));
end


%% 5. Badanie zniekształceń - Sygnał: SINUS (szybkie)
fprintf('\n\n\n5. Badanie zniekształceń - Sygnał: SINUS (szybkie)\n');
figure('Name', 'Znormalizowana FFT (Sinus Szybki)');

for k = 1:length(kanaly)
    y = s_dane.(kanaly{k}).szybkie.sinus; 
    N = length(y);
    f = (0:N-1);
    
    y_fft = abs(fft(y));
    
    % normalizuj względem największego prażka
    % z wyłączeniem składowej stałej
    max_y_fft = max(y_fft(2:end));
    y_norm = y_fft / max_y_fft;
    
    % zabezbiecz przed log10(0)
    y_db_norm = 20*log10(y_norm + eps);
    
    subplot(1, 3, k);
    plot(f, y_db_norm);
    grid on;
    
    title(['Znormalizowane FFT' upper(kanaly{k})]);
    ylabel('Amplituda [dB]');
    xlabel('Numer prążka');
    
    ylim([-100 5]);
end