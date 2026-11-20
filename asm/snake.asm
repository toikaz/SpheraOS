; ============================================================
;  SNAKE.BIN - beads-on-a-string snake for SpheraOS (VGA 320x200)
;  Arrows / WASD steer, P pause, ESC quit.
;  Build: nasm -f bin snake.asm -o SNAKE.BIN     run: run /GAMES/SNAKE.BIN
; ============================================================
BITS 16
ORG 0

GW      equ 40
GH      equ 23
OY      equ 16

start:
    cld
    mov ax, cs
    mov ds, ax
    mov ax, 0x1130
    mov bh, 3
    int 0x10
    mov [fontseg], es
    mov [fontoff], bp
    mov ax, 0x0013
    int 0x10
    mov ax, 0xA000
    mov es, ax
    call setpal
    xor ax, ax
    int 0x1A
    mov [seed], dx
    call title
.new:
    call initgame
    call drawfield
    call drawall
.loop:
    call getticks
    mov [last], ax
.wait:
    call keys
    cmp byte [quit], 0
    jne .exit
    call getticks
    sub ax, [last]
    cmp ax, [delay]
    jae .tick
    sti
    hlt
    jmp .wait
.tick:
    cmp byte [paused], 0
    jne .loop
    call step
    cmp byte [dead], 0
    je .loop
    call gameover
    cmp byte [quit], 0
    jne .exit
    jmp .new
.exit:
    mov ax, 0x0003
    int 0x10
    retf

; ---------------------------------------------------------------
getticks:
    push cx
    push dx
    xor ax, ax
    int 0x1A
    mov ax, dx
    pop dx
    pop cx
    ret

rnd:                            ; AX = random 0..32767
    mov ax, [seed]
    mov dx, 25173
    mul dx
    add ax, 13849
    mov [seed], ax
    shr ax, 1
    ret

keys:
    mov ah, 1
    int 0x16
    jz near .r
    xor ah, ah
    int 0x16
    cmp al, 27
    je near .esc
    or al, 0x20
    cmp al, 'p'
    je .pause
    cmp byte [paused], 0
    jne .unp
    cmp ah, 0x48
    je .up
    cmp al, 'w'
    je .up
    cmp ah, 0x50
    je .dn
    cmp al, 's'
    je .dn
    cmp ah, 0x4B
    je .lf
    cmp al, 'a'
    je .lf
    cmp ah, 0x4D
    je .rt
    cmp al, 'd'
    je .rt
    jmp keys
.up:
    cmp byte [diry], 1
    je keys
    mov byte [ndx], 0
    mov byte [ndy], -1
    jmp keys
.dn:
    cmp byte [diry], -1
    je keys
    mov byte [ndx], 0
    mov byte [ndy], 1
    jmp keys
.lf:
    cmp byte [dirx], 1
    je keys
    mov byte [ndx], -1
    mov byte [ndy], 0
    jmp keys
.rt:
    cmp byte [dirx], -1
    je near keys
    mov byte [ndx], 1
    mov byte [ndy], 0
    jmp keys
.pause:
    xor byte [paused], 1
    jmp keys
.unp:
    mov byte [paused], 0
    jmp keys
.esc:
    mov byte [quit], 1
.r:
    ret

; ---------------------------------------------------------------
initgame:
    mov di, grid
    mov cx, GW*GH
    xor al, al
.z:
    mov [di], al
    inc di
    loop .z
    mov word [score], 0
    mov word [delay], 4
    mov byte [dead], 0
    mov byte [paused], 0
    mov byte [dirx], 1
    mov byte [diry], 0
    mov byte [ndx], 1
    mov byte [ndy], 0
    mov word [head], 3
    mov word [tail], 0
    mov bx, 0
.s:
    mov al, bl
    add al, 15
    mov [sx+bx], al
    mov byte [sy+bx], GH/2
    movzx si, al
    mov ax, GH/2
    imul ax, GW
    add si, ax
    mov byte [grid+si], 1
    inc bx
    cmp bx, 4
    jb .s
    call placefood
    ret

