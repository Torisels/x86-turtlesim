
%define CMD_SET_POS 0x03
%define CMD_SET_DIR 0x02
%define CMD_MOVE    0x01
%define CMD_SET_PEN_STATE 0x00
%define MASK_CMD_TYPE 0x03
section	.text
global  exec_turtle_cmd, _exec_turtle_cmd
exec_turtle_cmd:
        push	ebp
        mov	    ebp, esp
        mov	    eax, DWORD [ebp+12]	 ;address of instruction buffer to eax
        xor     ebx, ebx
        mov     bl, [eax+1]           ;load four bytes of the instruction to eax
        and     bl, MASK_CMD_TYPE
        cmp     bl, CMD_SET_POS
        je      cmd_set_pos
        cmp     bl, CMD_SET_DIR
        je      cmd_set_dir

cmd_set_pos:
        mov     edx, [ebp+16]   ;edx holds address to turtle context struct
        mov     ebx, [eax]      ;ebx holds address to instruction which is --------|y5....0--|x1x0------|x9......x2
        ror     bx, 8           ;'exchange' two bytes (on lsb) =>          --------|y5....0--|x9......x2|x1x0------)
        shld    [edx], bx, 10   ; move first 10 bits of bx (x9...x0) to x_pos in turtle_struct
        and     ebx, 0xFF0000   ; ignore 8 msb bits with mask 00000000|y5....0
        shld    [edx+4], ebx, 14; move 00000000 | y5....0 to x_pos in turtle_struct
        mov     eax, DWORD 0x07
        jmp     exit1

cmd_set_dir:
        mov     bl, [eax+1]
        shr     bl, 2
        and     bl, 0x03
        mov     edx, [ebp+16]
        mov     [edx+13], bl
        mov     eax, DWORD 11
exit1:
	    pop	    ebp
	    ret




;============================================
; THE STACK
;============================================
;
; larger addresses
;
;  |                               |
;  | ...                           |
;  ---------------------------------
;  | function parameter - char *a  | EBP+8
;  ---------------------------------
;  | return address                | EBP+4
;  ---------------------------------
;  | saved caller's ebp            | EBP, ESP
;  ---------------------------------
;  | ... here local variables      | EBP-x
;  |     when needed               |
;
; \/                              \/
; \/ the stack grows in this      \/
; \/ direction                    \/
;
; lower addresses
;
;
;============================================



