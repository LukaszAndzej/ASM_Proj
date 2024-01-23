.model small
.stack 100h

.data
    debugMsg db 'Inicjalizacja zakonczona$', 13, 10, '$'
    score dw 0                    ; Zmienna do przechowywania wyniku (16-bitowa)
    difficulty dw 1               ; Poziom trudności (16-bitowy)
    movingObjects db 7*2 dup(0)   ; Tablica na poruszające się obiekty, każdy 2 bajty
    projectileX db 40             ; Początkowa pozycja X pocisku (na środku ekranu)
    projectileY db 24             ; Początkowa pozycja Y pocisku (u dołu ekranu)
    projectileActive db 0         ; Flaga aktywności pocisku
    objectChar db '*'             ; Znak reprezentujący obiekt
    projectileChar db '^'         ; Znak reprezentujący pocisk
    keyPress db 0                 ; Zmienna do przechowywania ostatniego naciśnięcia klawisza
    gameOverFlag db 0             ; Flaga końca gry
    gameOverMsg db 'Gra zakonczona! Twoj wynik: $'
    scoreMsg db 13, 10, 'Wynik: $'
    numberBuffer db 6 dup(0)      ; Bufor na liczbę (5 cyfr + znak końca łańcucha)

.code
start:
    ; Ustawienie trybu tekstowego 80x25
    mov ah, 0            ; Funkcja ustawienia trybu wideo
    mov al, 03           ; Tryb tekstowy 80x25, 16 kolorów
    int 10h              ; Wywołanie przerwania wideo

    ; Inicjalizacja zmiennej wyniku
    mov ax, 0
    mov [score], ax

    ; Inicjalizacja poziomu trudności
    mov ax, 1
    mov [difficulty], ax

    ; Inicjalizacja poruszających się obiektów
    mov si, offset movingObjects  ; Ustawienie wskaźnika na początek tablicy obiektów
    mov cx, 7                     ; Liczba obiektów
init_loop:
    push ax
    push dx
    call randomX
    pop dx
    mov [si], al                 ; Zapisanie pozycji X do tablicy
    inc si

    push ax
    call randomY
    pop ax
    mov [si], al                 ; Zapisanie pozycji Y do tablicy
    inc si
    loop init_loop

main_loop:
    call clearScreen         ; Czyszczenie ekranu
    call displayObjects      ; Wyświetlenie obiektów
    call getInput            ; Odbieranie wejścia od użytkownika
    call updateGame          ; Aktualizacja stanu gry
    call checkGameOver       ; Sprawdzenie warunków końca gry

    mov al, [gameOverFlag]
    or al, al
    jnz gameOverSequence     ; Jeśli gra się zakończyła, przejdź do sekwencji końcowej

    call delay               ; Krótkie opóźnienie, aby gra nie działała zbyt szybko

    jmp main_loop            ; Kontynuacja pętli gry

randomX proc
    ; Prosta funkcja generująca losową pozycję X (0-79)
    mov ah, 0                   ; Funkcja zegara systemowego
    int 1Ah                     ; Pobiera wartość rejestru CX (czas systemowy)
    mov ax, cx
    and ax, 007Fh               ; Ogranicza AX do zakresu 0-79
    ret
randomX endp

randomY proc
    ; Prosta funkcja generująca losową pozycję Y (0-24)
    mov ah, 0                   ; Funkcja zegara systemowego
    int 1Ah                     ; Pobiera wartość rejestru CX (czas systemowy)
    mov ax, cx
    and ax, 001Fh               ; Ogranicza AX do zakresu 0-24
    ret
randomY endp

gameOverSequence proc
    push ax
    push bx
    push dx

    ; Czyszczenie ekranu
    call clearScreen

    ; Ustawienie kursora na środku ekranu
    mov dh, 12                   ; Współrzędna Y kursora
    mov dl, 40                   ; Współrzędna X kursora
    mov bh, 0                    ; Numer strony
    mov ah, 02h                  ; Funkcja ustawienia pozycji kursora
    int 10h

    ; Wyświetlenie komunikatu o zakończeniu gry
    mov ah, 09h
    lea dx, gameOverMsg
    int 21h

    ; Wyświetlenie wyniku
    mov ah, 09h
    lea dx, scoreMsg
    int 21h
    mov ax, [score]
    call printNumber            ; Procedura do wyświetlenia liczby

    ; Opcja zrestartowania gry lub wyjścia
    ; Wyjście z programu
    mov ax, 4C00h
    int 21h

    pop dx
    pop bx
    pop ax
    ret
gameOverSequence endp

; Procedury używane w pętli
displayObjects proc
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, offset movingObjects  ; Ustawienie wskaźnika na początek tablicy obiektów
    mov cx, 7                     ; Liczba obiektów

display_loop:
    ; Wczytanie współrzędnych obiektu
    mov al, [si]                 ; Wczytanie współrzędnej X
    mov ah, 0                    ; Czyszczenie ah
    mov dl, [si+1]               ; Wczytanie współrzędnej Y
    inc si
    inc si

    ; Obliczenie adresu w pamięci wideo
    mov bh, 0                    ; Numer strony (zazwyczaj 0)
    mov bl, 2                    ; Atrybut (np. kolor)
    mov dh, dl                   ; Współrzędna Y
    mov dl, al                   ; Współrzędna X
    shl dx, 1                    ; Przesunięcie współrzędnej Y (bo każda linia ma 2 bajty na znak)
    mov ax, 0B800h               ; Segment pamięci wideo dla trybu tekstowego
    mov es, ax
    mov ax, 160                  ; Liczba bajtów na wiersz (80 znaków * 2 bajty/znak)
    mul dh                       ; AX = AX * DH
    add ax, dx                   ; Dodanie współrzędnej X
    shl ax, 1                    ; Przesunięcie o 1, aby uwzględnić atrybuty znaku
    mov di, ax                   ; Ustawienie DI na odpowiednią pozycję w pamięci wideo

    ; Wyświetlenie znaku obiektu
    mov al, objectChar
    stosw                        ; Zapisuje AL do ES:DI i zwiększa DI

    loop display_loop

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
displayObjects endp