placefood:
.again:
    call rnd
    xor dx, dx
    mov cx, GW
    div cx
    mov [foodx], dl
    call rnd
    xor dx, dx
    mov cx, GH
    div cx
    mov [foody], dl
    movzx ax, byte [foody]
    imul ax, GW
    movzx bx, byte [foodx]
    add bx, ax
    cmp byte [grid+bx], 0
    jne .again
    ret

; ---------------------------------------------------------------
step:
    mov al, [ndx]
    mov [dirx], al
    mov al, [ndy]
    mov [diry], al
    mov bx, [head]
    and bx, 1023
    movsx ax, byte [dirx]
    movzx cx, byte [sx+bx]
    add cx, ax
    movsx ax, byte [diry]
    movzx dx, byte [sy+bx]
    add dx, ax
    cmp cx, GW
    jae near .die
    cmp dx, GH
    jae near .die
    mov [nx], cl
    mov [ny], dl
    mov byte [eating], 0
    mov al, [foodx]
    cmp al, [nx]
    jne .noeat
    mov al, [foody]
    cmp al, [ny]
    jne .noeat
    mov byte [eating], 1
.noeat:
    cmp byte [eating], 0
    jne .coll
    mov bx, [tail]
    and bx, 1023
    movzx ax, byte [sy+bx]
    imul ax, GW
    movzx si, byte [sx+bx]
    add si, ax
    mov byte [grid+si], 0
    movzx cx, byte [sx+bx]
    movzx dx, byte [sy+bx]
    call erasecell
    inc word [tail]
.coll:
    movzx ax, byte [ny]
    imul ax, GW
    movzx si, byte [nx]
    add si, ax
    cmp byte [grid+si], 0
    jne .die
    mov byte [grid+si], 1
    inc word [head]
    mov bx, [head]
    and bx, 1023
    mov al, [nx]
    mov [sx+bx], al
    mov al, [ny]
    mov [sy+bx], al
    cmp byte [eating], 0
    je .draw
    add word [score], 10
    mov ax, [score]
    cmp ax, [hiscore]
    jbe .hs
    mov [hiscore], ax
.hs:
    mov ax, [score]
    xor dx, dx
    mov cx, 60
    div cx
    mov bx, 4
    sub bx, ax
    jg .sp
    mov bx, 1
.sp:
    mov [delay], bx
    call placefood
    call drawhud
.draw:
    call drawall
    ret
.die:
    mov byte [dead], 1
    ret

; ---------------------------------------------------------------
setpal:
    mov si, paltab
.l:
    lodsb
    cmp al, 0xFF
    je .ramp
    mov dx, 0x3C8
    out dx, al
    inc dx
    lodsb
    out dx, al
    lodsb
    out dx, al
    lodsb
    out dx, al
    jmp .l
.ramp:
    mov dx, 0x3C8
    mov al, 16
    out dx, al
    inc dx
    xor bx, bx
.r:
    imul ax, bx, 26
    shr ax, 5
    mov cl, al
    mov al, 30
    sub al, cl
    out dx, al
    imul ax, bx, 43
    shr ax, 5
    mov cl, al
    mov al, 63
    sub al, cl
    out dx, al
    imul ax, bx, 24
    shr ax, 5
    mov cl, al
    mov al, 30
    sub al, cl
    out dx, al
    inc bx
    cmp bx, 32
    jb .r
    ret

fillrect:                       ; BX=x CX=y DX=w SI=h AL=colour (ES=A000)
    pusha
    push ax
    mov ax, cx
    shl ax, 6
    mov di, ax
    shl ax, 2
    add di, ax
    add di, bx
    pop ax
.row:
    push di
    mov cx, dx
    rep stosb
    pop di
    add di, 320
    dec si
    jnz .row
    popa
    ret

