; ============================================================
;  tetris.asm - falling blocks for SpheraOS GUI
;  nasm -f bin -I gui/ tetris.asm -o asm/tetris.app
;  Left/Right = move, Up/Enter = rotate, Down = soft drop,
;  Space = hard drop, P = pause, R = new game, Esc = quit.
; ============================================================
BITS 16
ORG 0
%include "sdk.inc"

APP_HEADER "Tetris", 176, 156

COLS  equ 10
ROWS  equ 16
CELL  equ 7
BXL   equ 8
BYT   equ 26
BSZ   equ COLS*ROWS

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

; ------------------------------------------------------------
h_init:
    call start_game
    xor al, al
    retf

start_game:
    mov bx, 0
    GUI API_SOUND
    mov word [snd], 0
    mov di, board
    mov cx, BSZ
    xor al, al
    rep stosb

    mov word [score], 0
    mov word [lines], 0
    mov byte [level], 1
    mov byte [over], 0
    mov byte [paused], 0
    mov byte [dropc], 0
    mov word [score2], 0

    mov bx, 7
    GUI API_RND
    mov [nextp], al
    call spawn
    ret

; spawn the piece from [nextp] and pick the following one
spawn:
    mov al, [nextp]
    mov [piece], al
    mov byte [rot], 0
    mov word [px], 3
    mov word [py], 0
    mov bx, 7
    GUI API_RND
    mov [nextp], al
    call collide
    jc .over
    ret
.over:
    mov byte [over], 1
    mov bx, 0
    GUI API_SOUND
    ret

; ------------------------------------------------------------
; collide: CF=1 if the current piece overlaps a wall/block
; ------------------------------------------------------------
collide:
    movzx si, byte [piece]
    shl si, 4
    movzx ax, byte [rot]
    shl ax, 2
    add si, ax
    add si, shapes

    mov word [srow], 0
.row:
    mov bx, [srow]
    mov al, [si+bx]
    mov [mask], al
    mov word [scol], 0
.col:
    mov bx, [scol]
    mov al, [mask]
    and al, [bitmask+bx]
    jz .next
    mov ax, [px]
    add ax, bx
    mov [tx], ax
    mov ax, [py]
    add ax, [srow]
    mov [ty], ax
    cmp word [tx], 0
    jl .hit
    cmp word [tx], COLS
    jae .hit
    cmp word [ty], ROWS
    jae .hit
    cmp word [ty], 0
    jl .next
    mov ax, [ty]
    mov bx, COLS
    mul bx
    add ax, [tx]
    mov di, ax
    cmp byte [board+di], 0
    jne .hit
.next:
    inc word [scol]
    cmp word [scol], 4
    jb .col
    inc word [srow]
    cmp word [srow], 4
    jb .row
    clc
    ret
.hit:
    stc
    ret

; ------------------------------------------------------------
; lock the current piece into the board and clear full lines
; ------------------------------------------------------------
lock_piece:
    movzx si, byte [piece]
    shl si, 4
    movzx ax, byte [rot]
    shl ax, 2
    add si, ax
    add si, shapes

    mov word [srow], 0
.row:
    mov bx, [srow]
    mov al, [si+bx]
    mov [mask], al
    mov word [scol], 0
.col:
    mov bx, [scol]
    mov al, [mask]
    and al, [bitmask+bx]
    jz .next
    mov ax, [px]
    add ax, bx
    mov [tx], ax
    mov ax, [py]
    add ax, [srow]
    mov [ty], ax
    cmp word [ty], 0
    jl .next                   ; a cell above the top vanishes
    cmp word [ty], ROWS
    jae .next
    mov ax, [ty]
    mov bx, COLS
    mul bx
    add ax, [tx]
    mov di, ax
    mov al, [piece]
    inc al
    mov [board+di], al
.next:
    inc word [scol]
    cmp word [scol], 4
    jb .col
    inc word [srow]
    cmp word [srow], 4
    jb .row

    call clear_lines
    call spawn
    ret

