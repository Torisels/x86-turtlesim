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

%define CLOSEST_FOUR_MUL_MASK 0xFFFFFFFC

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
        push	ebp
        mov	    ebp, esp              ; prologue

        mov	    eax, DWORD [ebp+INS_BUFFER_S_OFF]	    ; address of instruction buffer to eax
        mov     bl,  [eax+1]                            ; load second byte of the instruction to bl
        mov     ecx, [ebp+TURTLE_CNTX_S_OFF]            ; move address to turtle_context struct to ecx
        and     ebx, MASK_CMD_TYPE                      ; mask ebx in order to hold instruction information only

        ;switch case (CMD_TYPE)
        jz      cmd_set_pen_state     ; case set pen state: code is 0x00 so that we can use 'and' above which sets ZF
        cmp     bl, CMD_SET_POS       ; case CMD set position
        je      cmd_set_pos
        cmp     bl, CMD_SET_DIR       ; case CMD set direction
        je      cmd_set_dir
        cmp     bl, CMD_MOVE          ; case CMD move
        je      cmd_move
        
        mov     eax, EXIT_CODE_ERROR_NO_INS ; if instruction was not found, exit with error
        pop     ebp
        ret     
;==========CASE CMD SET POSITION=================================
cmd_set_pos:
        mov     ebx, [eax]              ; ebx holds instruction which is     --------|y5....0--|x1x0------x9......x2
        ror     bx, 14                  ;'exchange' two bytes (inside bx) => --------|y5....0--|------x9x8.....x2x1x0
        and     bx, 0x3FF               ; mask x9....x0 to remove trash bits
        mov     edx, [ebp + BMP_BUFFER_S_OFF]   ; move bmp buffer address to edx
        mov     edi, [edx + IM_OFF_WIDTH]       ; move image's width to edi
        movzx   esi, bx                   ; move bx to esi with zero extension in order to compare right
        cmp     esi, edi                  ; if desired X pos is greater or equal than image's width exit with error
        jge     exit_with_error_cmd_set_pos     ; if not proceed
        mov     [ecx], bx               ; move masked 10 bits of bx (x9...x0) to x_pos in turtle_struct
        shr     ebx, 18                 ; shift right remaining bits (y5...y0)
        and     ebx, 0x3F               ; mask to remove trash bits

        mov     edi, [edx + IM_OFF_HEIGHT]  ; move image's height to edi
        cmp     ebx, edi                    ; if desired Y pos is greater or equal than height exit with error
        jge     exit_with_error_cmd_set_pos ; if not, proceed with correct execution
        mov     [ecx+4], ebx            ; move 00000000 | y5....0 to y_pos in turtle_context struct

        mov     eax, EXIT_CODE_SET_POS  ; set exit code to special SET_POS which indicates that this instruction has 4 bytes
        pop     ebp                     ; epilogue
        ret

exit_with_error_cmd_set_pos:
        mov     eax, EXIT_CODE_ERROR_SET_POS ; set exit code to error set pos
        pop     ebp                          ; epilogue
        ret

;==========END CMD SET POSITION===================================

;=========CASE CMD SET DIRECTION==================================
cmd_set_dir:
        mov     bl, [eax+1]         ; move instruction to bl
        shr     bl, 2               ; shift right by 2 to have direction on correct bit positions
        and     bl, 0x03            ; mask bl in order to remove unnecessary bits
        mov     [ecx+13], bl        ; write position to position in turtle_context struct
        jmp     exit_correct        ; exit with correct code
;=========END CMD SET DIRECTION==================================