drawfield:
    xor bx, bx
    xor cx, cx
    mov dx, 320
    mov si, 200
    mov al, 4
    call fillrect
    xor bx, bx
    mov cx, 12
    mov dx, 320
    mov si, 4
    mov al, 3
    call fillrect
    call drawhud
    xor dx, dx
.row:
    xor cx, cx
.col:
    call erasecell
    inc cx
    cmp cx, GW
    jb .col
    inc dx
    cmp dx, GH
    jb .row
    ret

erasecell:                      ; CX=cell x, DX=cell y
    pusha
    mov bx, cx
    shl bx, 3
    mov ax, dx
    shl ax, 3
    add ax, OY
    mov di, cx
    add di, dx
    and di, 1
    mov cx, ax
    mov al, [bgcol+di]
    mov dx, 8
    mov si, 8
    call fillrect
    popa
    ret

bead:                           ; CX=cell x, DX=cell y, AL=ramp colour, AH=ring colour
    pusha
    mov [bcol], ax
    mov bx, cx
    shl bx, 3
    mov ax, dx
    shl ax, 3
    add ax, OY
    mov cx, ax
    mov al, [bcol+1]
    mov dx, 8
    mov si, 8
    call fillrect
    inc bx
    inc cx
    mov al, [bcol]
    mov dx, 6
    mov si, 6
    call fillrect
    add bx, 1
    add cx, 1
    mov al, 60
    mov dx, 2
    mov si, 2
    call fillrect
    popa
    ret

drawall:
    pusha
    movzx cx, byte [foodx]
    movzx dx, byte [foody]
    call erasecell
    mov bx, cx
    shl bx, 3
    mov ax, dx
    shl ax, 3
    add ax, OY
    mov cx, ax
    mov al, 5
    mov dx, 8
    mov si, 8
    call fillrect
    inc bx
    inc cx
    mov al, 6
    mov dx, 6
    mov si, 6
    call fillrect
    add bx, 1
    add cx, 1
    mov al, 7
    mov dx, 2
    mov si, 2
    call fillrect
    add bx, 3
    sub cx, 3
    mov al, 10
    mov dx, 1
    mov si, 2
    call fillrect
    mov ax, [head]
    sub ax, [tail]
    inc ax
    mov [len], ax
    xor si, si
.seg:
    cmp si, [len]
    jae .done
    mov bx, [head]
    sub bx, si
    and bx, 1023
    movzx cx, byte [sx+bx]
    movzx dx, byte [sy+bx]
    mov ax, si
    mov di, 31
    mul di
    xor dx, dx
    mov di, [len]
    cmp di, 1
    jbe .one
    div di
    jmp .col
.one:
    xor ax, ax
.col:
    cmp ax, 31
    jbe .ok
    mov ax, 31
.ok:
    add al, 16
    mov ah, 48
    movzx bx, byte [sx+bx]
    mov bx, [head]
    sub bx, si
    and bx, 1023
    movzx cx, byte [sx+bx]
    movzx dx, byte [sy+bx]
    call bead
    inc si
    jmp .seg
.done:
    popa
    ret

; ---------------------------------------------------------------
text:                           ; DS:SI asciiz, BX=x CX=y, DL=colour, [tsc]=scale
    pusha
    mov [tcol], dl
.ch:
    lodsb
    test al, al
    jz .done
    push si
    push bx
    push cx
    xor ah, ah
    shl ax, 3
    add ax, [fontoff]
    mov si, ax
    mov fs, [fontseg]
    mov di, 8
.rw:
    mov ah, [fs:si]
    inc si
    push bx
    mov bp, 8
.bt:
    shl ah, 1
    jnc .nb
    push ax
    push si
    push di
    push bp
    mov al, [tcol]
    mov dx, [tsc]
    mov si, dx
    call fillrect
    pop bp
    pop di
    pop si
    pop ax
