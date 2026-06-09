#!/bin/bash
# ============================================================
#  S-RAM  Swap Manager  v2
#  Author: Dnt3e
#  Platform: Ubuntu / Debian
# ============================================================

SWAPFILE="/swapfile"
SYSCTL_CONF="/etc/sysctl.conf"

# ── Colors ───────────────────────────────────────────────────
G="\e[32m"; Y="\e[33m"; R="\e[31m"; C="\e[36m"; W="\e[97m"
DIM="\e[2m"; BOLD="\e[1m"; NC="\e[0m"
LINE="${DIM}────────────────────────────────────────────────────────${NC}"

# ── Root check ───────────────────────────────────────────────
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${R}  Error: must be run as root.${NC}"
        exit 1
    fi
}

# ── Environment detection ─────────────────────────────────────
_is_server() {
    local dm
    for dm in gdm gdm3 sddm lightdm xdm lxdm nodm; do
        systemctl is-active --quiet "$dm" 2>/dev/null && return 1
    done
    pgrep -x "Xorg|Xwayland|sway|weston|kwin_wayland|mutter" >/dev/null 2>&1 && return 1
    return 0
}

# ── Banner status ─────────────────────────────────────────────
_show_status() {
    local swap_total swap_used swappiness vfs swap_label env_label

    swap_total=$(free -m | awk '/Swap/{print $2}')
    swap_used=$(free -m  | awk '/Swap/{print $3}')
    swappiness=$(cat /proc/sys/vm/swappiness         2>/dev/null || echo "?")
    vfs=$(cat        /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo "?")

    if [ "${swap_total:-0}" -gt 0 ] 2>/dev/null; then
        swap_label="${G}Active${NC}  ${DIM}(${swap_total}MB total, ${swap_used}MB used)${NC}"
    else
        swap_label="${R}None${NC}"
    fi

    if _is_server; then
        env_label="${C}Server${NC}"
    else
        env_label="${Y}Desktop${NC}"
    fi

    echo -e "  ${W}Swap          :${NC} ${swap_label}"
    echo -e "  ${W}Swappiness    :${NC} ${DIM}${swappiness}${NC}  ${W}vfs_cache_pressure:${NC} ${DIM}${vfs}${NC}"
    echo -e "  ${W}Environment   :${NC} ${env_label}"
}

# ── Banner ───────────────────────────────────────────────────
banner() {
    clear
    echo -e "${G}"
    echo "   ███████╗    ██████╗  █████╗ ███╗   ███╗"
    echo "   ██╔════╝    ██╔══██╗██╔══██╗████╗ ████║"
    echo "   ███████╗    ██████╔╝███████║██╔████╔██║"
    echo "   ╚════██║    ██╔══██╗██╔══██║██║╚██╔╝██║"
    echo "   ███████║    ██║  ██║██║  ██║██║ ╚═╝ ██║"
    echo "   ╚══════╝    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}${W}S-RAM Swap Manager${NC}  ${DIM}v2${NC}"
    echo -e "  ${DIM}Author: Dnt3e${NC}"
    echo -e "${LINE}"
    _show_status
    echo -e "${LINE}"
}

# ── Recommended size ──────────────────────────────────────────
_recommended_size() {
    local ram
    ram=$(free -m | awk '/Mem/{print $2}')
    if   [ "$ram" -lt 2048 ]; then echo $(( ram * 2 ))
    elif [ "$ram" -lt 8192 ]; then echo "$ram"
    else                           echo $(( ram / 2 ))
    fi
}

# ── Apply sysctl settings ─────────────────────────────────────
_apply_sysctl() {
    local swappiness=$1 vfs=$2

    sysctl -qw vm.swappiness="$swappiness"
    sysctl -qw vm.vfs_cache_pressure="$vfs"

    if grep -q "vm.swappiness" "$SYSCTL_CONF" 2>/dev/null; then
        sed -i "s/vm.swappiness=.*/vm.swappiness=${swappiness}/" "$SYSCTL_CONF"
    else
        echo "vm.swappiness=${swappiness}" >> "$SYSCTL_CONF"
    fi

    if grep -q "vm.vfs_cache_pressure" "$SYSCTL_CONF" 2>/dev/null; then
        sed -i "s/vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=${vfs}/" "$SYSCTL_CONF"
    else
        echo "vm.vfs_cache_pressure=${vfs}" >> "$SYSCTL_CONF"
    fi
}