;=========CASE CMD MOVE==========================================
cmd_move:
        mov     bx, [eax]           ; move two bytes of instruction to bx
        ror     bx, 10              ; rotate bits by 10 to get bits on correct positions
        and     ebx, 0x3FF          ; mask with 0b00001111 11111111 to remove trash bits

        mov     eax, [ebp + BMP_BUFFER_S_OFF]   ; addr of image to eax
        mov     esi, [eax + IM_OFF_WIDTH]       ; move width to esi

        imul    edi, esi, 3         ; edi = WIDTH * 3
        add     edi, 3              ; edi = WIDTH * 3 + 3
        and     edi, CLOSEST_FOUR_MUL_MASK; edi = (WIDTH * 3 + 3) & ~3
        push    edi                 ; preserve edi on stack, edi holds bmp row's width

        mov     edx, [ecx]          ; move current X POS from turtle context to ecx
        movzx   edi, BYTE [ecx+13]  ; move direction code from turtle context to edi
        movsx   eax, BYTE [h_movs + edi] ;move move multiplier to eax
        test    eax, eax            ; if multiplier is 0 we simply ignore horizontal movement
        jz      y_pos               ; jmp for vertical movement
        push    eax                 ; save multiplier to stack
        imul    eax, ebx            ; eax = multiplier * steps_to_move
        add     eax, edx            ; eax = multiplier * steps_to_move + current_position
        cmp     eax, esi            ; compare future position X with image's width
        jl      then_x_0            ; if future position < image's width, then ok
        mov     eax, esi            ; if not, set future position to image's border
        sub     eax, 1              ; and subtract 1, because position is 0 indexed
        jmp     then_x              ; after this operation, checking for negative future pos is unnecessary
then_x_0:
        test    eax, eax            ; check if future position (eax) is lower than 0
        jns     then_x              ; if not go to saving and drawing
        xor     eax, eax            ; if yes, set future position to 0
then_x:
        cmp     eax, edx            ; if future position == current position do nothing
        je      exit_from_move_x      ; and exit with correct stack balance

        mov     ecx, [ebp+TURTLE_CNTX_S_OFF]       ; move pointer to turtle_context from stack to ecx
        mov     [ecx], eax          ; move future position X (eax) to turtle_context
        pop     eax                 ; eax = multiplier from stack
        mov     bl, [ecx+12]        ; move pen state flag to bl
        test    bl, bl              ; check if pen state is one
        pop     edi                 ; edi = bmp's width, pop here to maintain stack balance
        jz      exit_correct        ; if pen state is zero, simply exit
        mov     ebx, [ecx + 4]      ; ebx = current Y pos of turtle
        imul    edi, ebx            ; edi = row_width * Y pos
        imul    esi, edx, 3         ; esi = current_pos * 3
        add     edi, esi            ; edi = edi + esi = row_width * Y pos + X pos * 3
        mov     ecx, [ebp+BMP_BUFFER_S_OFF]         ; ecx = pointer to bmp
        add     ecx, IM_OFF_PIXEL_ARRAY             ; ecx holds pointer to pixel array (pointer to buffer + offset)
        add     edi, ecx            ; edi holds absolute pixel index ( pointer to array + pixel index)

        mov     ecx, [ebp+TURTLE_CNTX_S_OFF]       ; ecx = turtle context pointer
        mov     ebx, [ecx+8]        ; ebx holds color from turtle context
        mov     ecx, [ecx]          ; ecx hold x pos from turtle context
        push    ebp                 ; preserve ebp on stack
        mov     ebp, ebx            ; ebp = ebx = color
        mov     esi, eax            ; esi = multiplier
        imul    eax, 3              ; eax = 3 * multiplier

draw_horizontal_line_loop:
        mov     ebx, ebp            ; move color from ebp to ebx
        mov     [edi], bx           ; move Green and Blue to bmp buffer at correct position
        shr     ebx, 16             ; shift right ebx by 16 bits to place red at it's correct position
        mov     [edi+2], bl         ; copy red into bmp buffer

        add     edx, esi            ; add multiplier (-1 or 1) to current position
        add     edi, eax            ; add multiplier (-3 or 3) to memory index
        cmp     edx, ecx            ; compare current position with future position
        jne     draw_horizontal_line_loop   ; if they are not equal repeat the loop

        mov     ebx, ebp            ; if they are, color the last pixel
        mov     [edi], bx           ; do the same as in four lines below draw_horizontal_line_loop
        shr     ebx, 16
        mov     [edi+2], bl

        pop     ebp                 ; restore ebp
        jmp     exit_correct        ; exit normally

