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

section .data
h_movs  DB  1, 0, -1, 0
v_movs  DB  0, 1, 0, -1

colors  DD  COLR_BLACK, COLR_RED, COLR_GREEN, COLR_BLUE, COLR_YELL, COLR_CYAN, COLR_PURPL, COLR_WHITE

section	.text
global  exec_turtle_cmd, _exec_turtle_cmd
exec_turtle_cmd:
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
        ror     bx, 8               ;'exchange' two bytes (on lsb part of ebx) => --------|y5....0--|x9......x2|x1x0------)
        shld    [ecx], bx, 10       ; move first 10 bits of bx (x9...x0) to x_pos in turtle_struct
        and     ebx, 0xFF0000       ; ignore 8 msb bits with mask 00000000|y5....0
        shld    [ecx+4], ebx, 14    ; move 00000000 | y5....0 to x_pos in turtle_struct

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

        mov     ecx, [ebp+16]       ; address of turtle context struct to ecx
        mov     esi, [ecx]          ; move current X POS from turtle context to esi
        movzx   edi, BYTE [ecx+13]  ; move direction code from turtle context to edi
        movsx   eax, BYTE [h_movs + edi]
        mul     ebx
        add     eax, esi
        mov     [ecx], eax

        mov     esi, [ecx+4]
        movsx   eax, BYTE[v_movs + edi]
        mul     ebx
        add     eax, esi
        mov     [ecx+4], eax

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



