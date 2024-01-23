IDEAL
MODEL small
STACK 100h
jumps
p186
DATASEG
    ; Enemy Missile Data
    enemy_x_cors dw 10 dup (-1)      ; X coordinates of enemy missiles
    enemy_y_cors dw 10 dup (-1)      ; Y coordinates of enemy missiles
	enemy_x_slopes dw 10 dup (-1) 		; An array of the enemy's missile's slopes
	enemy_y_slopes dw 10 dup (-1)		; An array of the enemy's missile's slopes
	; Defender
    defender_x_cors dw 10 dup (-1)   ; X coordinates of defender missiles
    defender_y_cors dw 10 dup (-1)   ; Y coordinates of defender missiles
	defender_x_slopes dw  10 dup (-1)	; An array of the defender's missile's y slopes
	defender_y_slopes dw  10 dup (-1)	; An array of the defender's missile's x slopes
	defender_stop_y_cors dw  10 dup (-1)	; An array of the defender's missile's ending y coordinates
	defender_stop_x_cors dw  10 dup (-1)	; An array of the defender's missile's ending y coordinates
	defender_arr_pointer dw 18

	remainders dw 10 dup (-1) 			; An array of remainders of slope

    missile_slopes dw 40 dup (-1)    ; Slopes for both enemy and defender missiles
    missile_end_cors dw 20 dup (-1)  ; Ending coordinates for defender missiles
    missile_status db 20 dup (0)     ; Status of each missile (active/inactive)

    ; Game Objects and Status
    launchers db 2 dup (1)           ; Status of launchers (1 for active, 0 for destroyed)
    houses db 6 dup (1)              ; Status of houses (1 for intact, 0 for destroyed)
    game_status db 0                 ; 0 = playing, 1 = game over (win), 2 = game over (lose)

    ; Score and Timekeeping
    score dw 0                       ; Player's score
    last_time dw ?                   ; Last recorded time for enemy generation
    generating_rate db 2             ; Enemy generation rate (in seconds)

    ; Graphics and Interaction
    x dw ?                           ; X coordinate for drawing
    y dw ?                           ; Y coordinate for drawing
    x_cor dw ?                       ; X coordinate of mouse click
    y_cor dw ?                       ; Y coordinate of mouse click
	x_slope dw ?						; the returned slope of x axis
	x_start dw ?						; the returned starting x coordinate
	y_slope dw ?						; the returned slope of y axis
	rect_width dw ?						; width of rectangle
	rect_height dw ? 					; height of rectangle
    color db ?                       ; Color for drawing
    is_clicked db ?                  ; Mouse click status (0 or 1)

	slopes_offset dw 0					; offset of the slope array

    ; Bitmap Variables
    filename db 'cm.bmp',0         ; Filename for bitmap
    filehandle dw ?                  ; File handle for bitmap operations
    Header db 54 dup (0)             ; Bitmap header
    Palette db 256*4 dup (0)         ; Bitmap color palette
    ScrLine db 320 dup (0)           ; Line buffer for bitmap display
    ErrorMsg db 'Error', 13, 10, '$' ; Error message string

    ; Constants and Tables
    surface_y dw 180                 ; Y coordinate for the game's surface
    divisorTable db 10, 1, 0         ; Table for print_number procedure
    row db ?                         ; Cursor row for printing score
    column db ?                      ; Cursor column for printing score
	has_exploded db ?					; stores weather or not an explosion had happened in the current iteration of main
	st_score db '			   ', 10, 13			; A string that stores the word "SCORE: "
			 db '		SCORE: ', 10, 13, '$'

    ; Game status pictures
    pic_win db 'win.bmp', 0
    pic_loose db 'lost.bmp', 0
    pic_opening db 'cm.bmp', 0

