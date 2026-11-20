; ============================================================
;  timer.asm - countdown timer with a seven-segment display
;  nasm -f bin -I gui/ timer.asm -o asm/timer.app
;  Up/Down = +-1 minute, Left/Right = +-10 seconds,
;  Space/Enter = start/pause, R = reset, Esc = quit.
; ============================================================
BITS 16
ORG 0
%include "sdk.inc"

APP_HEADER "Timer", 200, 114

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
    mov word [setmin], 5
    mov word [setsec], 0
    call apply_set
    mov word [left], 300
    mov byte [running], 0
    mov byte [done], 0
    mov byte [frac], 0
    mov word [snd], 0
    mov bx, 0
    GUI API_SOUND
    xor al, al
    retf

; total = setmin*60 + setsec, left = total
apply_set:
    mov ax, [setmin]
    mov bx, 60
    mul bx
    add ax, [setsec]
    mov [total], ax
    mov [left], ax
    ret

h_tick:
    ; ---- alarm sound ----
    cmp word [snd], 0
    je .nosnd
    dec word [snd]
    test word [snd], 8
    jz .quiet
    mov bx, 2000
    GUI API_SOUND
    jmp .nosnd
.quiet:
    mov bx, 0
    GUI API_SOUND
.nosnd:
    cmp byte [running], 0
    je .r0
    inc byte [frac]
    cmp byte [frac], 18
    jb .r0
    mov byte [frac], 0
    cmp word [left], 0
    je .end
    dec word [left]
    cmp word [left], 0
    jne .redraw
.end:
    mov byte [running], 0
    mov byte [done], 1
    mov word [snd], 70
.redraw:
    mov al, 1
    retf
.r0:
    xor al, al
    retf

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
    je .reset
    cmp bl, 'R'
    je .reset
    cmp bh, KEY_SPACE
    je .toggle
    cmp bh, KEY_ENTER
    je .toggle
    ; setup keys only while stopped
    cmp byte [running], 0
    jne .no
    cmp byte [done], 0
    jne .no
    cmp bh, KEY_UP
    jne .kd
    cmp word [setmin], 99
    jae .no
    inc word [setmin]
    call apply_set
    jmp .yes
.kd:
    cmp bh, KEY_DOWN
    jne .kl
    cmp word [setmin], 0
    je .no
    dec word [setmin]
    call apply_set
    jmp .yes
.kl:
    cmp bh, KEY_LEFT
    jne .kr
    mov ax, [setsec]
    sub ax, 10
    jns .ls
    mov ax, 50
.ls:
    mov [setsec], ax
    call apply_set
    jmp .yes
.kr:
    cmp bh, KEY_RIGHT
    jne .no
    mov ax, [setsec]
    add ax, 10
    cmp ax, 60
    jb .rs
    xor ax, ax
.rs:
    mov [setsec], ax
    call apply_set
    jmp .yes
.toggle:
    cmp byte [done], 0
    je .t2
    call reset_timer
    jmp .yes
.t2:
    cmp byte [running], 0
    jne .stop
    cmp word [left], 0
    jne .start
    mov ax, [total]
    mov [left], ax
.start:
    mov byte [running], 1
    jmp .yes
.stop:
    mov byte [running], 0
    jmp .yes
.reset:
    call reset_timer
.yes:
    mov al, 1
    retf
.no:
    xor al, al
    retf

reset_timer:
    mov bx, 0
    GUI API_SOUND
    mov word [snd], 0
    mov byte [running], 0
    mov byte [done], 0
    mov byte [frac], 0
    call apply_set
    ret

; ------------------------------------------------------------
h_draw:
    mov al, 0
    GUI API_CLEAR

    ; status
    cmp byte [done], 0
    je .runst
    mov si, s_done
    mov bx, 76
    mov cx, 8
    mov dl, 12
    GUI API_STR
    jmp .digits
.runst:
    cmp byte [running], 0
    je .pause
    mov si, s_run
    mov bx, 76
    mov cx, 8
    mov dl, 10
    GUI API_STR
    jmp .digits
.pause:
    mov si, s_pause
    mov bx, 72
    mov cx, 8
    mov dl, 14
    GUI API_STR

