; ============================================================
;  palette.asm - VGA 256-colour palette explorer
;  nasm -f bin -I gui/ palette.asm -o asm/palette.app
;  Arrows = move, PgUp/PgDn = jump 16, Esc = quit.
; ============================================================
BITS 16
ORG 0
%include "sdk.inc"

APP_HEADER "Palette", 200, 160

GX  equ 4
GY  equ 20
CW  equ 10
CELLH  equ 8

entry:
    push cs
    pop ds
    push cs
    pop es
    cmp ax, MSG_INIT
    je near h_init
    cmp ax, MSG_KEY
    je near h_key
    cmp ax, MSG_DRAW
    je near h_draw
    xor al, al
    retf

h_init:
    mov word [selx], 0
    mov word [sely], 0
    xor al, al
    retf

h_key:
    cmp bh, KEY_ESC
    jne .k1
    GUI API_EXIT
    xor al, al
    retf
.k1:
    cmp bh, KEY_LEFT
    jne .kr
    cmp word [selx], 0
    je .no
    dec word [selx]
    jmp .yes
.kr:
    cmp bh, KEY_RIGHT
    jne .ku
    cmp word [selx], 15
    jae .no
    inc word [selx]
    jmp .yes
.ku:
    cmp bh, KEY_UP
    jne .kd
    cmp word [sely], 0
    je .no
    dec word [sely]
    jmp .yes
.kd:
    cmp bh, KEY_DOWN
    jne .pg
    cmp word [sely], 15
    jae .no
    inc word [sely]
    jmp .yes
.pg:
    cmp bh, 0x49                ; PgUp
    jne .pd
    cmp word [sely], 0
    je .no
    sub word [sely], 2
    jns .yes
    mov word [sely], 0
    jmp .yes
.pd:
    cmp bh, 0x51                ; PgDn
    jne .no
    cmp word [sely], 15
    jae .no
    add word [sely], 2
    cmp word [sely], 15
    jbe .yes
    mov word [sely], 15
.yes:
    mov al, 1
    retf
.no:
    xor al, al
    retf

; ------------------------------------------------------------
h_draw:
    mov al, 0
    GUI API_CLEAR

    mov word [yy], 0
.row:
    cmp word [yy], 16
    jae .cursor
    mov word [xx], 0
.col:
    cmp word [xx], 16
    jae .nextrow
    mov ax, [yy]
    shl ax, 4
    add ax, [xx]
    mov [idx], ax
    mov bx, [xx]
    imul bx, bx, CW
    add bx, GX
    mov cx, [yy]
    imul cx, cx, CELLH
    add cx, GY
    mov al, [idx]
    mov dx, CW-1
    mov si, CELLH-1
    GUI API_FILL
    inc word [xx]
    jmp .col
.nextrow:
    inc word [yy]
    jmp .row

.cursor:
    mov bx, [selx]
    imul bx, bx, CW
    add bx, GX
    dec bx
    mov cx, [sely]
    imul cx, cx, CELLH
    add cx, GY
    dec cx
    mov al, 15
    mov dx, CW+1
    mov si, 1
    GUI API_FILL
    mov bx, [selx]
    imul bx, bx, CW
    add bx, GX
    dec bx
    mov cx, [sely]
    imul cx, cx, CELLH
    add cx, GY
    add cx, CELLH
    mov dx, CW+1
    mov si, 1
    GUI API_FILL
    mov bx, [selx]
    imul bx, bx, CW
    add bx, GX
    dec bx
    mov cx, [sely]
    imul cx, cx, CELLH
    add cx, GY
    mov dx, 1
    mov si, CELLH+1
    GUI API_FILL
    mov bx, [selx]
    imul bx, bx, CW
    add bx, GX
    add bx, CW
    mov cx, [sely]
    imul cx, cx, CELLH
    add cx, GY
    mov dx, 1
    mov si, CELLH+1
    GUI API_FILL

    ; ---- selected colour preview ----
    mov ax, [sely]
    shl ax, 4
    add ax, [selx]
    mov [idx], ax
    mov bx, 170
    mov cx, 20
    mov dx, 26
    mov si, 52
    mov al, [idx]
    GUI API_FILL
    mov al, 8
    mov bx, 169
    mov cx, 19
    mov dx, 28
    mov si, 1
    GUI API_FILL
    mov bx, 169
    mov cx, 71
    mov dx, 28
    mov si, 1
    GUI API_FILL
    mov bx, 169
    mov cx, 19
    mov dx, 1
    mov si, 53
    GUI API_FILL
    mov bx, 196
    mov cx, 19
    mov dx, 1
    mov si, 53
    GUI API_FILL

    mov si, s_idx
    mov bx, 168
    mov cx, 78
    mov dl, 8
    GUI API_STR
    mov al, 15
    mov bx, 168
    mov cx, 88
    mov dx, [idx]
    GUI API_NUM

    mov si, s_hex
    mov bx, 168
    mov cx, 100
    mov dl, 8
    GUI API_STR
    mov al, 15
    mov bx, 168
    mov cx, 110
    mov dx, [idx]
    call draw_hex

    ; ---- hint at the bottom ----
    mov si, s_hint
    mov bx, 4
    mov cx, 152
    mov dl, 8
    GUI API_STR
    xor al, al
    retf

; draw DX as "$00" at BX,CX in colour AL
draw_hex:
    mov [hx], bx
    mov [hy], cx
    mov [hc], al
    mov di, hbuf
    mov byte [di], '$'
    inc di
    mov ax, dx
    mov bl, 16
    div bl
    add al, '0'
    cmp al, '9'
    jbe .a
    add al, 7
.a:
    mov [di], al
    inc di
    mov al, ah
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .b
    add al, 7
.b:
    mov [di], al
    inc di
    mov byte [di], 0
    mov si, hbuf
    mov bx, [hx]
    mov cx, [hy]
    mov dl, [hc]
    GUI API_STR
    ret

; ------------------------------------------------------------
selx    dw 0
sely    dw 0
xx      dw 0
yy      dw 0
idx     dw 0
hx      dw 0
hy      dw 0
hc      db 0
hbuf    times 5 db 0

s_idx  db "IDX", 0
s_hex  db "HEX", 0
s_hint db "ARROWS  PGUP/DN  ESC", 0
