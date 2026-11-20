; ============================================================
;  breakout.asm - brick breaker for SpheraOS GUI
;  nasm -f bin -I gui/ breakout.asm -o asm/breakout.app
;  Left/Right = paddle, Space = pause, R = new game, Esc = quit.
; ============================================================
BITS 16
ORG 0
%include "sdk.inc"

APP_HEADER "Breakout", 240, 168

W       equ 240
H       equ 168
BALL    equ 4
PADW    equ 40
PADH    equ 5
PADY    equ H-18
BCOLS   equ 10
BROWS   equ 5
BX0     equ 10
BY0     equ 26
BW      equ 22
BRH      equ 9

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
    call new_game
    xor al, al
    retf

new_game:
    mov bx, 0
    GUI API_SOUND
    mov word [snd], 0
    mov di, bricks
    mov cx, BCOLS*BROWS
    mov al, 1
    rep stosb
    mov word [score], 0
    mov byte [lives], 3
    mov byte [over], 0
    mov byte [paused], 0
    mov word [padx], 100
    call reset_ball
    ret

reset_ball:
    mov word [balx], 116
    mov word [baly], 100
    mov word [balvx], 2
    mov word [balvy], -2
    ret

; ------------------------------------------------------------
h_tick:
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
    call move_ball
    mov al, 1
    retf
.no:
    xor al, al
    retf

beep:                           ; BX = tone
    GUI API_SOUND
    mov word [snd], 3
    ret

move_ball:
    mov ax, [balx]
    mov [prevx], ax
    mov ax, [baly]
    mov [prevy], ax

    mov ax, [balx]
    add ax, [balvx]
    mov [balx], ax
    mov ax, [baly]
    add ax, [balvy]
    mov [baly], ax

    ; walls
    cmp word [balx], 0
    jge .right
    mov word [balx], 0
    neg word [balvx]
.right:
    mov ax, W-BALL
    cmp [balx], ax
    jle .top
    mov [balx], ax
    neg word [balvx]
.top:
    cmp word [baly], 0
    jge .bottom
    mov word [baly], 0
    neg word [balvy]
.bottom:
    cmp word [baly], H
    jl .paddle
    ; lost a life
    dec byte [lives]
    mov bx, 1200
    call beep
    cmp byte [lives], 0
    jne .reset
    mov byte [over], 1
    mov bx, 0
    GUI API_SOUND
    ret
.reset:
    mov word [padx], 100
    call reset_ball
    ret

.paddle:
    ; only when falling
    cmp word [balvy], 0
    jl .bricks
    mov ax, [baly]
    add ax, BALL
    cmp ax, PADY
    jb .bricks
    cmp word [baly], PADY+PADH
    ja .bricks
    mov ax, [balx]
    add ax, BALL
    cmp ax, [padx]
    jb .bricks
    mov ax, [padx]
    add ax, PADW
    cmp [balx], ax
    ja .bricks
    ; hit the paddle
    mov ax, PADY-BALL
    mov [baly], ax
    mov word [balvy], -2
    mov ax, [balx]
    add ax, BALL/2
    mov cx, [padx]
    add cx, PADW/2
    sub ax, cx
    mov cx, 6
    cwd
    idiv cx
    cmp ax, 3
    jle .v1
    mov ax, 3
.v1:
    cmp ax, -3
    jge .v2
    mov ax, -3
.v2:
    test ax, ax
    jnz .v3
    mov ax, 1
.v3:
    mov [balvx], ax
    mov bx, 3000
    call beep

.bricks:
    ; check the ball centre against the brick grid
    mov ax, [balx]
    add ax, BALL/2
    mov [bcx], ax
    mov ax, [baly]
    add ax, BALL/2
    mov [bcy], ax
    cmp word [bcx], BX0
    jb .done
    cmp word [bcy], BY0
    jb .done
    mov ax, [bcx]
    sub ax, BX0
    xor dx, dx
    mov bx, BW
    div bx                      ; AX=col, DX=rem
    cmp ax, BCOLS
    jae .done
    mov [bcol], ax
    mov ax, [bcy]
    sub ax, BY0
    xor dx, dx
    mov bx, BRH
    div bx
    cmp ax, BROWS
    jae .done
    mov [brow], ax
    ; index = row*BCOLS + col
    mov bx, BCOLS
    mul bx
    add ax, [bcol]
    mov di, ax
    cmp byte [bricks+di], 0
    je .done
    mov byte [bricks+di], 0
    add word [score], 10
    mov bx, 2500
    call beep
    ; bounce direction from where the ball came
    mov ax, [bcol]
    imul ax, ax, BW
    add ax, BX0
    mov cx, ax
    add cx, BW
    mov ax, [prevx]
    add ax, BALL/2
    mov cx, [bcol]
    imul cx, cx, BW
    add cx, BX0
    cmp ax, cx
    jb .vx
    ; previous centre was inside the brick column: vertical hit
    neg word [balvy]
    ret
