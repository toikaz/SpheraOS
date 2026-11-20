#!/bin/bash
# SpheraOS build script
#
# Sources:
#   boot.asm, kernel.asm      -> asm/boot.bin, asm/kernel.bin
#   *.asm in the root         -> asm/<name>.bin
#   asm/*.asm                 -> asm/<name>.bin       (standalone programs / tools)
#   gui/*.asm                 -> asm/<name>.app       (GUI programs, built with sdk.inc)
#   examples/*                -> copied as they are
#
# Layout of floppy.img (FAT12, 1.44 MB, label SpheraOS):
#   /              KERNEL.BIN  SETUP.BIN  GUI.BIN  AUTOEXEC.PLB
#   /APPS          every *.APP (GUI programs)
#   /GAMES         SNAKE.BIN  DOOMISH.BIN  CHESS.BIN  MATRIX.BIN
#   /SYS           SETCOLOR.BIN  GUIMOUSE.BIN  other asm/*.bin tools
#   /EXAMPLES      other *.PLB scripts
#   /DEV           SDK.INC
#
# To move a program to another folder, edit the lists below.
#
# Needs: nasm, mtools (mcopy, mmd, mdir), dosfstools (mkfs.fat), dd, qemu
set -euo pipefail

# Always work from the directory containing this script
cd "$(dirname "$0")"

ASM_DIR=asm
GUI_DIR=gui
EX_DIR=examples
IMG=floppy.img

# ---- placement rules (names without extension, lowercase) ----
ROOT_BINS="kernel setup gui"       # the kernel and GUI look for these in the root
ROOT_PLB="autoexec"                # AUTOEXEC.PLB runs at boot, so it lives in the root
GAME_BINS="snake doomish chess matrix"
SYS_BINS="setcolor guimouse"       # any other asm/*.bin without a rule goes to /SYS

in_list() {  # in_list NAME LIST...
    local needle=$1; shift
    local x
    for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
    return 1
}

# Echoes the target folder for a file ("" = root, "SKIP" = do not copy).
# Argument: file name (any case)
dest_for() {
    local name
    name=$(echo "$1" | tr 'A-Z' 'a-z')
    local base=${name%.*} ext=${name##*.}
    case "$ext" in
        app) echo "APPS" ;;
        bin)
            if   in_list "$base" $ROOT_BINS; then echo ""
            elif in_list "$base" $GAME_BINS; then echo "GAMES"
            else echo "SYS"
            fi ;;
        plb)
            if in_list "$base" $ROOT_PLB; then echo ""
            else echo "EXAMPLES"; fi ;;
        inc) echo "DEV" ;;
        *)   echo "SKIP" ;;
    esac
}