y_pos:

        mov     esi, [ecx+4]            ; move old Y pos from turtle context to esi
        movsx   edx, BYTE[v_movs + edi] ; move Y multiplier to edx
        pop     edi                     ; edi = row's width
        mov     eax, edx                ; eax = multiplier
        imul    eax, ebx                ; multiply eax = coeff * ebx (steps to move)
        add     eax, esi                ; eax = steps to move + old position Y
        push    edx                     ; push multiplier (if we are in y_pos we know that is is != 0)
        mov     edx, [ebp+8]            ; edx = address for bmp buffer
        mov     edx, [edx+22]           ; edx = bmp's height
        cmp     eax, edx                ; compare future position (eax) with image's height (edx)
        jl      then_y_0                ; if future position is lower than height, check if it is lower than 0
        mov     eax, edx                ; if not => future pos = height
        sub     eax, 1                  ; future pos --
        jmp     then_y                  ; after this operation, checking for negative future pos is unnecessary
then_y_0:
        test    eax, eax            ; check if future position is negative
        jns     then_y              ; if not, proceed to then_y
        xor     eax, eax            ; if yes, set future pos to 0
then_y:
        cmp     eax, esi            ; if future position == old position
        je      exit_from_move      ; exit normally
        pop     edx                 ; edx holds multiplier
        mov     [ecx+4], eax        ; store new position in memory

        mov     bl, [ecx+12]        ; move pen state flag to bl
        test    bl, bl              ; check if pen state is one
        jz      exit_correct               ; if not don't draw, exit
        mov     ebx, esi            ; move current Y pos to ebx
        imul    ebx, edi            ; ebx = current Y * bytes_per_row
        mov     ecx, [ebp+BMP_BUFFER_S_OFF] ; ecx = beginning of bmp buffer
        add     ecx, IM_OFF_PIXEL_ARRAY     ; ecx = beginning + pixel offset
        add     ecx, ebx            ; ecx holds absolute pixel offset (correct row)
        mov     ebx, [ebp+TURTLE_CNTX_S_OFF]; ebx holds pointer to turtle context
        mov     ebx, [ebx]          ; ebx = current X position
        imul    ebx, 3              ; ebx = current X position * 3
        add     ecx, ebx            ; ecx holds absolute pixel offset (memory offset + row + width)
        mov     ebx, [ebp+TURTLE_CNTX_S_OFF] ; ebx holds pointer to turtle context
        mov     ebx, [ebx+8]        ; ebx = turtle's color
        push    ebp                 ; preserve ebp on stack
        mov     ebp, ebx            ; ebp also holds color
        imul    edi, edx            ; edi = bytes per row * multiplier (-1 or 1), because we traverse vertically

draw_vertical_line:
        mov     ebx, ebp            ; move color from ebp to ebx
        mov     [ecx], bx           ; move Green and Blue into memory
        shr     ebx, 16             ; shift right color register by 16 (00...0RRRRRRRR)
        mov     [ecx+2], bl         ; move Red to memory

        add     esi, edx            ; current position += multiplier (-1 or 1)
        add     ecx, edi            ; memory index += bytes per row * multiplier (-1 or 1)
        cmp     esi, eax            ; check if current position == future position
        jne     draw_vertical_line  ; if not, repeat the loop

        mov     ebx, ebp            ; color last pixel in the same way as above
        mov     [ecx], bx
        shr     ebx, 16
        mov     [ecx+2], bl

        pop     ebp                 ; restore ebp
        jmp     exit_correct        ; exit correctly
;========END CMD MOVE===========================


;========CASE CMD SET PEN STATE=================
cmd_set_pen_state:
        mov     bx, [eax]       ; move 2bytes of instruction to bx
        shr     bh, 3           ; shift right for correct bit position of pen state
        and     bh, 0x01        ; mask pen state
        mov     [ecx+12], bh    ; move pen state information to turtle context struct
        shr     bl, 5           ; shift bl by 5 to have correct color info at right bits
        movzx   edx, bl         ; move color code to edx
        mov     ebx, [colors + edx*4] ; exchange color code to real color with using static array
        mov     [ecx+8], ebx    ; move correct RGB color to turtle context struct
;========END CMD SET PEN STATE==================


exit_correct:   ; label for correct exit
	    mov     eax, EXIT_CODE_CORRECT  ; exit with correct code in eax
	    pop	    ebp
	    ret

exit_from_move_x:
        add     esp, 4                 ; when exiting from x pos region, add 4 to stack

exit_from_move: ; special type of exit with maintaining correct stack balance.
        add     esp, 4                  ; balance the stack
        mov     eax, EXIT_CODE_CORRECT  ; move exit code to eax
        pop     ebp                     ; restore ebp
        ret                             ; return


