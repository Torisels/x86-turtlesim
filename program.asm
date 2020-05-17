%define CMD_SET_POS 0x03
%define CMD_SET_DIR 0x02
%define CMD_MOVE    0x01
%define CMD_SET_PEN_STATE 0x00

%define MASK_CMD_TYPE 0x03

%define COLR_BLACK  0x000000
%define COLR_RED    0xFF0000
%define COLR_GREEN  0x00FF00
%define COLR_BLUE   0x0000FF
%define COLR_YELL   0xFFFF00
%define COLR_CYAN   0x00FFFF
%define COLR_PURPL  0xFF00FF
%define COLR_WHITE  0xFFFFFF

%define CLOSEST_FOUR_MUL_MASK 0xFFFFFFFFFFFFFFFC

%define IM_OFF_WIDTH 18
%define IM_OFF_HEIGHT 22
%define IM_OFF_PIXEL_ARRAY 54

%define EXIT_CODE_CORRECT DWORD 0
%define EXIT_CODE_SET_POS DWORD -1
%define EXIT_CODE_ERROR_NO_INS DWORD 1
%define EXIT_CODE_ERROR_SET_POS DWORD 2

%define BMP_BUFFER_S_OFF 8
%define INS_BUFFER_S_OFF 12
%define TURTLE_CNTX_S_OFF 16
section .data
h_movs  DB  1, 0, -1, 0
v_movs  DB  0, 1, 0, -1

colors  DD  COLR_BLACK, COLR_RED, COLR_GREEN, COLR_BLUE, COLR_YELL, COLR_CYAN, COLR_PURPL, COLR_WHITE

section	.text
global  exec_turtle_cmd, _exec_turtle_cmd ;for Windows and Linux

exec_turtle_cmd:
_exec_turtle_cmd:
        ; Function arguments:

        ; rdi - dest bitmap *
        ; rsi - command buffer *
        ; rdx - turtle context struct *

        mov     rax, [rsi]            ; move instructions to rax (8 bytes)
        and     ah, MASK_CMD_TYPE     ; mask ah in order to hold instruction information only

        ;switch case (CMD_TYPE)
        jz      cmd_set_pen_state     ; case set pen state: code is 0x00 so that we can use 'and' above which sets ZF
        cmp     ah, CMD_SET_POS       ; case CMD set position
        je      cmd_set_pos
        cmp     ah, CMD_SET_DIR       ; case CMD set direction
        je      cmd_set_dir
        cmp     ah, CMD_MOVE          ; case CMD move
        je      cmd_move
        
        mov     rax, EXIT_CODE_ERROR_NO_INS ; if instruction was not found, exit with error
        ret     
;==========CASE CMD SET POSITION=================================
cmd_set_pos:
        mov     eax, [rsi]
        ror     ax, 14                  ;'exchange' two bytes (inside bx) => --------|y5....0--|------x9x8.....x2x1x0
        and     ax, 0x3FF               ; mask x9....x0 to remove trash bits
        mov     r8d, [rdi + IM_OFF_WIDTH]       ; move image's width to edi
        movzx   ecx, ax                   ; move bx to esi with zero extension in order to compare right
        cmp     ecx, r8d                  ; if desired X pos is greater or equal than image's width exit with error
        jge     exit_with_error_cmd_set_pos     ; if not proceed
        mov     [rdx], ax               ; move masked 10 bits of bx (x9...x0) to x_pos in turtle_struct
        shr     eax, 18                 ; shift right remaining bits (y5...y0)
        and     eax, 0x3F               ; mask to remove trash bits

        mov     edi, [rdi + IM_OFF_HEIGHT]  ; move image's height to edi
        cmp     eax, edi                    ; if desired Y pos is greater or equal than height exit with error
        jge     exit_with_error_cmd_set_pos ; if not, proceed with correct execution
        mov     [rdx+4], eax            ; move 00000000 | y5....0 to y_pos in turtle_context struct

        mov     rax, EXIT_CODE_SET_POS  ; set exit code to special SET_POS which indicates that this instruction has 4 bytes
        ret

exit_with_error_cmd_set_pos:
        mov     rax, EXIT_CODE_ERROR_SET_POS ; set exit code to error set pos
        ret

;==========END CMD SET POSITION===================================