# FAT names are at most 8 characters + 3 for the extension; returns the upper-case name
dos_name() {
    local base=${1%.*} ext=${1##*.}
    if [ ${#base} -gt 8 ] || [ ${#ext} -gt 3 ]; then
        echo "[!] skipped (name is not 8.3): $1" >&2
        return 1
    fi
    echo "$1" | tr 'a-z' 'A-Z'
}

mkdir -p "$ASM_DIR"

# ---- 1. Build phase ----
echo "[*] boot.asm   -> $ASM_DIR/boot.bin"
nasm -f bin boot.asm -o "$ASM_DIR/boot.bin"

echo "[*] kernel.asm -> $ASM_DIR/kernel.bin"
nasm -f bin kernel.asm -o "$ASM_DIR/kernel.bin"

for src in *.asm; do                               # other programs in the root
    [ -f "$src" ] || continue
    base=$(basename "$src" .asm)
    case "$base" in boot|kernel) continue ;; esac
    echo "[*] $src -> $ASM_DIR/$base.bin"
    nasm -f bin "$src" -o "$ASM_DIR/$base.bin"
done

for src in "$ASM_DIR"/*.asm; do                    # standalone programs and tools
    [ -f "$src" ] || continue
    base=$(basename "$src" .asm)
    echo "[*] $src -> $ASM_DIR/$base.bin"
    nasm -f bin "$src" -o "$ASM_DIR/$base.bin"
done

if [ -d "$GUI_DIR" ]; then                         # GUI programs
    for src in "$GUI_DIR"/*.asm; do
        [ -f "$src" ] || continue
        base=$(basename "$src" .asm)
        echo "[*] $src -> $ASM_DIR/$base.app"
        nasm -f bin -I "$GUI_DIR/" -I . "$src" -o "$ASM_DIR/$base.app"
    done
fi

# ---- 2. Create the image ----
echo "[*] Creating $IMG (FAT12, 1.44 MB, label: SpheraOS)"
dd if=/dev/zero of="$IMG" bs=512 count=2880 2>/dev/null
mkfs.fat -F 12 -n "SPHERAOS" "$IMG" >/dev/null
dd if="$ASM_DIR/boot.bin" of="$IMG" conv=notrunc 2>/dev/null

# ---- 3. Put the files into their folders ----
# run an mtools command: no keyboard input, and a 30 s limit so a hang is reported
MT() {
    timeout 30 "$@" </dev/null
    local rc=$?
    if [ $rc -eq 124 ]; then
        echo "[!] timed out: $*" >&2
        echo "    (is floppy.img open in another program? close it and try again)" >&2
        exit 1
    fi
    return $rc
}

# make sure folder /NAME exists on the image
ensure_dir() {
    MT mdir -i "$IMG" "::/$1" >/dev/null 2>&1 || MT mmd -i "$IMG" "::/$1" >/dev/null 2>&1 || true
}

# put SOURCE FOLDER NAME : copies SOURCE to FOLDER/NAME (FOLDER empty = root)
put() {
    local src=$1 folder=$2 name=$3
    if [ -n "$folder" ]; then
        ensure_dir "$folder"
        MT mcopy -o -i "$IMG" "$src" "::/$folder/$name" || { echo "[!] mcopy failed: $name" >&2; exit 1; }
        printf '[+] %-16s -> /%s/%s\n' "$(basename "$src")" "$folder" "$name"
    else
        MT mcopy -o -i "$IMG" "$src" "::$name" || { echo "[!] mcopy failed: $name" >&2; exit 1; }
        printf '[+] %-16s -> /%s\n' "$(basename "$src")" "$name"
    fi
}

echo "[*] Filling $IMG"
[ -f "$ASM_DIR/kernel.bin" ] || { echo "[!] kernel.bin missing"; exit 1; }
put "$ASM_DIR/kernel.bin" "" "KERNEL.BIN"

for f in "$ASM_DIR"/*.bin; do                      # asm/*.bin
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in boot.bin|kernel.bin) continue ;; esac
    name=$(dos_name "$base") || continue
    folder=$(dest_for "$base")
    [ "$folder" = "SKIP" ] && continue
    put "$f" "$folder" "$name"
done

for f in "$ASM_DIR"/*.app; do                      # asm/*.app -> /APPS
    [ -f "$f" ] || continue
    base=$(basename "$f")
    name=$(dos_name "$base") || continue
    put "$f" "$(dest_for "$base")" "$name"
done

if [ -d "$EX_DIR" ]; then                          # examples/*
    for f in "$EX_DIR"/*; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        name=$(dos_name "$base") || continue
        folder=$(dest_for "$base")
        [ "$folder" = "SKIP" ] || [ "$folder" = "DEV" ] && continue   # sdk.inc is copied from the root below
        put "$f" "$folder" "$name"
    done
fi

if [ -f sdk.inc ]; then                            # SDK header for programmers
    put "sdk.inc" "DEV" "SDK.INC"
fi

echo
echo "=== Image contents ==="
MT mdir -s -i "$IMG" :: || true
for d in APPS GAMES SYS EXAMPLES DEV; do
    if MT mdir -i "$IMG" "::/$d" >/dev/null 2>&1; then
        echo "--- /$d"
        MT mdir -i "$IMG" "::/$d" | grep -v '^ *Volume\|^ *Directory' || true
    fi
done

# ---- 4. Launch ----
echo
echo "[*] Starting QEMU..."
qemu-system-i386 -drive format=raw,file="$IMG",if=floppy -boot a