.nb:
    add bx, [tsc]
    dec bp
    jnz .bt
    pop bx
    add cx, [tsc]
    dec di
    jnz .rw
    pop cx
    pop bx
    pop si
    mov ax, 8
    mul word [tsc]
    add bx, ax
    jmp .ch
.done:
    popa
    ret

drawhud:
    pusha
    xor bx, bx
    xor cx, cx
    mov dx, 320
    mov si, 12
    mov al, 4
    call fillrect
    mov word [tsc], 1
    mov si, s_score
    mov bx, 8
    mov cx, 2
    mov dl, 8
    call text
    mov ax, [score]
    mov di, numbuf
    call itoa
    mov si, numbuf
    mov bx, 64
    mov cx, 2
    mov dl, 9
    call text
    mov si, s_hi
    mov bx, 200
    mov cx, 2
    mov dl, 8
    call text
    mov ax, [hiscore]
    mov di, numbuf
    call itoa
    mov si, numbuf
    mov bx, 248
    mov cx, 2
    mov dl, 9
    call text
    popa
    ret

itoa:                           ; AX -> DI asciiz
    pusha
    mov bx, 10
    xor cx, cx
.d:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .d
.o:
    pop ax
    add al, '0'
    mov [di], al
    inc di
    loop .o
    mov byte [di], 0
    popa
    ret

title:
    xor bx, bx
    xor cx, cx
    mov dx, 320
    mov si, 200
    mov al, 4
    call fillrect
    mov word [tsc], 5
    mov si, s_title
    mov bx, 60
    mov cx, 50
    mov dl, 17
    call text
    mov word [tsc], 1
    mov si, s_press
    mov bx, 88
    mov cx, 130
    mov dl, 8
    call text
    mov si, s_keys
    mov bx, 56
    mov cx, 150
    mov dl, 3
    call text
    xor ax, ax
    int 0x16
    ret

gameover:
    mov word [tsc], 3
    mov si, s_over
    mov bx, 52
    mov cx, 70
    mov dl, 6
    call text
    mov word [tsc], 1
    mov si, s_again
    mov bx, 72
    mov cx, 110
    mov dl, 8
    call text
.w:
    xor ax, ax
    int 0x16
    cmp al, 27
    je .q
    or al, 0x20
    cmp al, 'r'
    jne .w
    ret
.q:
    mov byte [quit], 1
    ret

; ---------------------------------------------------------------
s_score db "SCORE", 0
s_hi    db "BEST", 0
s_title db "SNAKE", 0
s_press db "Press any key to start", 0
s_keys  db "Arrows/WASD  P pause  ESC quit", 0
s_over  db "GAME OVER", 0
s_again db "R: again   ESC: quit", 0
bgcol   db 1, 2
paltab  db 0, 0, 0, 0
        db 1, 3, 9, 13
        db 2, 5, 12, 17
        db 3, 30, 34, 52
        db 4, 4, 4, 14
        db 5, 28, 0, 0
        db 6, 58, 8, 8
        db 7, 63, 58, 58
        db 8, 48, 62, 48
        db 9, 63, 56, 10
        db 10, 20, 50, 12
        db 17, 20, 63, 20
        db 60, 52, 63, 52
        db 0xFF

absolute 0x1000
fontseg resw 1
fontoff resw 1
seed    resw 1
last    resw 1
delay   resw 1
score   resw 1
hiscore resw 1
head    resw 1
tail    resw 1
len     resw 1
tsc     resw 1
bcol    resw 1
tcol    resb 1
dirx    resb 1
diry    resb 1
ndx     resb 1
ndy     resb 1
nx      resb 1
ny      resb 1
foodx   resb 1
foody   resb 1
dead    resb 1
paused  resb 1
quit    resb 1
eating  resb 1
numbuf  resb 8
grid    resb GW*GH
sx      resb 1024
sy      resb 1024
