
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
        mov     bl, [eax+1]           ;load four bytes of the instruction to eax
        and     bl, MASK_CMD_TYPE
        cmp     bl, CMD_SET_POS
        je      cmd_set_pos
        cmp     bl, CMD_MOVE

cmd_set_pos:
        mov     edx, [ebp+16]   ;edx holds address to turtle context struct
        mov     ebx, [eax]      ;ebx holds address to instruction
        ror     bx, 8           ;'exchange' first two bytes
        movzx   ecx, bx         ; move lowest 16bits from ebx to ecx
        shr     ecx, 6          ; shift right ecx to move XPOS val at is't correct bit positions
        mov     [edx], ecx
        shr     ebx, 18
        and     ebx, 0x3F
        mov     [edx+4], ebx
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



