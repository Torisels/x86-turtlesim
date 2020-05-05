section	.text
global  exec_turtle_cmd, _exec_turtle_cmd
exec_turtle_cmd:
        push	ebp
        mov	    ebp, esp
        mov	    eax, DWORD [ebp+8]	;address of *a to eax

exit:
        mov     BYTE [ebx], 0
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