clear_lines:
    mov word [crow], ROWS-1
.scan:
    cmp word [crow], 0
    jl .done
    mov ax, [crow]
    mov bx, COLS
    mul bx
    mov di, ax
    mov cx, COLS
    xor bx, bx
.count:
    cmp byte [board+di], 0
    je .notfull
    inc di
    inc bx
    loop .count
    ; --- full line ---
    mov bx, [crow]
.shift:
    cmp bx, 0
    je .topmost
    mov ax, bx
    mov dx, COLS
    mul dx
    mov di, ax                  ; destination row
    mov si, di
    sub si, COLS                ; source row
    mov cx, COLS
.copy:
    mov al, [board+si]
    mov [board+di], al
    inc si
    inc di
    loop .copy
    dec bx
    jmp .shift
.topmost:
    mov di, board
    mov cx, COLS
    xor al, al
    rep stosb
    inc word [lines]
    call set_level
    mov ax, 100
    mov bl, [level]
    xor bh, bh
    mul bx
    add [score], ax
    inc word [score2]
    mov word [snd], 4
    mov bx, 2400
    GUI API_SOUND
    jmp .scan                   ; the same row may now be full again
.notfull:
    dec word [crow]
    jmp .scan
.done:
    ret

set_level:
    mov ax, [lines]
    xor dx, dx
    mov bx, 10
    div bx
    inc ax
    cmp ax, 20
    jbe .ok
    mov ax, 20
.ok:
    mov [level], al
    ret

; ------------------------------------------------------------
h_tick:
    ; beep timer
    cmp word [snd], 0
    je .nosnd
    dec word [snd]
    jnz .nosnd
    mov bx, 0
    GUI API_SOUND
.nosnd:
    cmp byte [over], 0
    jne .no
    cmp byte [paused], 0
    jne .no
    inc byte [dropc]
    mov al, 10
    sub al, [level]
    cmp al, 2
    jae .dly
    mov al, 2
.dly:
    cmp [dropc], al
    jb .no
    mov byte [dropc], 0
    inc word [py]
    call collide
    jnc .moved
    dec word [py]
    call lock_piece
    mov al, 1
    retf
.moved:
    mov al, 1
    retf
.no:
    xor al, al
    retf

; ------------------------------------------------------------
h_key:
    cmp bh, KEY_ESC
    jne .k1
    mov bx, 0
    GUI API_SOUND
    GUI API_EXIT
    xor al, al
    retf
.k1:
    cmp bl, 'r'
    je .restart
    cmp bl, 'R'
    je .restart
    cmp bl, 'p'
    je .pause
    cmp bl, 'P'
    je .pause
    cmp byte [over], 0
    jne .no
    cmp byte [paused], 0
    jne .no
    cmp bh, KEY_LEFT
    jne .kr
    dec word [px]
    call collide
    jnc .yes
    inc word [px]
    jmp .no
.kr:
    cmp bh, KEY_RIGHT
    jne .ku
    inc word [px]
    call collide
    jnc .yes
    dec word [px]
    jmp .no
.ku:
    cmp bh, KEY_UP
    je .rotate
    cmp bh, KEY_ENTER
    je .rotate
    cmp bh, KEY_DOWN
    jne .ks
    inc word [py]
    call collide
    jnc .yes
    dec word [py]
    call lock_piece
    jmp .yes
.ks:
    cmp bh, KEY_SPACE
    jne .no
.hard:
    inc word [py]
    call collide
    jc .hlock
    jmp .hard
.hlock:
    dec word [py]
    call lock_piece
    mov byte [dropc], 0
    jmp .yes
.rotate:
    mov al, [rot]
    inc al
    and al, 3
    mov [rot], al
    call collide
    jnc .yes
    ; wall kicks: try -1, +1, -2, +2
    mov ax, [px]
    mov [pxs], ax
    dec word [px]
    call collide
    jnc .yes
    mov ax, [pxs]
    inc ax
    mov [px], ax
    call collide
    jnc .yes
    mov ax, [pxs]
    sub ax, 2
    mov [px], ax
    call collide
    jnc .yes
    mov ax, [pxs]
    add ax, 2
    mov [px], ax
    call collide
    jnc .yes
    mov ax, [pxs]
    mov [px], ax
    mov al, [rot]
    dec al
    and al, 3
    mov [rot], al
    jmp .no
