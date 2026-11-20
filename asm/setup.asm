; ============================================================
;  SETUP.BIN - SpheraOS first-time setup wizard
;  Flat binary, started by the kernel on first boot (when
;  /SYS/SYSTEM.CFG does not exist). Talks to the kernel through
;  int 0x80 (see the API list in kernel.asm).
;  Build: nasm -f bin setup.asm -o SETUP.BIN
; ============================================================
BITS 16
ORG 0

start:
    cld
    mov si, m_banner
    call puts

    ; ---- user account ----
    mov si, m_user
    call puts
    mov di, uname
    mov cx, 15
    xor al, al
    call gets
    cmp byte [uname], 0
    je .nouser
    mov si, m_pass
    call puts
    mov di, upass
    mov cx, 15
    mov al, 1
    call gets
    mov si, m_admin
    call puts
    call getkey
    or al, 0x20
    mov [uadmin], al
    call nl
.nouser:
    mov si, m_host
    call puts
    mov di, hname
    mov cx, 15
    xor al, al
    call gets
    cmp byte [hname], 0
    jne .hok
    mov si, d_host
    mov di, hname
    call copy
.hok:

    ; ---- terminal colour ----
    mov si, m_colors
    call puts
    call getkey
    sub al, '1'
    cmp al, 6
    jb .cok
    xor al, al
.cok:
    xor ah, ah
    mov bx, ax
    mov al, [color_tab+bx]
    mov [color], al
    mov ah, 7
    int 0x80                     ; apply the colour now
    call nl
    mov si, m_colset
    call puts

    ; ---- prompt style ----
    mov si, m_prompts
    call puts
    call getkey
    sub al, '1'
    cmp al, 5
    jb .pok
    xor al, al
.pok:
    cmp al, 4
    je .custom
    xor ah, ah
    shl ax, 1
    mov bx, ax
    mov si, [prompt_tab+bx]
    mov di, pfmt
    call copy
    jmp .pdone
.custom:
    call nl
    mov si, m_custom
    call puts
    mov di, pfmt
    mov cx, 58
    xor al, al
    call gets
    cmp byte [pfmt], 0
    jne .pdone
    mov si, p1
    mov di, pfmt
    call copy
.pdone:
    call nl

    ; ---- write the configuration ----
    mov si, m_mkdir
    mov ah, 8
    int 0x80                     ; mkdir /SYS (SI = path)
    mov si, m_writing
    call puts

    mov di, outbuf               ; SYSTEM.CFG
    mov si, c_head
    call append
    mov si, hname
    call append
    mov si, c_color
    call append
    mov al, [color]
    call hexbyte
    mov si, c_prompt
    call append
    mov si, pfmt
    call append
    mov al, 10
    stosb
    mov cx, di
    sub cx, outbuf
    mov si, m_syscfg
    mov di, outbuf
    mov ah, 5
    int 0x80

    mov di, outbuf               ; USERS.CFG
    mov si, u_head
    call append
    mov si, u_root
    call append
    cmp byte [uname], 0
    je .wu
    mov si, uname
    call append
    mov al, ':'
    stosb
    mov si, upass
    call append
    mov si, u_role_user
    cmp byte [uadmin], 'n'
    je .rl
    mov si, u_role_admin
.rl:
    call append
.wu:
    mov cx, di
    sub cx, outbuf
    mov si, m_userscfg
    mov di, outbuf
    mov ah, 5
    int 0x80

    mov si, m_done
    call puts
    call getkey
    call nl
    retf

; ---------------- helpers ----------------
puts:                            ; SI asciiz
    mov ah, 1
    int 0x80
    ret

nl:
    mov al, 10
    mov ah, 2
    int 0x80
    ret

getkey:                          ; -> AL
    mov ah, 4
    int 0x80
    ret

gets:                            ; ES:DI buffer, CX max, AL=1 hidden
    mov ah, 3
    int 0x80
    ret

copy:                            ; SI -> DI asciiz
    lodsb
    stosb
    test al, al
    jnz copy
    ret

append:                          ; SI asciiz appended at DI (no NUL)
    lodsb
    test al, al
    jz .d
    stosb
    jmp append
.d:
    ret

hexbyte:                         ; AL -> two hex digits at DI
    push ax
    shr al, 4
    call .nib
    pop ax
    and al, 0x0F
.nib:
    add al, '0'
    cmp al, '9'
    jbe .o
    add al, 7
.o:
    stosb
    ret

; ---------------- data ----------------
m_banner  db 10, "=== SpheraOS first-time setup ===", 10
          db "root already exists (password: root, change it in /SYS/USERS.CFG).", 10, 10, 0
m_user    db "Create your own account - login name (empty = skip): ", 0
m_pass    db "Password: ", 0
m_admin   db 10, "Administrator rights (can edit /SYS)? [Y/n] ", 0
m_host    db "Computer name [sphera]: ", 0
d_host    db "sphera", 0
m_colors  db 10, "Terminal colour:", 10
          db "  1) white on black   2) green on black   3) yellow on black", 10
          db "  4) cyan on black    5) white on blue    6) black on grey", 10
          db "Choice [1]: ", 0
m_colset  db "Colour applied.", 10, 0
m_prompts db 10, "Prompt style:", 10
          db "  1) user@host A:/path$     2) A:/path>       3) [user] /path$", 10
          db "  4) host:/path$            5) custom", 10
          db "Choice [1]: ", 0
m_custom  db "Format (%u user, %h host, %d drive, %p path, %$ $ or #): ", 0
m_mkdir   db "/SYS", 0
m_writing db "Writing /SYS/SYSTEM.CFG and /SYS/USERS.CFG ...", 10, 0
m_syscfg  db "/SYS/SYSTEM.CFG", 0
m_userscfg db "/SYS/USERS.CFG", 0
m_done    db "Done. Press any key to continue to the login prompt.", 0
c_head    db "# SpheraOS system configuration (edit as root)", 10, "host=", 0
c_color   db 10, "color=", 0
c_prompt  db 10, "prompt=", 0
u_head    db "# user:password:role:run-allowed-globs:hidden-globs", 10
          db "# role = admin or user. Globs are upper-case absolute paths,", 10
          db "# e.g.  bob:1234:user:/GAMES/*,/APPS/*:/SECRET/*,/PRIVATE", 10, 0
u_root    db "root:root:admin::", 10, 0
u_role_admin db ":admin::", 10, 0
u_role_user  db ":user::", 10, 0
color_tab db 0x07, 0x0A, 0x0E, 0x0B, 0x1F, 0x70
prompt_tab dw p1, p2, p3, p4
p1        db "%u@%h %d:%p%$ ", 0
p2        db "%d:%p> ", 0
p3        db "[%u] %p%$ ", 0
p4        db "%h:%p%$ ", 0

absolute 0x1800
uname     resb 20
upass     resb 20
hname     resb 20
pfmt      resb 64
color     resb 1
uadmin    resb 1
outbuf    resb 700
