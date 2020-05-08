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

section .data
h_movs  DB  1, 0, -1, 0
v_movs  DB  0, 1, 0, -1

colors  DD  COLR_BLACK, COLR_RED, COLR_GREEN, COLR_BLUE, COLR_YELL, COLR_CYAN, COLR_PURPL, COLR_WHITE

section	.text
global  exec_turtle_cmd, _exec_turtle_cmd

exec_turtle_cmd:
_exec_turtle_cmd:
        push	ebp
        mov	    ebp, esp              ; prologue

        mov	    eax, DWORD [ebp+12]	  ; address of instruction buffer to eax
        mov     bl, [eax+1]           ; load four bytes of the instruction to eax
        mov     ecx, [ebp+16]         ; move address to turtle_context struct to ecx
        and     ebx, MASK_CMD_TYPE    ; mask ebx in order to hold instruction information only
        ;switch case eqiv below
        jz      cmd_set_pen_state     ; case set pen state: code is 0x00 so that we can use 'and' above which sets ZF
        cmp     bl, CMD_SET_POS       ; case CMD set position
        je      cmd_set_pos
        cmp     bl, CMD_SET_DIR       ; case CMD set direction
        je      cmd_set_dir
        cmp     bl, CMD_MOVE          ; case CMD move
        je      cmd_move
        mov     eax, DWORD 2          ; if instruction was not found, exit with code 2
        jmp     exit1

cmd_set_pos:
        mov     ebx, [eax]          ; ebx holds address to instruction which is   --------|y5....0--|x1x0------|x9......x2
        ror     bx, 14              ;'exchange' two bytes (on lsb part of ebx) => --------|y5....0--|------x9x8.....x2x1x0
        and     bx, 0x3FF
        mov     [ecx], bx           ; move first 10 bits of bx (x9...x0) to x_pos in turtle_struct
        shr     ebx, 18
        and     ebx, 0x3F            ; ignore 8 msb bits with mask 00000000|y5....0
        mov     [ecx+4], ebx         ; move 00000000 | y5....0 to x_pos in turtle_struct

        mov     eax, DWORD 0x07     ; set exit code to special 7 which indicates that this instruction has 4 bytes
        jmp     exit1               ; jump to exit

cmd_set_dir:
        mov     bl, [eax+1]         ; move instruction to bl
        shr     bl, 2               ; shift right by 2 to have direction on correct bit positions
        and     bl, 0x03            ; mask bl in order to remove unnecessary bits
        mov     [ecx+13], bl        ; write position to turtle_context->position
        mov     eax, DWORD 11       ; exit with code 11
        jmp     exit1

cmd_move:
        mov     bx, [eax]           ; move two bytes of instruction to bx
        ror     bx, 10              ; rotate bits by 10 to get bits on correct positions
        and     ebx, 0x3FF          ; mask with 0b00001111 11111111 to remove trash bits

        mov     eax, [ebp + 8]                ; addr of image to eax
        mov     esi, [eax + IM_OFF_WIDTH]     ; move width to esi

        imul    edi, esi, 3         ; edi = esi * 3
        add     edi, 3              ; edi = edi + 3
        and     edi, CLOSEST_FOUR_MUL_MASK; edi = edi & ~3
        push    edi                 ; preserve edi on stack, edi holds bmp row's width

        mov     edx, [ecx]          ; move current X POS from turtle context to ecx
        movzx   edi, BYTE [ecx+13]  ; move direction code from turtle context to edi
        movsx   eax, BYTE [h_movs + edi] ;move move multiplier to eax
        test    eax, eax            ; if multiplier is 0 we simply ignore horizontal movement
        jz      y_pos               ; jmp for vertical movement
        push    eax                 ; save multiplier to stack
        imul    eax, ebx            ; eax = multiplier * steps_to_move
        add     eax, edx            ; eax = correct_steps_to_move + current_position
        cmp     eax, esi            ; compare future position X with image's width
        jl      then_x_0              ; if future position is below, then ok
        mov     eax, esi            ; if not, set future position to image's border
        sub     eax, 1              ; and subtract 1, because position is 0 indexed
        cmp     eax, edx
        je      exit_from_move
then_x_0:
        test    eax, eax
        jns     then_x
        xor     eax, eax