.digits:
    mov ax, [left]
    xor dx, dx
    mov bx, 60
    div bx                      ; AX = minutes, DX = seconds
    mov [minv], ax
    mov [secv], dx

    mov al, [minv]
    xor ah, ah
    mov bl, 10
    div bl
    mov [d0], al
    mov [d1], ah
    mov al, [secv]
    xor ah, ah
    mov bl, 10
    div bl
    mov [d2], al
    mov [d3], ah

    mov al, [d0]
    mov bx, 24
    mov cx, 26
    mov dl, 10
    call digit
    mov al, [d1]
    mov bx, 44
    mov cx, 26
    mov dl, 10
    call digit
    ; colon
    mov al, 12
    mov bx, 64
    mov cx, 32
    mov dx, 4
    mov si, 4
    GUI API_FILL
    mov al, 12
    mov bx, 64
    mov cx, 46
    mov dx, 4
    mov si, 4
    GUI API_FILL
    mov al, [d2]
    mov bx, 72
    mov cx, 26
    mov dl, 10
    call digit
    mov al, [d3]
    mov bx, 92
    mov cx, 26
    mov dl, 10
    call digit

    ; progress bar
    mov al, 8
    mov bx, 20
    mov cx, 76
    mov dx, 160
    mov si, 10
    GUI API_FILL
    mov ax, [total]
    test ax, ax
    jz .hint
    mov bx, [left]
    mov cx, 160
    mul cx                      ; DX:AX = total*160
    mov cx, [total]
    div cx                      ; AX = filled width
    test ax, ax
    jz .hint
    mov dx, ax
    mov al, 10
    mov bx, 20
    mov cx, 78
    mov si, 6
    GUI API_FILL

.hint:
    mov si, s_hint
    mov bx, 8
    mov cx, 96
    mov dl, 8
    GUI API_STR
    xor al, al
    retf

; digit: AL = 0..9, BX = x, CX = y, DL = colour
; seven-segment cell: 18 wide, 32 high, 4 pixels thick
digit:
    mov [dg], al
    mov [dcol], dl
    mov [dxp], bx
    mov [dyp], cx
    movzx bx, al
    mov al, [segmask+bx]
    mov [dseg], al

    ; a (top)
    test byte [dseg], 0x01
    jz .b
    mov bx, [dxp]
    add bx, 3
    mov cx, [dyp]
    mov dx, 12
    mov si, 4
    call segdraw
.b:
    test byte [dseg], 0x02
    jz .c
    mov bx, [dxp]
    add bx, 14
    mov cx, [dyp]
    add cx, 3
    mov dx, 4
    mov si, 12
    call segdraw
.c:
    test byte [dseg], 0x04
    jz .d
    mov bx, [dxp]
    add bx, 14
    mov cx, [dyp]
    add cx, 17
    mov dx, 4
    mov si, 12
    call segdraw
.d:
    test byte [dseg], 0x08
    jz .e
    mov bx, [dxp]
    add bx, 3
    mov cx, [dyp]
    add cx, 28
    mov dx, 12
    mov si, 4
    call segdraw
.e:
    test byte [dseg], 0x10
    jz .f
    mov bx, [dxp]
    mov cx, [dyp]
    add cx, 17
    mov dx, 4
    mov si, 12
    call segdraw
.f:
    test byte [dseg], 0x20
    jz .g
    mov bx, [dxp]
    mov cx, [dyp]
    add cx, 3
    mov dx, 4
    mov si, 12
    call segdraw
.g:
    test byte [dseg], 0x40
    jz .done
    mov bx, [dxp]
    add bx, 3
    mov cx, [dyp]
    add cx, 14
    mov dx, 12
    mov si, 4
    call segdraw
.done:
    ret

segdraw:
    mov al, [dcol]
    GUI API_FILL
    ret

; ------------------------------------------------------------
setmin  dw 5
setsec  dw 0
total   dw 300
left    dw 300
running db 0
done    db 0
frac    db 0
snd     dw 0
minv    dw 0
secv    dw 0
d0      db 0
d1      db 0
d2      db 0
d3      db 0
dg      db 0
dcol    db 0
dseg    db 0
dxp     dw 0
dyp     dw 0

segmask db 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F

s_run   db "RUNNING", 0
s_pause db "PAUSED", 0
s_done  db "TIME UP", 0
s_hint  db "UP/DN min  LT/RT 10s  SPC go  R reset", 0