CODESEG
	; Logics
	proc update_coordinates
		push bp
		mov bp, sp
		mov cx, 18
		mov si, ARRAY_NUM

		cmp si, 2
		je enemy_y_cors_update

		cmp si, 3
		je defender_x_cors_update

		cmp si, 4
		je defender_y_cors_update

		lea di, [enemy_x_cors]
		lea ax, [enemy_x_slopes]
		jmp update_cors

		enemy_y_cors_update:
			lea di, [enemy_y_cors]
			lea ax, [enemy_y_slopes]
			mov [slopes_offset], ax
			jmp update_cors

		defender_x_cors_update:
			lea di, [defender_x_cors]
			lea ax, [defender_x_slopes]
			mov [slopes_offset], ax
			jmp update_cors

		defender_y_cors_update:
			lea di, [defender_y_cors]
			lea ax, [defender_y_slopes]
			mov [slopes_offset], ax
			jmp update_cors

		update_cors:
			mov bx, cx
			cmp si, 2
			je load_enemy_y_slopes

			cmp si, 3
			je load_defender_x_slopes

			cmp si, 4
			je load_defender_y_slopes

			mov dx, [offset enemy_x_slopes + bx]
			jmp update

			load_enemy_y_slopes:
				mov dx, [offset enemy_y_slopes + bx]
				jmp update

			load_defender_x_slopes:
				mov dx, [offset defender_x_slopes + bx]
				jmp update

			load_defender_y_slopes:
				mov dx, [offset defender_y_slopes + bx]

			update:
				mov ax, [word ptr di + bx]
				cmp ax, 0
				jl return_value_to_arr
				add ax, dx

				return_value_to_arr:
					mov [word ptr di + bx], ax

			sub cx, 2
			cmp cx, 0 ; loop until index 0
			jge update_cors
		pop bp
		ret 2 ; return gotten parameter
	endp update_coordinates

	proc update_enemy_defender_cors
		pusha
		push 1
		ARRAY_NUM equ [bp + 4]
		call update_coordinates

		push 2
		ARRAY_NUM equ [bp + 4]
		call update_coordinates

		push 3
		ARRAY_NUM equ [bp + 4]
		call update_coordinates

		push 4
		ARRAY_NUM equ [bp + 4]
		call update_coordinates

		popa
		ret
	endp update_enemy_defender_cors

	proc check_explosion
		mov cx, 18
		loop_x_coordinates:
			mov bx, cx
			mov dx, [offset defender_x_cors + bx]
			cmp dx, 0
			jl update_loop_counter
			mov si, [offset defender_y_cors + bx]
			cmp si, [offset defender_stop_y_cors + bx]
			jbe explode
			ja update_loop_counter

			explode:
				add [defender_arr_pointer], 2
				mov [word ptr offset defender_x_cors + bx], -1
				push [offset defender_stop_x_cors + bx]		; X
				push [offset defender_stop_y_cors + bx]		; Y
				EXPLOSION_X equ [bp + 8]
				EXPLOSION_Y equ [bp + 6]
				call draw_explosion

			update_loop_counter:
				sub cx, 2
				cmp cx, 0 ; loop until index 0
				jne loop_x_coordinates
		ret
	endp check_explosion

	proc time_delay
		pusha
		mov cx, 0
		mov dx, 20000
		mov ah, 86h			; delay
		int 15h				; delay
		popa
		ret
	endp time_delay

	proc wait_char
		mov ah, 0h
		int 16h
		ret
	endp wait_char

	proc calc_slope
		push bp
		push di
		mov bp, sp
		mov bx, X1
		mov ax, Y1
		sub ax, 124
		cmp bx, 160
		jae launcher1
		jb launcher2

		launcher1:
			cmp bx, 233
			jae launcher1_right
			jb launcher1_middle

		launcher2:
			cmp bx, 82
			jae launcher2_middle
			jb launcher2_left

		launcher1_right:
			sub bx, 254 ;left corner of launching box
			mov di, 254
			mov cx, 1

			mov si, bx
			neg si

			cmp si, ax
			jae div_deltas ; if the delta x is bigger
			neg bx
			mov cx, -1
			jmp div_deltas

		launcher1_middle:
			mov dx, bx
			mov bx, 230	; right corner of launching box
			mov di, 236
			sub bx, dx
			mov cx, -1
			mov si, bx
			neg si
			jmp div_deltas

		launcher2_middle:
			sub bx, 84 ;left corner of launching box
			mov di, 84
			mov cx, 1 ; in case of y divided by x
			mov si, bx
			neg si

			cmp si, ax
			jae div_deltas ; if the delta x is bigger
			neg bx
			mov cx, -1
			jmp div_deltas

		launcher2_left:
			sub bx, 64	; right corner of launching box
			neg bx
			mov di, 64
			mov cx, -1
			mov si, bx
			neg si ; make si negative so it would be compareable with ax

		div_deltas:
			cmp si, ax
			jbe x_div_y
			ja	y_div_x

		y_div_x:
			cmp bx, 0
			je accurate_spot
			xor dx, dx ; only ax is needed for the upper part of the devision
			cwd
			idiv bx ; finding the slope (slope => ax)
			shl cx, 2
			shl ax, 2
			mov [x_slope], cx ; move the x_slope
			mov [y_slope], ax ; move the y_slope
			cmp dx, 0F000h
			jb slope_x_normal
			inc ax
			jmp check_zero_slope

		x_div_y:
			xor dx, dx ; only ax is needed for the upper part of the devision
			mov si, ax ; si - tmp register
			mov ax, bx ; swap ax and bx
			mov bx, si
			cwd
			idiv bx
			mov [y_slope], cx ; move the y_slope

			slope_x_normal:
				mov [x_slope], ax ; move the x_slope

		check_zero_slope:
			cmp [x_slope], 0
			je accurate_spot
			jne set_starting_x

		accurate_spot:
			mov ax, X1
			mov [x_start], ax
			jmp end_func

		set_starting_x:
			mov [x_start], di ; move the starting x coordinate

		cmp [y_slope], 0
		jg make_slope_neg
		jle end_func

		make_slope_neg:
			neg [y_slope]

		end_func:

		pop di
		pop bp
		ret 4 ; popping the parameters
	endp calc_slope

	proc generate_random
		pusha
		mov cx, 18
		check_empty_place:
			mov di, cx
			cmp [enemy_x_cors + di], -1
			je generate_enemy
			sub cx, 2
			cmp cx, 0
			jge check_empty_place

		cmp di, 0
		jl full_array

		generate_enemy:
		mov ah, 2ch
		int 21h 	   	  ; interrupt for getting sys time
		mov si, dx		  ; in order to update last_time later on
		xor dx, [last_time] ; dl = 1/ 100 sec, dh = sec
		mov bl, 1
		and bl, dl
		xor bh, bh
		cmp bl, 0
		je negative_x_slope
		jne positive_x_slope

		negative_x_slope:
			mov [enemy_x_slopes + di], -1
			jmp random_y_slope

		positive_x_slope:
			mov [enemy_x_slopes + di], 1

		random_y_slope:
			mov bl, 1b ; 0 - 1
			and bl, dh
			inc bl 		; 1- 2
			mov [enemy_y_slopes + di], bx

		init_enemy_x_cor:
			mov ax, dx ; divide by 319
			mov bx, 319
			cwd
			xor dx, dx
			div bx	; dx => conatians a number in the range 0 - 319
			mov [enemy_x_cors + di], dx
			mov [enemy_y_cors + di], 17

		mov [last_time], si ; insert current time to last_time for the next enemy rocket

		full_array:
		popa
		ret
	endp generate_random

	proc randomize_enemy_rocket
		pusha
		mov ah, 2ch
		int 21h ; get sys time
		sub dx, [last_time] ; check if 5 sec have passed

		cmp dh, [generating_rate]
		jb no_generate

		call generate_random

		no_generate:
		popa
		ret
	endp randomize_enemy_rocket

	proc check_bounds
		push bp
		mov bp, sp

		mov si, ARRAY_INDEX ; index in the arrays (0 - 9)

		mov ax, [offset enemy_x_cors + si]
		mov bx, [offset enemy_y_cors + si]
		jmp cmp_with_bounds

		cmp_with_bounds:
			cmp ax, 310 ; right bound of screen
			jae remove_enemy
			cmp ax, 0  ; right bound of screen
			jle remove_enemy
			cmp bx, 166 ; bottom bound of screen
			jae remove_enemy
			cmp bx, 10  ; top bound of screen
			jle remove_enemy
			jg finish_proc

		remove_enemy:
			mov [word ptr offset enemy_x_cors + si], -1 ;remove the rocket
			mov [has_exploded], 1
			push ax		; X
			push bx		; Y
			EXPLOSION_X equ [bp + 8]
			EXPLOSION_Y equ [bp + 6]
			call draw_explosion

		finish_proc:
			pop bp
			ret 2
	endp check_bounds

	proc check_win
		pusha
		cmp [score], 100
		je win
		jne not_win

		win:
			mov ax, 13h
			int 10h

			mov [game_status], 1
			call time_delay
			call display_screen
			jmp end_game
		not_win:
		popa
		ret
	endp check_win

	proc check_loose
		pusha
		check_launchers:
			mov cx, 1
			launchers_loop:
				mov di, cx
				cmp [launchers + di], 1 ; there is at least one launcher
				je keep_game

				dec cx
				cmp cx, 0
				jge launchers_loop

		mov ax, 13h
		int 10h

		mov [game_status], 2
		call time_delay
		call display_screen

		jmp end_game

		keep_game:
			popa
			ret
	endp check_loose

	proc rem_enemies
		pusha
		mov bx, 18

		remove_enemies_loop:
			mov [enemy_x_cors + bx], -1

			; loop counter
			sub bx, 2
			cmp bx, 0
			jge remove_enemies_loop

		popa
		ret
	endp rem_enemies

	;;; Graphics ;;;
	proc game_graphics_init
		mov ax, 13h
		int 10h
		mov [game_status], 0 ; opening image
		call display_screen
		call wait_char
		mov [game_status], 3 ; rules image
		call display_screen
		call wait_char
		mov ax, 13h
		int 10h

		call draw_background
		call mouse_config
		call init_score

		ret
	endp game_graphics_init

	proc draw_pixel
		pusha

		mov bh,0h
		mov cx, [x]
		mov dx, [y]
		mov al,[color]
		mov ah,0ch
		int 10h

		popa
		ret
	endp draw_pixel

	proc draw_rectangle
		pusha

		mov ax, [y]
		mov cx, [rect_width]
		draw_horizental:
			call draw_pixel

			mov dx, [rect_height]
			draw_vertical:
				call draw_pixel
				inc [y]

				dec dx
				cmp dx, 0
				jne draw_vertical

			mov [y], ax
			inc [x]
			dec cx
			cmp cx, 0
			jne draw_horizental

		popa
		ret
	endp draw_rectangle

	proc draw_surface
		pusha
		mov [color], 2
		mov [rect_width], 319
		mov [rect_height], 20

		mov [x], 0
		mov bx, [surface_y]
		mov [y], bx

		call draw_rectangle

		popa
		ret
	endp draw_surface

	proc draw_launcher
		push bp
		mov bp, sp
		mov ax, LAUNCHER_X_COR
		mov bx, ERASE
		cmp bx, 1 ; erase / destroy a rocketequ [bp + 6]
		je black1
		jne normal1

		black1:
			mov [color], 0
			jmp draw_lower_block

		normal1:
			mov [color], 1

		draw_lower_block:
			mov [rect_width],  31
			mov [rect_height], 10
			mov ax, LAUNCHER_X_COR
			mov [x], ax
			add [x], 10
			mov bx, [surface_y]
			mov [y], bx
			sub [y], 10
			call draw_rectangle

		mov [rect_width],  31
		mov [rect_height], 10
		mov ax, LAUNCHER_X_COR
		mov [x], ax
		add [x], 10
		mov bx, [surface_y]
		mov [y], bx
		sub [y], 20
		call draw_rectangle

		mov [rect_width],  15
		mov [rect_height], 30
		mov ax, LAUNCHER_X_COR
		mov [x], ax
		add [x], 18
		mov bx, [surface_y]
		mov [y], bx
		sub [y], 30
		call draw_rectangle

		mov [rect_width],  5
		mov [rect_height], 15
		mov ax, LAUNCHER_X_COR
		mov [x], ax
		add [x], 23
		mov bx, [surface_y]
		mov [y], bx
		sub [y], 45

		call draw_rectangle

		mov bx, ERASE
		cmp bx, 1 ; erase / destroy a rocketequ [bp + 6]
		je black3
		jne normal3

		black3:
			mov [color], 0
			jmp draw_launching_box

		normal3:
			mov [color], 4

		draw_launching_box:
			mov [rect_width],  7
			mov [rect_height], 6
			mov ax, LAUNCHER_X_COR
			mov [x], ax
			add [x], 22
			mov bx, [surface_y]
			mov [y], bx
			sub [y], 48

			call draw_rectangle

		pop bp
		ret 4 ;pop the pushed params
	endp draw_launcher

	proc draw_house
		push bp
		mov bp, sp
		mov ax, HOUSE_X_COR
		mov [color], 7
		mov [rect_width],  30
		mov [rect_height], 35
		mov [x], ax
		add [x], 18
		mov bx, [surface_y]
		mov [y], bx
		sub [y], 35

		call draw_rectangle

		mov [color], 13
		mov [rect_width],  7
		mov [rect_height], 7
		mov [x], ax
		add [x], 22
		mov bx, [surface_y]
		mov [y], bx
		sub [y], 30
		call draw_rectangle

		mov [color], 13
		mov [rect_width],  7
		mov [rect_height], 7
		mov [x], ax
		add [x], 37
		mov bx, [surface_y]
		mov [y], bx
		sub [y], 30
		call draw_rectangle

		mov [color], 0
		mov [rect_width],  7
		mov [rect_height], 8
		mov [x], ax
		add [x], 29
		mov bx, [surface_y]
		mov [y], bx
		sub [y], 8
		call draw_rectangle

		pop bp
		ret 2
	endp draw_house

	proc draw_background
		call draw_surface

		push 49 ; the launcher X coordinate
		push 0  ; draw = 0, erase = 1
		LAUNCHER_X_COR equ [bp + 6]
		ERASE equ [bp + 4]
		call draw_launcher

		push 223 ; The launcher X coordinate
		push 0  ; draw = 0, erase = 1
		LAUNCHER_X_COR equ [bp + 6]
		ERASE equ [bp + 4]
		call draw_launcher

		push 2 ; The house's X ccordinate
		HOUSE_X_COR equ [bp + 4]
		call draw_house

		push 78; The house's X ccordinate
		HOUSE_X_COR equ [bp + 4]
		call draw_house

		push 112 ; The house's X ccordinate
		HOUSE_X_COR equ [bp + 4]
		call draw_house

		push 146 ; The house's X ccordinate
		HOUSE_X_COR equ [bp + 4]
		call draw_house

		push 180 ; The house's X ccordinate
		HOUSE_X_COR equ [bp + 4]
		call draw_house

		push 258 ; The house's X ccordinate
		HOUSE_X_COR equ [bp + 4]
		call draw_house
		ret
	endp draw_background

	proc rocket_graphics
		push bp
		mov bp, sp
		mov ax, ROCKET_X
		mov dx, ROCKET_Y
		mov bx, ROCKET_TYPE
		cmp bx, 2
		je erase_rocket
		cmp bx, 0
		je enemy_rocket

		defender_rocket:
			mov bl, 4	; outer color
			mov bh, 1	; inner color
			jmp draw_bullet

		enemy_rocket:
			mov bl,  8	; outer color
			mov bh, 14	; inner color
			jmp draw_bullet

		erase_rocket:
			xor bx, bx ; black color inner + outer

		draw_bullet:
			mov [color], bl
			mov [rect_width],  5
			mov [rect_height], 5
			mov [x], ax
			mov [y], dx
			sub [y], 1
			call draw_rectangle

			mov [color], bh
			mov [rect_width],  3
			mov [rect_height], 3
			mov [x], ax
			add [x], 1
			mov [y], dx
			call draw_rectangle

		pop bp
		ret 6 ; pop back 3 parameters of double byte
	endp rocket_graphics

	proc check_collision
		push bp
		push di
		mov bp, sp
		mov ax, ARRAY_TYPE ; 1 = defender, 0 = enemy
		mov bx, ROCKET_IND
		mov cx, [offset enemy_x_cors + bx]
		mov dx, [offset enemy_y_cors + bx]
		mov [x], cx ; initial x cor
		mov [y], dx
		dec [y]

		get_pixel_color:
			mov bx, 3
			get_x_loop:
				mov si, 3
				get_y_loop:
					mov cx, [x]
					mov dx, [y]
					mov bh,0h
					mov ah,0Dh
					int 10h ; AL = COLOR
					mov di, ARRAY_TYPE
					cmp di, 0	; enemy color checking
					je check_enemy_collision

					check_defender_collision:
						cmp al, 14 ; collision with enemy rocket
						je defender_collision
						jne y_color_loop

					check_enemy_collision:
						cmp al, 6
						je house_collision
						cmp al, 5
						je house_collision
						cmp al, 9
						je launcher_collison
						cmp al, 13
						je launcher_collison
						cmp al, 7
						je launcher_collison
						cmp al, 4
						je defender_collision
						cmp al, 8
						je defender_collision
						cmp al, 9
						je defender_collision
						cmp al, 10
						je defender_collision
						cmp al, 11
						je defender_collision
						cmp al, 12
						je defender_collision
						cmp al, 13
						je defender_collision
						jne y_color_loop

					launcher_collison:
						push [x] ; explosion_x
						EXP_X_COR equ [bp + 4]
						call destroy_launcher

					house_collision:
						mov di, ROCKET_IND
						mov [word ptr offset enemy_x_cors + di], -1
						cmp [score], 5
						jae sub_score_5
						jb no_score
						sub_score_5:
							sub [score], 5

						no_score:
						jmp explosion_animation

					defender_collision:
						add [score], 5
						mov di, ROCKET_IND
						mov [word ptr offset enemy_x_cors + di], -1
						jmp explosion_animation

					explosion_animation:
						mov [has_exploded], 1
						push [x]	; X
						push [y]	; Y
						EXPLOSION_X equ [bp + 8]
						EXPLOSION_Y equ [bp + 6]
						call draw_explosion
						jmp finish_check

					y_color_loop:
						inc [y]
						dec si
						cmp si, 0
						jge get_y_loop

				x_color_loop:
					inc [x]
					dec bx
					cmp bx, 0
					jge get_x_loop	; inner loop

		finish_check:
			pop di
			pop bp
			ret 4
	endp check_collision

	proc mouse_config
		pusha
		mov ax, 0
		int 33h	; intialize cursor
		mov cx, 8 * 2  ;X speed (lower multiplication = faster)
		mov dx, 16 * 2 ;Y speed (lower multiplication = faster)
		mov ax, 0Fh ; set speed
		int 33h

		popa
		ret
	endp mouse_config

	proc event_click
		pusha
		mov ax, 1
		int 33h

		get_cursor:
			mov ax, 3
			int 33h     ;Check the mouse
			and bx, 3h
			cmp bx, 1
			je check_release
			cmp bx, 0
			je last_click
			jne noClick

			last_click:
				cmp [is_clicked], 1
				je left
				jne noClick

			check_release:
				mov [is_clicked], 1
				mov ax, 3
				int 33h     ;Check the release
				and bx, 3h
				cmp bx, 0
				je left
				jne noClick

			left:
				mov [is_clicked], 0
				cmp [defender_arr_pointer], 0 ; full array
				je noClick
				shr cx, 1 ; the x coordinate needs to be divided by 2
				cmp dx, 140
				jae noClick
				mov di, [defender_arr_pointer]
				mov [offset defender_stop_y_cors + di], dx
				mov [offset defender_stop_x_cors + di], cx
				cmp cx, 160
				jae launcher1_check
				jb launcher2_check

				launcher1_check:
					cmp [launchers + 1], 1
					jne noClick			; cannot shoot since launcher is destroyed
					je valid_shoot

				launcher2_check:
					cmp [launchers + 0], 1
					jne noClick			; cannot shoot since launcher is destroyed

				valid_shoot:
					push cx ; X1
					push dx; Y1
					X1 equ [bp + 8]
					Y1 equ [bp + 6]
					call calc_slope

					mov bx, [x_slope]
					mov si, [y_slope]
					mov ax, [x_start]
					mov [offset defender_x_slopes + di], bx
					mov [offset defender_y_slopes + di], si
					mov [offset defender_x_cors + di], ax
					mov [word ptr offset defender_y_cors + di], 124 ; The constant height of the two launchers
					sub [defender_arr_pointer], 2
		noClick:
		popa
		ret
	endp event_click

	proc draw_explosion
		push cx
		push bp
		mov bp, sp
		mov bx, 2
		repeat_explosion:
			mov ax, EXPLOSION_X; x cor
			mov dx, EXPLOSION_Y; y_cor
			mov [rect_width],  6
			mov [rect_height], 6
			mov [color], 13
			mov cx, 6

			draw_explosion_levels:
				cmp [color], 8
				jne set_color
				mov [color], 12
				set_color:
					dec [color]

				add [rect_height], 2
				add [rect_width], 2
				sub ax, 1
				sub dx, 1
				mov [x], ax
				mov [y], dx
				call draw_rectangle
				call time_delay

				loop draw_explosion_levels

		dec bx
		cmp bx, 0
		jne repeat_explosion
		mov [x], ax
		mov [y], dx
		call check_explosion_zone

		mov [color], 0
		call draw_rectangle
		pop bp
		pop cx

		ret 4
	endp draw_explosion

	proc check_explosion_zone
		pusha
		mov cx, 18

		loop_cors:
			mov bx, cx
			mov ax, [offset enemy_x_cors + bx]
			mov bx, [offset	enemy_y_cors + bx]
			cmp ax, -1
			je update_loop

			cmp ax, [x]
			jb update_loop

			sub ax, [x]
			cmp ax, [rect_width]
			ja update_loop

			cmp bx, [y]
			jb update_loop

			sub bx, [y]
			cmp bx, [rect_height]
			ja update_loop

			push [offset enemy_x_cors + bx]		; X
			push [offset enemy_y_cors + bx]		; Y
			EXPLOSION_X equ [bp + 8]
			EXPLOSION_Y equ [bp + 6]
			call draw_explosion

			update_loop:
				sub cx, 2
				cmp cx, 0 ; loop until index 0
				jge loop_cors
		popa
		ret
	endp check_explosion_zone

	proc show_rockets
		mov di, 18
		display_rockets:
			mov cx, [offset defender_x_cors + di]
			mov dx, [offset defender_y_cors + di]
			cmp cx, -1
			je enemy_display
			push 1
			push di

			ARRAY_TYPE equ [bp + 8]
			ROCKET_IND equ [bp + 6]
			call check_collision

			mov cx, [offset defender_x_cors + di]
			mov dx, [offset defender_y_cors + di]
			push 1	; ROCKET_TYPE
			push cx ; ROCKET_X
			push dx ; ROCKET_Y
			ROCKET_TYPE equ [bp + 8] ; 0 => enemy, 1 => defender, 2 => erase
			ROCKET_X	equ [bp + 6]
			ROCKET_Y equ [bp + 4]
			call rocket_graphics

			enemy_display:
				mov [has_exploded], 0
				mov cx, [offset enemy_x_cors + di]
				mov dx, [offset enemy_y_cors + di]
				cmp cx, -1
				je loop_check
				push di ; index of rcoket
				ARRAY_INDEX equ [bp + 4]; index in the arrays (0 - 9)
				call check_bounds

				push 0
				push di
				ARRAY_TYPE equ [bp + 8]
				ROCKET_IND equ [bp + 6]
				call check_collision

				cmp [has_exploded], 0
				jne loop_check
				mov cx, [offset enemy_x_cors + di]
				mov dx, [offset enemy_y_cors + di]
				push 0	; ROCKET_TYPE
				push cx ; ROCKET_X
				push dx ; rocket y
				ROCKET_TYPE equ [bp + 8] ; 0 => enemy, 1 => defender, 2 => erase
				ROCKET_X	equ [bp + 6]
				ROCKET_Y equ [bp + 4]
				call rocket_graphics

			loop_check:
				sub di, 2
				cmp di, -2
				jne display_rockets

		ret
	endp show_rockets

	proc hide_rockets
		mov di, 18

		remove_rockets:
			mov cx, [offset defender_x_cors + di]
			mov dx, [offset defender_y_cors + di]
			cmp cx, -1
			je enemy_rockets_remove
				push 2	; ROCKET_TYPE
			push cx ; ROCKET_X
			push dx ; rocket y
			ROCKET_TYPE equ [bp + 8] ; 1 => enemy, 0 => defender, 2 => erase
			ROCKET_X	equ [bp + 6]
			ROCKET_Y equ [bp + 4]
			call rocket_graphics

			enemy_rockets_remove:
				mov cx, [offset enemy_x_cors + di]
				mov dx, [offset enemy_y_cors + di]
				cmp cx, -1
				je loop_counter
				push 2	; ROCKET_TYPE
				push cx ; ROCKET_X
				push dx ; rocket y

				ROCKET_TYPE equ [bp + 8] ; 1 => enemy, 0 => defender, 2 => erase
				ROCKET_X	equ [bp + 6]
				ROCKET_Y equ [bp + 4]
				call rocket_graphics

			loop_counter:
				sub di, 2
				cmp di, -2
				jne remove_rockets
		ret
	endp hide_rockets

	proc destroy_launcher
		push bp
		mov bp, sp
		mov ax, EXP_X_COR
		cmp ax, 160 ; half of screen
		jae launcher_2
		jb launcher_1

		launcher_1:
			mov [launchers + 0], 0
			push 49 ; the launcher X coordinate
			jmp delete_launcher

		launcher_2:
			mov [launchers + 1], 0
			push 223 ; The launcher X coordinate

		delete_launcher:
			push 1  ; draw = 0, erase = 1
			LAUNCHER_X_COR equ [bp + 6]
			ERASE equ [bp + 4]
			call draw_launcher

		pop bp
		ret 2
	endp destroy_launcher

	proc print_number
		push ax
		push bx
		push dx
		mov bx, offset divisorTable

		next_digit:
			xor ah,ah ; dx:ax = number
			div [byte ptr bx] ; al = quotient, ah = remainder
			add al,'0'
			call print_character ; Display the quotient
			mov al,ah ; ah = remainder
			add bx,1 ; bx = address of next divisor
			cmp [byte ptr bx],0 ; Have all divisors been done?
			jne next_digit
			mov ah,2
			mov dl,13
			int 21h
			mov dl,10
			int 21h
			pop dx
			pop bx
			pop ax
			ret
	endp print_number

	proc print_character
		push ax
		push dx
		mov ah,2
		mov dl, al
		int 21h
		pop dx
		pop ax
		ret
	endp print_character

	proc set_cursor_position
		pusha
		mov dh, [row] 	  ;  row
		mov dl, [column]  ; column
		mov bh, 0   ; page number
		mov ah, 2
		int 10h
		popa
		ret
	endp set_cursor_position

	proc print_string
		pusha
		mov ah, 9h
		int 21h    ;interrupt that displays a string
		popa

		ret
	endp print_string

	proc print_updated_score
		push ax
		mov [row], 1
		mov [column], 23
		call set_cursor_position

		mov ax, [score]
		call print_number

		pop ax
		ret
	endp print_updated_score

	proc init_score
		push dx
		lea dx, [st_score]
		call print_string

		pop dx
		ret
	endp init_score

	proc open_file
		mov ah, 3Dh
		xor al, al
		int 21h
		jc openerror
		mov [filehandle], ax
		ret
		openerror:
			mov dx, offset ErrorMsg
			mov ah, 9h
			int 21h
			ret
	endp open_file

	proc read_header
		mov ah,3fh
		mov bx, [filehandle]
		mov cx,54
		mov dx,offset Header
		int 21h
		ret
	endp read_header

	proc read_pallette
		mov ah,3fh
		mov cx,400h
		mov dx,offset Palette
		int 21h
		ret
	endp read_pallette

	proc copy_pal
		mov si,offset Palette
		mov cx,256
		mov dx,3C8h
		mov al,0
		out dx,al
		inc dx
		PalLoop:
			mov al,[si+2] ; Get red value.
			shr al,2 ; Max. is 255, but video palette maximal
			out dx,al ; Send it.
			mov al,[si+1] ; Get green value.
			shr al,2
			out dx,al ; Send it.
			mov al,[si] ; Get blue value.
			shr al,2
			out dx,al ; Send it.
			add si,4 ; Point to next color.
			loop PalLoop
		ret
	endp copy_pal

	proc copy_bitmap
		mov ax, 0A000h
		mov es, ax
		mov cx,200

		PrintBMPLoop:
			push cx
			mov di,cx
			shl cx,6
			shl di,8
			add di,cx
			mov ah,3fh
			mov cx,320
			mov dx,offset ScrLine
			int 21h

			cld ; Clear direction flag, for movsb
			mov cx,320
			mov si,offset ScrLine
			rep movsb ; Copy line to the screen
			pop cx
			loop PrintBMPLoop
		ret
	endp copy_bitmap

	proc display_screen
		pusha

		cmp [game_status], 0 ; opening screen
		je load_opening

		cmp [game_status], 1 ; win screen
		je load_winning

		cmp [game_status], 2 ; loose screen
		je load_losing

		load_opening:
			lea dx, [pic_opening]
			jmp load_file

		load_winning:
			lea dx, [pic_win]
			jmp load_file

		load_losing:
			lea dx, [pic_loose]
			jmp load_file

		load_file:
			call open_file
			call read_header
			call read_pallette
			call copy_pal
			call copy_bitmap

		popa
		ret
	endp display_screen