;=========CASE CMD SET DIRECTION==================================
cmd_set_dir:
        mov     si, [rsi]
        shr     si, 10               ; shift right by 10 to have direction on correct bit positions
        and     si, 0x03            ; mask di in order to remove unnecessary bits
        mov     [rdx+13], sil        ; write position to position in turtle_context struct
        jmp     exit_correct        ; exit with correct code
;=========END CMD SET DIRECTION==================================

;=========CASE CMD MOVE==========================================
cmd_move:
        mov     si, [rsi]           ; move two bytes of instruction to si
        ror     si, 10              ; rotate bits by 10 to get bits on correct positions
        and     rsi, 0x3FF          ; mask with 0b00001111 11111111 to remove trash bits

        mov     ecx, [rdi + IM_OFF_WIDTH]       ; move width to ecx
        mov     r10, rcx            ; copy width to r10
        imul    rcx, 3              ; rcx = WIDTH * 3
        add     rcx, 3              ; rcx = WIDTH * 3 + 3
        and     rcx, CLOSEST_FOUR_MUL_MASK; rcx = (WIDTH * 3 + 3) & ~3

        mov     r8d, [rdx]          ; move current X POS from turtle context to r8d (4 bytes)
        movzx   r9,  BYTE [rdx+13]   ; move direction code from turtle context to r9
        movsx   rax, BYTE [h_movs + r9] ;move move multiplier to rax
        test    rax, rax            ; if multiplier is 0 we simply ignore horizontal movement
        jz      y_pos               ; jmp for vertical movement
        mov     r11, rax            ; copy multiplier to r11
        imul    rax, rsi            ; rax = multiplier * steps_to_move
        add     rax, r8             ; rax = multiplier * steps_to_move + current_position
        cmp     rax, r10            ; compare future position X with image's width
        jl      then_x_0            ; if future position < image's width, then ok and test if it is negative
        mov     rax, r10            ; if not, set future position to image's border
        sub     rax, 1              ; and subtract 1, because position is 0 indexed
        jmp     then_x              ; after this operation, checking for negative future pos is unnecessary
then_x_0:
        test    rax, rax            ; check if future position (rax) is lower than 0
        jns     then_x              ; if not go to saving and drawing
        xor     rax, rax            ; if yes, set future position to 0
then_x:
        cmp     rax, r8             ; if future position == current position do nothing
        je      exit_from_move      ; and exit with corresponding exit code

        mov     [rdx], eax          ; move future position X (eax) to turtle_context
        mov     sil, [rdx+12]       ; move pen state flag to sil
        test    sil, sil            ; check if pen state is one
        jz      exit_from_x_pos     ; if pen state is zero, just exit
        mov     esi, [rdx + 4]      ; esi = current Y pos of turtle
        imul    rcx, rsi            ; rcx = row_width * current Y pos
        imul    r9, r8, 3           ; r9 = current X pos * 3

        add     rdi, IM_OFF_PIXEL_ARRAY ; rdi holds pointer to pixel array (pointer to buffer + offset==54)
        add     rdi, rcx            ; rdi = rdi + rcx = address + 54 + row_width * current Y pos
        add     rdi, r9             ; rdi holds absolute pixel index

        mov     edx, [rdx+8]        ; rdx holds color from turtle context
        mov     r10, rdx            ; copy color to r10
        imul    rsi, r11, 3         ; rsi = 3 * multiplier (-3 or 3)

draw_horizontal_line_loop:
        mov     rdx, r10            ; move color from r10 to rdx
        mov     [rdi], dx           ; move Green and Blue to bmp buffer at correct position
        shr     rdx, 16             ; shift right rdx by 16 bits to place red at it's correct position
        mov     [rdi+2], dl         ; copy red into bmp buffer

        add     r8, r11             ; add multiplier (-1 or 1) to current position
        add     rdi, rsi            ; add multiplier (-3 or 3) to memory index
        cmp     r8, rax             ; compare current position with future position
        jne     draw_horizontal_line_loop   ; if they are not equal repeat the loop

        mov     rdx, r10            ; move color from r10 to rdx
        mov     [rdi], dx           ; move Green and Blue to bmp buffer at correct position
        shr     rdx, 16             ; shift right rdx by 16 bits to place red at it's correct position
        mov     [rdi+2], dl         ; copy red into bmp buffer

        jmp     exit_correct        ; exit normally with correct exit code

y_pos:

;        mov     esi, [ecx+4]            ; move old Y pos from turtle context to esi
;        movsx   edx, BYTE[v_movs + edi] ; move Y multiplier to edx
;        pop     edi                     ; edi = row's width
;        mov     eax, edx                ; eax = multiplier
;        imul    eax, ebx                ; multiply eax = coeff * ebx (steps to move)
;        add     eax, esi                ; eax = steps to move + old position Y
;        push    edx                     ; push multiplier (if we are in y_pos we know that is is != 0)
;        mov     edx, [ebp+8]            ; edx = address for bmp buffer
;        mov     edx, [edx+22]           ; edx = bmp's height
;        cmp     eax, edx                ; compare future position (eax) with image's height (edx)
;        jl      then_y_0                ; if future position is lower than height, check if it is lower than 0
;        mov     eax, edx                ; if not => future pos = height
;        sub     eax, 1                  ; future pos --
;        jmp     then_y                  ; after this operation, checking for negative future pos is unnecessary
;then_y_0:
;        test    eax, eax            ; check if future position is negative
;        jns     then_y              ; if not, proceed to then_y
;        xor     eax, eax            ; if yes, set future pos to 0
;then_y:
;        cmp     eax, esi            ; if future position == old position
;        je      exit_from_move      ; exit normally
;        pop     edx                 ; edx holds multiplier
;        mov     [ecx+4], eax        ; store new position in memory
;
;        mov     bl, [ecx+12]        ; move pen state flag to bl
;        test    bl, bl              ; check if pen state is one
;        jz      exit_correct               ; if not don't draw, exit
;        mov     ebx, esi            ; move current Y pos to ebx
;        imul    ebx, edi            ; ebx = current Y * bytes_per_row
;        mov     ecx, [ebp+BMP_BUFFER_S_OFF] ; ecx = beginning of bmp buffer
;        add     ecx, IM_OFF_PIXEL_ARRAY     ; ecx = beginning + pixel offset
;        add     ecx, ebx            ; ecx holds absolute pixel offset (correct row)
;        mov     ebx, [ebp+TURTLE_CNTX_S_OFF]; ebx holds pointer to turtle context
;        mov     ebx, [ebx]          ; ebx = current X position
;        imul    ebx, 3              ; ebx = current X position * 3
;        add     ecx, ebx            ; ecx holds absolute pixel offset (memory offset + row + width)
;        mov     ebx, [ebp+TURTLE_CNTX_S_OFF] ; ebx holds pointer to turtle context
;        mov     ebx, [ebx+8]        ; ebx = turtle's color
;        push    ebp                 ; preserve ebp on stack
;        mov     ebp, ebx            ; ebp also holds color
;        imul    edi, edx            ; edi = bytes per row * multiplier (-1 or 1), because we traverse vertically
;
;draw_vertical_line:
;        mov     ebx, ebp            ; move color from ebp to ebx
;        mov     [ecx], bx           ; move Green and Blue into memory
;        shr     ebx, 16             ; shift right color register by 16 (00...0RRRRRRRR)
;        mov     [ecx+2], bl         ; move Red to memory
;
;        add     esi, edx            ; current position += multiplier (-1 or 1)
;        add     ecx, edi            ; memory index += bytes per row * multiplier (-1 or 1)
;        cmp     esi, eax            ; check if current position == future position
;        jne     draw_vertical_line  ; if not, repeat the loop
;
;        mov     ebx, ebp            ; color last pixel in the same way as above
;        mov     [ecx], bx
;        shr     ebx, 16
;        mov     [ecx+2], bl
;
;        pop     ebp                 ; restore ebp
;        jmp     exit_correct        ; exit correctly
;========END CMD MOVE===========================


;========CASE CMD SET PEN STATE=================
cmd_set_pen_state:
        mov     rax, [rsi]
        shr     ah, 3           ; shift right for correct bit position of pen state
        and     ah, 0x01        ; mask pen state
        mov     [rdx+12], ah    ; move pen state information to turtle context struct
        shr     al, 5           ; shift bl by 5 to have correct color info at right bits
        and     rax, 0x03       ; and rax with correct bit mask
        mov     rax, [colors + rax*4] ; exchange color code to real color with using static array
        mov     [rdx+8], eax    ; move correct RGB color to turtle context struct
;========END CMD SET PEN STATE==================


exit_correct:   ; label for correct exit
	    mov     rax, EXIT_CODE_CORRECT  ; exit with correct code in eax
	    ret

exit_from_move: ; special type of exit with maintaining correct stack balance.
        mov     rax, EXIT_CODE_CORRECT  ; move exit code to eax
        ret                             ; return