.pause:
    cmp byte [over], 0
    jne .no
    xor byte [paused], 1
    jmp .yes
.restart:
    call start_game
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

    ; board frame
    mov al, 8
    mov bx, BXL-1
    mov cx, BYT-1
    mov dx, COLS*CELL+2
    mov si, ROWS*CELL+2
    GUI API_FILL
    mov al, 0
    mov bx, BXL
    mov cx, BYT
    mov dx, COLS*CELL
    mov si, ROWS*CELL
    GUI API_FILL

    ; locked cells
    mov word [yy], 0
.yl:
    cmp word [yy], ROWS
    jae .piece
    mov word [xx], 0
.xl:
    cmp word [xx], COLS
    jae .xn
    mov ax, [yy]
    mov bx, COLS
    mul bx
    add ax, [xx]
    mov di, ax
    movzx bx, byte [board+di]
    test bx, bx
    jz .xn2
    dec bx
    mov al, [colors+bx]
    mov bx, [xx]
    imul bx, bx, CELL
    add bx, BXL
    mov cx, [yy]
    imul cx, cx, CELL
    add cx, BYT
    mov dx, CELL-1
    mov si, CELL-1
    GUI API_FILL
.xn2:
    inc word [xx]
    jmp .xl
.xn:
    inc word [yy]
    jmp .yl

.piece:
    call draw_piece

    ; ---- HUD ----
    mov si, s_score
    mov bx, 92
    mov cx, 6
    mov dl, 8
    GUI API_STR
    mov al, 15
    mov bx, 92
    mov cx, 16
    mov dx, [score]
    GUI API_NUM

    mov si, s_lines
    mov bx, 92
    mov cx, 32
    mov dl, 8
    GUI API_STR
    mov al, 15
    mov bx, 92
    mov cx, 42
    mov dx, [lines]
    GUI API_NUM

    mov si, s_level
    mov bx, 92
    mov cx, 58
    mov dl, 8
    GUI API_STR
    mov al, 15
    mov bx, 92
    mov cx, 68
    xor dx, dx
    mov dl, [level]
    GUI API_NUM

    mov si, s_next
    mov bx, 92
    mov cx, 84
    mov dl, 8
    GUI API_STR
    call draw_next

    ; hint
    mov si, s_hint
    mov bx, 2
    mov cx, 146
    mov dl, 8
    GUI API_STR

    ; overlays
    cmp byte [over], 0
    je .pp
    mov al, 1
    mov bx, 10
    mov cx, 58
    mov dx, 96
    mov si, 20
    GUI API_FILL
    mov si, s_over
    mov bx, 22
    mov cx, 60
    mov dl, 14
    GUI API_STR
    mov si, s_new
    mov bx, 10
    mov cx, 68
    mov dl, 15
    GUI API_STR
    jmp .done
.pp:
    cmp byte [paused], 0
    je .done
    mov al, 1
    mov bx, 16
    mov cx, 60
    mov dx, 48
    mov si, 14
    GUI API_FILL
    mov si, s_pause
    mov bx, 20
    mov cx, 62
    mov dl, 14
    GUI API_STR
.done:
    xor al, al
    retf

; draw the falling piece
draw_piece:
    cmp byte [over], 0
    jne .r
    movzx si, byte [piece]
    shl si, 4
    movzx ax, byte [rot]
    shl ax, 2
    add si, ax
    add si, shapes
    mov [sbase], si

    mov word [srow], 0
.row:
    mov bx, [srow]
    mov si, [sbase]
    mov al, [si+bx]
    mov [mask], al
    mov word [scol], 0