# ── Create swap ───────────────────────────────────────────────
create_swap() {
    banner
    echo -e "${BOLD}${C}  ➕ Create Swap Space${NC}"
    echo -e "${LINE}"

    local existing
    existing=$(free -m | awk '/Swap/{print $2}')
    if [ "${existing:-0}" -gt 0 ] 2>/dev/null; then
        echo -e "  ${Y}[WARN] Swap already active (${existing}MB). This will replace it.${NC}"
        echo -e "${LINE}"
        read -p "  Continue? [y/N]: " ch
        [ "${ch,,}" != "y" ] && return
        echo -e "${LINE}"
    fi

    local ram recommended
    ram=$(free -m | awk '/Mem/{print $2}')
    recommended=$(_recommended_size)

    echo -e "  ${W}Total RAM   :${NC} ${DIM}${ram}MB${NC}"
    echo -e "  ${W}Recommended :${NC} ${G}${recommended}MB${NC}"
    echo -e "${LINE}"

    local size
    while true; do
        read -p "  Swap size in MB (0 = cancel): " size
        if   [ "${size:-0}" -eq 0 ] 2>/dev/null; then return
        elif ! [[ "$size" =~ ^[0-9]+$ ]] || [ "$size" -le 0 ]; then
            echo -e "${R}  Invalid size.${NC}"
        else
            break
        fi
    done

    echo -e "${LINE}"

    if [ -f "$SWAPFILE" ]; then
        echo -e "  ${DIM}Removing existing swap file...${NC}"
        swapoff "$SWAPFILE" 2>/dev/null
        rm -f "$SWAPFILE"
    fi

    echo -e "  ${DIM}Allocating ${size}MB...${NC}"
    if fallocate -l "${size}M" "$SWAPFILE" 2>/dev/null; then
        echo -e "  ${G}[OK] Allocated with fallocate.${NC}"
    else
        echo -e "  ${Y}[WARN] fallocate unavailable, using dd...${NC}"
        if ! dd if=/dev/zero of="$SWAPFILE" bs=1M count="$size" status=none; then
            echo -e "  ${R}[ERR] Failed to create swap file.${NC}"
            read -p "  Press Enter..."; return 1
        fi
    fi

    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE" >/dev/null
    swapon "$SWAPFILE"

    if ! grep -q "$SWAPFILE" /etc/fstab 2>/dev/null; then
        echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
        echo -e "  ${G}[OK] Added to /etc/fstab.${NC}"
    fi

    _run_optimize silent
    echo -e "  ${G}[OK] Swap created and active.${NC}"
    read -p "  Press Enter..."
}

# ── Optimize logic ────────────────────────────────────────────
_run_optimize() {
    local mode="${1:-}"
    local swappiness vfs env_name

    if _is_server; then
        swappiness=10; vfs=50; env_name="Server"
    else
        swappiness=30; vfs=100; env_name="Desktop"
    fi

    _apply_sysctl "$swappiness" "$vfs"

    [ "$mode" == "silent" ] && return

    echo -e "  ${G}[OK] Environment detected: ${env_name}${NC}"
    echo -e "${LINE}"
    echo -e "  ${W}vm.swappiness          :${NC} ${G}${swappiness}${NC}"
    echo -e "  ${W}vm.vfs_cache_pressure  :${NC} ${G}${vfs}${NC}"
}

# ── Optimize menu ─────────────────────────────────────────────
optimize_swap() {
    banner
    echo -e "${BOLD}${C}  ⚡ Optimize Swap Settings${NC}"
    echo -e "${LINE}"
    _run_optimize
    read -p "  Press Enter..."
}