start:
	mov ax, @data
	mov ds, ax
	xor ax, ax

	game:
	call game_graphics_init				; inicjalizacja grafiki

	main:
		call randomize_enemy_rocket		; generuje nowego wroga jeśli minęły 2 sekundy
		call show_rockets				; pokazuje wszystkie rakiety na ekranie
		call time_delay					; opóźnienie tworzące animację ruchu rakiet
		call hide_rockets				; ukrywa wszystkie rakiety do następnej iteracji
		call update_enemy_defender_cors	; aktualizuje współrzędne
		call check_explosion			; sprawdza, czy nastąpiła eksplozja po aktualizacji współrzędnych
		call event_click				; sprawdza, czy nastąpiło zdarzenie kliknięcia
		call check_win					; sprawdza, czy gracz wygrał
		call check_loose 				; sprawdza, czy gracz przegrał
		call print_updated_score		; drukuje na ekranie aktualny wynik

		jmp main		; kontynuuje główną pętlę gry

	end_game:
		mov ax, 02h 	; ustala kod operacji dla przerwania obsługującego mysz
		int 33h 		; skutkuje ukryciem kursora myszy na ekranie

exit:
	mov ax, 04ch 	; zakończenie programu i powrot do systemu operacyjnego DOS
	int 21h

END start