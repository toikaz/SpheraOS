; ============================================================
;  mandel.asm - Mandelbrot explorer for SpheraOS GUI
;  nasm -f bin -I gui/ mandel.asm -o asm/mandel.app
;  Arrows = pan, +/- = zoom, R = reset, Esc = quit.
;  The picture is computed a few rows per tick, then painted.
; ============================================================
BITS 16
ORG 0
%include "sdk.inc"

APP_HEADER "Mandel", 200, 150

W      equ 192
H      equ 128
BX0    equ 4
BY0    equ 10
MAXIT  equ 24

entry:
    push cs
    pop ds
    push cs
    pop es
    cmp ax, MSG_INIT
    je near h_init
    cmp ax, MSG_TICK
    je near h_tick
    cmp ax, MSG_KEY
    je near h_key
    cmp ax, MSG_DRAW
    je near h_draw
    xor al, al
    retf

h_init:
    call reset_view
    xor al, al
    retf

reset_view:
    mov word [cenx], -64         ; -0.5 in Q7
    mov word [ceny], 0
    mov word [spanx], 384        ; 3.0
    mov word [spany], 256        ; 2.0
    jmp start_render

start_render:
    mov ax, [spanx]
    xor dx, dx
    mov bx, W
    div bx
    test ax, ax
    jnz .sx
    mov ax, 1
.sx:
    mov [stepx], ax
    mov ax, [spany]
    xor dx, dx
    mov bx, H
    div bx
    test ax, ax
    jnz .sy
    mov ax, 1
.sy:
    mov [stepy], ax

    mov ax, [spanx]
    shr ax, 1
    mov bx, [cenx]
    sub bx, ax
    mov [startx], bx
    mov ax, [spany]
    shr ax, 1
    mov bx, [ceny]
    sub bx, ax
    mov [starty], bx

    mov word [row], 0
    mov byte [done], 0
    ret

; ------------------------------------------------------------
; signed fixed-point helpers: (AX*BX)>>shift
; ------------------------------------------------------------
ms7:
    imul bx
    shrd ax, dx, 7
    ret

ms6:
    imul bx
    shrd ax, dx, 6
    ret

; ------------------------------------------------------------
h_tick:
    cmp byte [done], 0
    jne .no
    mov byte [chunk], 4
.chunk:
    cmp byte [chunk], 0
    je .no
    mov ax, [row]
    cmp ax, H
    jae .finished
    call render_row
    inc word [row]
    dec byte [chunk]
    jmp .chunk
.finished:
    mov byte [done], 1
    mov al, 1
    retf
.no:
    xor al, al
    retf

; render one row at [row]
render_row:
    mov ax, [row]
    mov bx, [stepy]
    mul bx
    add ax, [starty]
    mov [cyv], ax
    mov word [col], 0
.pix:
    cmp word [col], W
    jae .end
    mov ax, [col]
    mov bx, [stepx]
    mul bx
    add ax, [startx]
    mov [cxv], ax

    mov word [zx], 0
    mov word [zy], 0
    mov word [it], 0
.iter:
    mov ax, [zx]
    mov bx, ax
    call ms7
    mov [zx2], ax
    mov ax, [zy]
    mov bx, ax
    call ms7
    mov [zy2], ax
    mov ax, [zx2]
    add ax, [zy2]
    cmp ax, 4*128                ; escape radius 2.0 in Q7
    jg .esc
    mov ax, [zx]
    mov bx, [zy]
    call ms6
    add ax, [cyv]
    mov [zy], ax
    mov ax, [zx2]
    sub ax, [zy2]
    add ax, [cxv]
    mov [zx], ax
    inc word [it]
    cmp word [it], MAXIT
    jb .iter

    mov ax, [row]
    mov bx, W
    mul bx
    add ax, [col]
    mov di, ax
    mov byte [bitmap+di], 0
    jmp .next
.esc:
    mov ax, [it]
    and ax, 15
    mov bx, ax
    mov al, [pal+bx]
    mov [colc], al
    mov ax, [row]
    mov bx, W
    mul bx
    add ax, [col]
    mov di, ax
    mov al, [colc]
    mov [bitmap+di], al
.next:
    inc word [col]
    jmp .pix
.end:
    ret

; ------------------------------------------------------------
h_key:
    cmp bh, KEY_ESC
    jne .k1
    GUI API_EXIT
    xor al, al
    retf
.k1:
    cmp bl, 'r'
    je .reset
    cmp bl, 'R'
    je .reset
    cmp bl, '+'
    je .zin
    cmp bl, '='
    je .zin
    cmp bl, '-'
    je .zout
    cmp bh, KEY_LEFT
    jne .kr
    mov ax, [spanx]
    shr ax, 3
    sub [cenx], ax
    jmp .redraw
.kr:
    cmp bh, KEY_RIGHT
    jne .ku
    mov ax, [spanx]
    shr ax, 3
    add [cenx], ax
    jmp .redraw
.ku:
    cmp bh, KEY_UP
    jne .kd
    mov ax, [spany]
    shr ax, 3
    sub [ceny], ax
    jmp .redraw
.kd:
    cmp bh, KEY_DOWN
    jne .no
    mov ax, [spany]
    shr ax, 3
    add [ceny], ax
    jmp .redraw
.zin:
    cmp word [spanx], 8
    jbe .no
    shr word [spanx], 1
    shr word [spany], 1
    jmp .redraw
.zout:
    cmp word [spanx], 2048
    jae .no
    shl word [spanx], 1
    shl word [spany], 1
    jmp .redraw
.reset:
    call reset_view
    jmp .no
.redraw:
    call start_render
    jmp .no
.no:
    xor al, al
    retf

; ------------------------------------------------------------
h_draw:
    mov al, 0
    GUI API_CLEAR
    cmp byte [done], 0
    je .text
    mov word [yy], 0
.row:
    mov ax, [yy]
    cmp ax, H
    jae .text
    mov word [xx], 0
.col:
    mov ax, [xx]
    cmp ax, W
    jae .nextrow
    mov ax, [yy]
    mov bx, W
    mul bx
    add ax, [xx]
    mov di, ax
    mov al, [bitmap+di]
    test al, al
    jz .skip
    mov bx, [xx]
    add bx, BX0
    mov cx, [yy]
    add cx, BY0
    GUI API_PIX
.skip:
    inc word [xx]
    jmp .col
.nextrow:
    inc word [yy]
    jmp .row

.text:
    mov si, s_title
    mov bx, 60
    mov cx, 1
    mov dl, 10
    GUI API_STR
    mov si, s_hint
    mov bx, 44
    mov cx, 140
    mov dl, 8
    GUI API_STR
    xor al, al
    retf

; ------------------------------------------------------------
cenx    dw 0
ceny    dw 0
spanx   dw 0
spany   dw 0
stepx   dw 0
stepy   dw 0
startx  dw 0
starty  dw 0
row     dw 0
col     dw 0
yy      dw 0
xx      dw 0
chunk   db 0
done    db 0

zx      dw 0
zy      dw 0
zx2     dw 0
zy2     dw 0
cxv     dw 0
cyv     dw 0
it      dw 0
colc    db 0

pal     db 1,9,11,3,10,14,12,4,13,5,15,6,2,7,8,9

s_title db "MANDELBROT", 0
s_hint  db "ARROWS  +/-  R", 0

bitmap  times W*H db 0