getInput proc
    ; Sprawdzenie, czy naciśnięto klawisz
    mov ah, 01h
    int 16h
    jz no_key_pressed
    mov ah, 00h
    int 16h           ; Pobranie naciśniętego klawisza
    mov [keyPress], al
no_key_pressed:
    ret
getInput endp

updateGame proc
    push ax
    push bx
    push cx
    push dx
    push si

    ; Aktualizacja pozycji obiektów
    mov si, offset movingObjects  ; Ustawienie wskaźnika na początek tablicy obiektów
    mov cx, 7                     ; Liczba obiektów

update_loop:
    ; Załóżmy, że obiekty poruszają się w dół ekranu
    mov al, [si+1]               ; Wczytanie współrzędnej Y
    inc al                       ; Zwiększenie Y (poruszanie się w dół)
    cmp al, 25                   ; Sprawdzenie, czy obiekt wyszedł poza ekran
    jl update_position
    call randomY                ; Wylosuj nową pozycję Y dla obiektu
update_position:
    mov [si+1], al               ; Aktualizacja współrzędnej Y
    add si, 2                    ; Przejście do następnego obiektu

    loop update_loop

    ; Obsługa naciśnięcia klawisza
    mov al, [keyPress]
    or al, al                    ; Sprawdzenie, czy klawisz został naciśnięty
    jz skip_key_press            ; Skok, jeśli żaden klawisz nie został naciśnięty

    ; Obsługa naciśnięcia spacji (strzelanie)
    cmp al, 32                   ; Sprawdzenie, czy naciśnięto spację
    jne skip_key_press           ; Jeśli nie spację, to pomiń

    ; Tutaj umieść kod obsługujący strzał
    call shoot
    ; ...

skip_key_press:
    mov [keyPress], 0            ; Resetowanie wartości keyPress

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
updateGame endp

shoot proc
    ; Sprawdzenie, czy już istnieje aktywny pocisk
    mov al, [projectileActive]
    or al, al
    jnz exit_shoot               ; Jeśli pocisk jest już aktywny, nie twórz nowego

    ; Ustawienie początkowej pozycji pocisku
    mov al, [projectileX]
    mov [projectileX], al
    mov al, [projectileY]
    mov [projectileY], al

    ; Aktywacja pocisku
    mov [projectileActive], 1

exit_shoot:
    ret
shoot endp

checkGameOver proc
    push ax
    push si
    push cx

    mov si, offset movingObjects  ; Ustawienie wskaźnika na początek tablicy obiektów
    mov cx, 7                     ; Liczba obiektów

check_loop:
    mov al, [si+1]               ; Wczytanie współrzędnej Y obiektu
    cmp al, 24                   ; Sprawdzenie, czy obiekt dotarł do dolnej krawędzi ekranu
    jge game_over                ; Jeśli tak, to ustaw flagę końca gry
    add si, 2                    ; Przejście do następnego obiektu
    loop check_loop
    jmp exit_check

game_over:
    mov [gameOverFlag], 1        ; Ustawienie flagi końca gry

; Procedury pomocnicze, takie jak clearScreen, printNumber, itd.
clearScreen proc
    push ax
    push bx
    push cx
    push dx

    mov ax, 0B800h               ; Segment pamięci wideo dla trybu tekstowego
    mov es, ax
    xor di, di                   ; DI na 0, początek pamięci wideo
    mov ax, 0720h                ; Atrybut (07h - jasnoszary na czarnym) i spacja (20h)
    mov cx, 2000                 ; Ilość znaków do wyczyszczenia (80 kolumn * 25 wierszy)
    rep stosw                    ; Wypełnienie ekranu atrybutem i spacją

    pop dx
    pop cx
    pop bx
    pop ax
    ret
clearScreen endp

printNumber proc
    push ax
    push bx
    push cx
    push dx

    mov bx, 10                   ; Dzielnik (baza liczby)
    lea si, numberBuffer + 5     ; Wskaźnik na koniec bufora
    mov byte ptr [si], '$'       ; Znak końca łańcucha

print_loop:
    dec si
    xor dx, dx                   ; Czyszczenie dx
    div bx                       ; AX = DX:AX / BX, DX = reszta
    add dl, '0'                  ; Konwersja liczby na znak
    mov [si], dl                 ; Zapisanie znaku
    test ax, ax                  ; Sprawdzenie, czy osiągnięto 0
    jnz print_loop               ; Kontynuacja pętli, jeśli AX != 0

    mov ah, 09h                  ; Funkcja wyświetlania ciągu DOS
    mov dx, si                   ; Wskaźnik na początek ciągu
    int 21h                      ; Wywołanie przerwania

    pop dx
    pop cx
    pop bx
    pop ax
    ret
printNumber endp

delay proc
    push ax
    push cx

    mov cx, 0FFFFh               ; Ustawienie dużej wartości w CX
delay_loop:
    dec cx                       ; Dekrementacja CX
    jnz delay_loop               ; Powtórzenie pętli, jeśli CX != 0

    pop cx
    pop ax
    ret
delay endp

exit_check:
    pop cx
    pop si
    pop ax
    ret
checkGameOver endp

end start