then_x:
        mov     ecx, [ebp+16]       ; move pointer to turtle_context to ecx
        mov     [ecx], eax          ; move future position X (eax) to turtle_context
        pop     eax                 ; eax = multiplier
        mov     bl, [ecx+12]        ; move pen state flag to bl
        test    bl, bl              ; check if pen state is one
        pop     edi                 ; edi = bmp's width
        jz      exit1               ; if zero, simply exit
        mov     ebx, [ecx + 4]      ; ebx = current Y pos of turtle
        imul    edi, ebx            ; edi = row_width * Y pos
        imul    esi, edx, 3         ; esi = current_pos * 3
        add     edi, esi            ; edi = edi + esi = row_width * Y pos + X pos * 3
        mov     ecx, [ebp+8]        ; ecx = pointer to bmp
        add     ecx, IM_OFF_PIXEL_ARRAY ;ecx holds pointer to pixel array
        add     edi, ecx            ; edi holds absolute pixel index

        mov     ecx, [ebp+16]
        mov     ebx, [ecx+8]        ;ebx holds color
        mov     ecx, [ecx]
        push    ebp
        mov     ebp, ebx
        mov     esi, eax
        imul    eax, 3              ; eax = 3 * sign


draw_horizontal_line_loop:
        mov     ebx, ebp
        mov     [edi], bx
        shr     ebx, 16
        mov     [edi+2], bl

        add     edx, esi
        add     edi, eax
        cmp     edx, ecx
        jne     draw_horizontal_line_loop

        mov     ebx, ebp
        mov     [edi], bx
        shr     ebx, 16
        mov     [edi+2], bl

        pop     ebp
        mov     eax, DWORD 13
        jmp     exit1

y_pos:

        mov     esi, [ecx+4]            ; move old Y pos from turtle context to esi
        movsx   edx, BYTE[v_movs + edi] ; move Y coefficient to edx
        pop     edi
        push    edx
        mov     eax, edx
        imul    eax, ebx                ; multiply eax = coeff * ebx (steps to move)
        add     eax, esi                ; add new position to eax
        mov     edx, [ebp+8]
        mov     edx, [edx+22]
        cmp     eax, edx
        jl      then_y_0
        mov     eax, edx
        sub     eax, 1
        cmp     eax, esi
        je      exit_from_move
then_y_0:
        test    eax, eax
        jns     then_y
        xor     eax, eax
then_y:
        pop     edx                 ; edx holds coeff
        mov     [ecx+4], eax        ; store new position in memory

        mov     bl, [ecx+12]        ; move pen state flag to bl
        test    bl, bl              ; check if pen state is one
        jz      exit1               ; if not don't draw, exit
        mov     ebx, esi            ; move current Y pos to ebx
        imul    ebx, edi            ; ebx = current Y * bytes_per_row
        mov     ecx, [ebp+8]
        add     ecx, IM_OFF_PIXEL_ARRAY
        add     ecx, ebx            ; ecx holds absolute pixel offset
        mov     ebx, [ebp+16]
        mov     ebx, [ebx]
        imul    ebx, 3
        add     ecx, ebx
        mov     ebx, [ebp+16]
        mov     ebx, [ebx+8]        ; ebx holds color
        push    ebp
        mov     ebp, ebx            ; ebp also holds color
        imul    edi, edx

draw_vertical_line:
        mov     ebx, ebp
        mov     [ecx], bx
        shr     ebx, 16
        mov     [ecx+2], bl

        add     esi, edx
        add     ecx, edi
        cmp     esi, eax
        jne     draw_vertical_line

        pop     ebp
        mov     eax, DWORD 13
        jmp     exit1


cmd_set_pen_state:
        mov     bx, [eax]       ; move 2bytes of instruction to bx
        shr     bh, 3           ; shift right for correct bit position of pen state
        and     bh, 0x01        ; mask pen state
        mov     [ecx+12], bh    ; move pen state information to turtle context struct
        shr     bl, 5           ; shift bl by 5 to have correct color info at right bits
        movzx   edx, bl         ; move color code to edx
        mov     ebx, [colors + edx*4] ; exchange color code to real color with using static array
        mov     [ecx+8], ebx    ; move correct RGB color to turtle context struct
        mov     eax, DWORD 12   ; exit with code 12

exit1:
	    pop	    ebp
	    ret

exit_from_move:
        add     esp, 8
        pop     ebp
        ret