# ── Show status ───────────────────────────────────────────────
show_status() {
    banner
    echo -e "${BOLD}${C}  📊 Detailed Status${NC}"
    echo -e "${LINE}"
    free -h
    echo -e "${LINE}"
    local sw_out
    sw_out=$(swapon --show 2>/dev/null)
    if [ -n "$sw_out" ]; then
        echo -e "  ${W}Active Swap:${NC}"
        echo "$sw_out" | awk 'NR==1{printf "  %-14s %-6s %-6s %-6s %-6s\n",$1,$2,$3,$4,$5; next}
                                    {printf "  %-14s %-6s %-6s %-6s %-6s\n",$1,$2,$3,$4,$5}'
    else
        echo -e "  ${DIM}No active swap.${NC}"
    fi
    echo -e "${LINE}"
    echo -e "  ${W}vm.swappiness          :${NC} $(cat /proc/sys/vm/swappiness)"
    echo -e "  ${W}vm.vfs_cache_pressure  :${NC} $(cat /proc/sys/vm/vfs_cache_pressure)"
    read -p "  Press Enter..."
}

# ── Remove & restore ──────────────────────────────────────────
remove_swap() {
    banner
    echo -e "${BOLD}${R}  🗑️  Remove Swap & Restore Defaults${NC}"
    echo -e "${LINE}"
    echo -e "  ${Y}This will:${NC}"
    echo -e "  ${DIM}  • Disable and delete the swap file${NC}"
    echo -e "  ${DIM}  • Remove the entry from /etc/fstab${NC}"
    echo -e "  ${DIM}  • Reset swappiness and vfs_cache_pressure to kernel defaults${NC}"
    echo -e "${LINE}"
    read -p "  Confirm? [y/N]: " confirm
    [ "${confirm,,}" != "y" ] && return
    echo -e "${LINE}"

    local active
    active=$(swapon --show=NAME --noheadings 2>/dev/null | head -1)

    if [ -n "$active" ]; then
        swapoff "$active" 2>/dev/null \
            && echo -e "  ${G}[OK] Swap disabled: ${active}${NC}" \
            || echo -e "  ${Y}[WARN] swapoff returned non-zero.${NC}"
    else
        echo -e "  ${DIM}No active swap to disable.${NC}"
    fi

    if [ -f "$SWAPFILE" ]; then
        rm -f "$SWAPFILE" \
            && echo -e "  ${G}[OK] Swap file removed.${NC}" \
            || echo -e "  ${R}[ERR] Failed to remove swap file.${NC}"
    fi

    if grep -q "$SWAPFILE" /etc/fstab 2>/dev/null; then
        sed -i "\|${SWAPFILE}|d" /etc/fstab \
            && echo -e "  ${G}[OK] fstab entry removed.${NC}"
    fi

    sysctl -qw vm.swappiness=60
    sysctl -qw vm.vfs_cache_pressure=100
    sed -i '/vm.swappiness/d'         "$SYSCTL_CONF" 2>/dev/null
    sed -i '/vm.vfs_cache_pressure/d' "$SYSCTL_CONF" 2>/dev/null
    echo -e "  ${G}[OK] sysctl restored to defaults (swappiness=60, vfs_cache_pressure=100).${NC}"

    read -p "  Press Enter..."
}

# ── Main menu ─────────────────────────────────────────────────
menu() {
    while true; do
        banner
        echo -e "${BOLD}${W}  Main Menu${NC}"
        echo -e "${LINE}"
        echo -e "   ${W}1)${NC} ➕  Create Swap"
        echo -e "   ${W}2)${NC} ⚡  Optimize Settings  ${DIM}(auto server/desktop)${NC}"
        echo -e "   ${W}3)${NC} 📊  Detailed Status"
        echo -e "${LINE}"
        echo -e "   ${W}4)${NC} 🗑️   Remove Swap & Restore Defaults"
        echo -e "${LINE}"
        echo -e "   ${W}0)${NC} 🚪  Exit"
        echo -e "${LINE}"
        read -p "  Select: " opt
        case $opt in
            1) create_swap   ;;
            2) optimize_swap ;;
            3) show_status   ;;
            4) remove_swap   ;;
            0) echo -e "${G}  Goodbye.${NC}"; exit 0 ;;
            *) echo -e "${R}  Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ── Entry point ───────────────────────────────────────────────
check_root
menu