.vx:
    neg word [balvx]
.done:
    ret

; ------------------------------------------------------------
h_key:
    cmp BH, KEY_ESC
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
    cmp BH, KEY_SPACE
    jne .left
    cmp byte [over], 0
    jne .restart
    xor byte [paused], 1
    jmp .yes
.left:
    cmp byte [over], 0
    jne .no
    cmp byte [paused], 0
    jne .no
    cmp BH, KEY_LEFT
    jne .right
    mov ax, [padx]
    sub ax, 8
    jns .l1
    xor ax, ax
.l1:
    mov [padx], ax
    jmp .yes
.right:
    cmp BH, KEY_RIGHT
    jne .no
    mov ax, [padx]
    add ax, 8
    cmp ax, W-PADW
    jbe .r1
    mov ax, W-PADW
.r1:
    mov [padx], ax
    jmp .yes
.restart:
    call new_game
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

    ; bricks
    mov word [bi], 0
.bl:
    cmp word [bi], BCOLS*BROWS
    jae .hud
    mov bx, [bi]
    cmp byte [bricks+bx], 0
    je .bn
    mov ax, bx
    xor dx, dx
    mov cx, BCOLS
    div cx                      ; AX=row, DX=col
    mov [brow2], ax
    mov [bcol2], dx
    mov bx, ax
    mov al, [bcolr+bx]
    mov bx, [bcol2]
    imul bx, bx, BW
    add bx, BX0
    mov cx, [brow2]
    imul cx, cx, BRH
    add cx, BY0
    mov dx, BW-1
    mov si, 6
    GUI API_FILL
.bn:
    inc word [bi]
    jmp .bl

.hud:
    mov si, s_score
    mov bx, 8
    mov cx, 6
    mov dl, 8
    GUI API_STR
    mov al, 15
    mov bx, 56
    mov cx, 6
    mov dx, [score]
    GUI API_NUM

    mov si, s_lives
    mov bx, 150
    mov cx, 6
    mov dl, 8
    GUI API_STR
    mov al, 15
    mov bx, 198
    mov cx, 6
    xor dx, dx
    mov dl, [lives]
    GUI API_NUM

    ; paddle
    mov al, 15
    mov bx, [padx]
    mov cx, PADY
    mov dx, PADW
    mov si, PADH
    GUI API_FILL

    ; ball
    mov al, 15
    mov bx, [balx]
    mov cx, [baly]
    mov dx, BALL
    mov si, BALL
    GUI API_FILL

    ; hint
    mov si, s_hint
    mov bx, 8
    mov cx, H-10
    mov dl, 8
    GUI API_STR

    cmp byte [over], 0
    je .pp
    mov al, 1
    mov bx, 56
    mov cx, 70
    mov dx, 128
    mov si, 24
    GUI API_FILL
    mov si, s_win
    mov bx, 84
    mov cx, 74
    mov dl, 14
    GUI API_STR
    mov si, s_new
    mov bx, 72
    mov cx, 84
    mov dl, 15
    GUI API_STR
    jmp .done
.pp:
    cmp byte [paused], 0
    je .done
    mov si, s_pause
    mov bx, 96
    mov cx, 74
    mov dl, 14
    GUI API_STR
.done:
    xor al, al
    retf

; ------------------------------------------------------------
bricks  times BCOLS*BROWS db 1
balx    dw 0
baly    dw 0
balvx   dw 0
balvy   dw 0
prevx   dw 0
prevy   dw 0
padx    dw 0
score   dw 0
lives   db 3
over    db 0
paused  db 0
snd     dw 0

bi      dw 0
bcx     dw 0
bcy     dw 0
bcol    dw 0
brow    dw 0
bcol2   dw 0
brow2   dw 0

bcolr   db 4,12,14,10,9
s_score db "SCORE", 0
s_lives db "LIVES", 0
s_hint  db "LT/RT  SPACE  R NEW", 0
s_win   db "GAME OVER", 0
s_new   db "R = NEW GAME", 0
s_pause db "PAUSED", 0