.col:
    mov bx, [scol]
    mov al, [mask]
    and al, [bitmask+bx]
    jz .next
    mov ax, [py]
    add ax, [srow]
    cmp ax, 0
    jl .next
    mov cx, ax
    mov ax, [px]
    add ax, bx
    mov bx, ax
    imul bx, bx, CELL
    add bx, BXL
    imul cx, cx, CELL
    add cx, BYT
    movzx di, byte [piece]
    mov al, [colors+di]
    mov dx, CELL-1
    mov si, CELL-1
    GUI API_FILL
.next:
    inc word [scol]
    cmp word [scol], 4
    jb .col
    inc word [srow]
    cmp word [srow], 4
    jb .row
.r:
    ret

; draw the next piece in its 4x4 box
draw_next:
    movzx si, byte [nextp]
    shl si, 4                   ; rotation 0 is the first group
    add si, shapes
    mov [sbase], si
    mov word [srow], 0
.row:
    mov bx, [srow]
    mov si, [sbase]
    mov al, [si+bx]
    mov [mask], al
    mov word [scol], 0
.col:
    mov bx, [scol]
    mov al, [mask]
    and al, [bitmask+bx]
    jz .next
    mov bx, [scol]
    imul bx, bx, CELL
    add bx, 100
    mov cx, [srow]
    imul cx, cx, CELL
    add cx, 94
    movzx di, byte [nextp]
    mov al, [colors+di]
    mov dx, CELL-1
    mov si, CELL-1
    GUI API_FILL
.next:
    inc word [scol]
    cmp word [scol], 4
    jb .col
    inc word [srow]
    cmp word [srow], 4
    jb .row
    ret

; ------------------------------------------------------------
board   times BSZ db 0
piece   db 0
nextp   db 0
rot     db 0
px      dw 3
py      dw 0
over    db 0
paused  db 0
level   db 1
lines   dw 0
score   dw 0
score2  dw 0
dropc   db 0
snd     dw 0

srow    dw 0
scol    dw 0
mask    db 0
tx      dw 0
ty      dw 0
pxs     dw 0
xx      dw 0
yy      dw 0
crow    dw 0
sbase   dw 0

bitmask db 8,4,2,1
colors  db 3,14,13,10,12,9,6

s_score db "SCORE", 0
s_lines db "LINES", 0
s_level db "LEVEL", 0
s_next  db "NEXT", 0
s_hint  db "ARROWS ROT SPACE P", 0
s_over  db "GAME OVER", 0
s_new   db "R = NEW GAME", 0
s_pause db "PAUSED", 0

; pieces: I O T S Z J L, four rotations each, 4 rows, bit 8 = left
shapes:
    ; I
    db 0x0,0xF,0x0,0x0
    db 0x2,0x2,0x2,0x2
    db 0x0,0x0,0xF,0x0
    db 0x4,0x4,0x4,0x4
    ; O
    db 0x6,0x6,0x0,0x0
    db 0x6,0x6,0x0,0x0
    db 0x6,0x6,0x0,0x0
    db 0x6,0x6,0x0,0x0
    ; T
    db 0x4,0xE,0x0,0x0
    db 0x4,0x6,0x4,0x0
    db 0x0,0xE,0x4,0x0
    db 0x4,0xC,0x4,0x0
    ; S
    db 0x6,0xC,0x0,0x0
    db 0x4,0x6,0x2,0x0
    db 0x0,0x6,0xC,0x0
    db 0x8,0xC,0x4,0x0
    ; Z
    db 0xC,0x6,0x0,0x0
    db 0x4,0xC,0x8,0x0
    db 0x0,0xC,0x6,0x0
    db 0x2,0x6,0x4,0x0
    ; J
    db 0x8,0xE,0x0,0x0
    db 0x6,0x4,0x4,0x0
    db 0x0,0xE,0x2,0x0
    db 0x4,0x4,0xC,0x0
    ; L
    db 0x2,0xE,0x0,0x0
    db 0x4,0x4,0x6,0x0
    db 0x0,0xE,0x8,0x0
    db 0xC,0x4,0x4,0x0
