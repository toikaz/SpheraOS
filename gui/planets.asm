; ============================================================
;  planets.asm - orbiting planets for SpheraOS GUI
;  nasm -f bin -I gui/ planets.asm -o asm/planets.app
;  Space = pause, +/- = speed, R = restart, Esc = quit.
; ============================================================
BITS 16
ORG 0
%include "sdk.inc"

APP_HEADER "Planets", 220, 160

H      equ 160
CX0    equ 110
CY0    equ 76
NP     equ 5

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
    call reset_all
    xor al, al
    retf

reset_all:
    mov word [pangles+0], 0
    mov word [pangles+2], 40*256
    mov word [pangles+4], 15*256
    mov word [pangles+6], 33*256
    mov word [pangles+8], 52*256
    mov byte [paused], 0
    mov byte [spd], 1
    ret

h_tick:
    cmp byte [paused], 0
    jne .no
    mov byte [pi], 0
.l:
    cmp byte [pi], NP
    jae .done
    movzx bx, byte [pi]
    mov al, [pspeed+bx]
    xor ah, ah
    mov dl, [spd]
    xor dh, dh
    mul dx
    mov si, bx
    shl si, 1
    add ax, [pangles+si]
    cmp ax, 60*256
    jb .ok
    sub ax, 60*256
.ok:
    mov [pangles+si], ax
    inc byte [pi]
    jmp .l
.done:
    mov al, 1
    retf
.no:
    xor al, al
    retf

h_key:
    cmp bh, KEY_ESC
    jne .k1
    GUI API_EXIT
    xor al, al
    retf
.k1:
    cmp bh, KEY_SPACE
    jne .k2
    xor byte [paused], 1
    jmp .yes
.k2:
    cmp bl, '+'
    je .fast
    cmp bl, '='
    je .fast
    cmp bl, '-'
    je .slow
    cmp bl, 'r'
    je .restart
    cmp bl, 'R'
    jne .no
.restart:
    call reset_all
    jmp .yes
.fast:
    cmp byte [spd], 4
    jae .no
    inc byte [spd]
    jmp .yes
.slow:
    cmp byte [spd], 1
    jbe .no
    dec byte [spd]
    jmp .yes
.yes:
    mov al, 1
    retf
.no:
    xor al, al
    retf

; ------------------------------------------------------------
; point: AL = angle index (0..59), BX = radius
;        -> DX = x, CX = y
; ------------------------------------------------------------
point:
    mov [rad], bx
    mov [ag], al
    movzx di, al
    mov ax, di
    add ax, 15                  ; cos = sin + 90 deg
    cmp ax, 60
    jb .a
    sub ax, 60
.a:
    movzx di, al
    shl di, 1
    mov ax, [sintab+di]
    imul word [rad]
    sar ax, 8
    add ax, CX0
    mov [ptx], ax

    movzx si, byte [ag]
    shl si, 1
    mov ax, [sintab+si]
    imul word [rad]
    sar ax, 8
    mov dx, CY0
    sub dx, ax
    mov cx, dx
    mov dx, [ptx]
    ret

plot:                           ; AL = colour, DX/CX = point
    mov bx, dx
    GUI API_PIX
    ret

; ------------------------------------------------------------
h_draw:
    mov al, 0
    GUI API_CLEAR

    ; ---- orbits ----
    mov byte [pi], 0
.orbit:
    cmp byte [pi], NP
    jae .sun
    movzx bx, byte [pi]
    movzx di, byte [pi]
    shl di, 1
    mov bx, [prad+di]
    mov [rad], bx
    mov byte [ti], 0
.ol:
    mov al, [ti]
    mov bx, [rad]
    call point
    mov al, 8
    call plot
    inc byte [ti]
    cmp byte [ti], 60
    jb .ol
    inc byte [pi]
    jmp .orbit

.sun:
    mov al, 14
    mov bx, CX0-7
    mov cx, CY0-7
    mov dx, 14
    mov si, 14
    GUI API_FILL
    mov al, 15
    mov bx, CX0-3
    mov cx, CY0-3
    mov dx, 6
    mov si, 6
    GUI API_FILL

    ; ---- planets with a short trail ----
    mov byte [pi], 0
.pl:
    cmp byte [pi], NP
    jae .title
    movzx di, byte [pi]
    mov si, di
    shl si, 1
    mov ax, [pangles+si]
    shr ax, 8
    mov [aidx], ax

    mov byte [tj], 1
.trail:
    cmp byte [tj], 4
    jae .body
    mov ax, [aidx]
    sub ax, [tj]
    jns .t1
    add ax, 60
.t1:
    movzx di, byte [pi]
    shl di, 1
    mov bx, [prad+di]
    call point
    mov al, 8
    call plot
    inc byte [tj]
    jmp .trail

.body:
    mov al, [aidx]
    movzx di, byte [pi]
    shl di, 1
    mov bx, [prad+di]
    call point
    mov [pxx], dx
    mov [pyy], cx

    movzx di, byte [pi]
    movzx si, byte [psize+di]
    mov ax, si
    shr ax, 1
    mov bx, [pxx]
    sub bx, ax
    mov cx, [pyy]
    sub cx, ax
    mov dx, si
    mov al, [pcolor+di]
    GUI API_FILL

    inc byte [pi]
    jmp .pl

.title:
    mov si, s_title
    mov bx, 56
    mov cx, 2
    mov dl, 10
    GUI API_STR
    mov si, s_hint
    mov bx, 4
    mov cx, 150
    mov dl, 8
    GUI API_STR
    xor al, al
    retf

; ------------------------------------------------------------
pangles dw 0,0,0,0,0
prad    dw 26,38,50,62,74
pspeed  db 24,16,11,8,5
psize   db 2,3,3,4,5
pcolor  db 7,14,9,12,6

pi      db 0
ti      db 0
tj      db 0
spd     db 1
paused  db 0
rad     dw 0
ag      db 0
ptx     dw 0
aidx    dw 0
pxx     dw 0
pyy     dw 0

s_title db "SPHERA SYSTEM", 0
s_hint  db "SPACE  +/-  R", 0

sintab:
    dw 0,27,53,79,104,128,150,171,190,207,222,234,243,250,255,256
    dw 255,250,243,234,222,207,190,171,150,128,104,79,53,27
    dw 0,-27,-53,-79,-104,-128,-150,-171,-190,-207,-222,-234
    dw -243,-250,-255,-256,-255,-250,-243,-234,-222,-207,-190,-171
    dw -150,-128,-104,-79,-53,-27
