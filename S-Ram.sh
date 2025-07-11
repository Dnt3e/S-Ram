#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Function to create swap
create_swap() {
    clear
    echo -e "${YELLOW}=== Create Swap Space ===${NC}"
    
    # Check existing swap
    existing_swap=$(free -m | awk '/Swap/{print $2}')
    if [ "$existing_swap" -gt 0 ]; then
        echo -e "${YELLOW}Warning: Swap already exists (${existing_swap}MB)${NC}"
        read -p "Do you want to continue and create additional swap? (y/n) " choice
        if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
            return
        fi
    fi
    
    # Get available RAM
    total_ram=$(free -m | awk '/Mem/{print $2}')
    echo -e "${GREEN}Your system has ${total_ram}MB of RAM${NC}"
    
    # Calculate recommended swap
    if [ "$total_ram" -lt 2048 ]; then
        recommended=$((total_ram * 2))
    elif [ "$total_ram" -lt 8192 ]; then
        recommended=$total_ram
    else
        recommended=$((total_ram / 2))
    fi
    
    echo -e "Recommended swap size: ${GREEN}${recommended}MB${NC}"
    
    # Get user input
    while true; do
        read -p "Enter swap size in MB (or 0 to cancel): " swap_size
        if [ "$swap_size" -eq 0 ]; then
            return
        elif [ "$swap_size" -lt 0 ]; then
            echo -e "${RED}Error: Swap size cannot be negative${NC}"
        else
            break
        fi
    done
    
    # Create swap file
    echo -e "${YELLOW}Creating swap file of ${swap_size}MB...${NC}"
    if fallocate -l "${swap_size}M" /swapfile 2>/dev/null; then
        echo -e "${GREEN}Swap file created successfully${NC}"
    else
        echo -e "${RED}fallocate failed, using dd instead...${NC}"
        dd if=/dev/zero of=/swapfile bs=1M count=$swap_size
    fi
    
    # Set permissions
    chmod 600 /swapfile
    
    # Format as swap
    mkswap /swapfile
    
    # Enable swap
    swapon /swapfile
    
    # Add to fstab
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
        echo -e "${GREEN}Swap added to /etc/fstab${NC}"
    fi
    
    # Optimize swappiness
    optimize_swap
    
    echo -e "${GREEN}Swap created and activated successfully!${NC}"
    show_status
}

# Function to optimize swap settings
optimize_swap() {
    echo -e "${YELLOW}Optimizing swap settings...${NC}"
    
    # Determine if this is a server or desktop
    is_server=0
    if [[ $(ps -p 1 -o comm=) == "systemd" ]] && [[ ! $(loginctl) == *"sessions"* ]]; then
        is_server=1
    fi
    
    if [ "$is_server" -eq 1 ]; then
        # Server settings
        swappiness=10
        vfs_cache_pressure=50
        echo -e "${GREEN}Detected server environment${NC}"
    else
        # Desktop settings
        swappiness=30
        vfs_cache_pressure=100
        echo -e "${GREEN}Detected desktop environment${NC}"
    fi
    
    # Apply settings
    sysctl vm.swappiness=$swappiness
    sysctl vm.vfs_cache_pressure=$vfs_cache_pressure
    
    # Make settings persistent
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=$swappiness" >> /etc/sysctl.conf
    else
        sed -i "s/vm.swappiness=.*/vm.swappiness=$swappiness/" /etc/sysctl.conf
    fi
    
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=$vfs_cache_pressure" >> /etc/sysctl.conf
    else
        sed -i "s/vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=$vfs_cache_pressure/" /etc/sysctl.conf
    fi
    
    echo -e "${GREEN}Swap settings optimized:${NC}"
    echo -e "swappiness = ${swappiness}"
    echo -e "vfs_cache_pressure = ${vfs_cache_pressure}"
}

# Function to remove swap
remove_swap() {
    clear
    echo -e "${YELLOW}=== Remove Swap Space ===${NC}"
    
    # Check if swap exists
    if [ ! -f /swapfile ] && ! swapon --show | grep -q "/swapfile"; then
        echo -e "${RED}Error: No swap file found${NC}"
        return
    fi
    
    # Disable swap
    swapoff /swapfile 2>/dev/null
    
    # Remove from fstab
    if grep -q "/swapfile" /etc/fstab; then
        sed -i '/\/swapfile/d' /etc/fstab
        echo -e "${GREEN}Swap removed from /etc/fstab${NC}"
    fi
    
    # Remove swap file
    if [ -f /swapfile ]; then
        rm -f /swapfile
        echo -e "${GREEN}Swap file removed${NC}"
    fi
    
    # Reset swappiness to default
    sysctl vm.swappiness=60
    sed -i '/vm.swappiness/d' /etc/sysctl.conf
    
    # Reset vfs_cache_pressure to default
    sysctl vm.vfs_cache_pressure=100
    sed -i '/vm.vfs_cache_pressure/d' /etc/sysctl.conf
    
    echo -e "${GREEN}Swap space completely removed and system restored to default settings${NC}"
    show_status
}

# Function to show swap status
show_status() {
    echo -e "\n${YELLOW}=== Current Swap Status ===${NC}"
    free -h
    echo -e "\n${YELLOW}Swap details:${NC}"
    swapon --show
    echo -e "\n${YELLOW}Swappiness:${NC} $(cat /proc/sys/vm/swappiness)"
    echo -e "${YELLOW}vfs_cache_pressure:${NC} $(cat /proc/sys/vm/vfs_cache_pressure)"
}

# Main menu
main_menu() {
    clear
    echo -e "${GREEN}"
    echo "   _____ ____    __  __ ___ "
    echo "  / ___// __ \  / / / //   |"
    echo "  \__ \/ / / / / / / // /| |"
    echo " ___/ / /_/ / / /_/ // ___ |"
    echo "/____/\___\_\ \____//_/  |_|"
    echo -e "${NC}"
    echo -e "${YELLOW}Advanced Swap Management Script${NC}"
    echo -e "${YELLOW}--------------------------------${NC}"
    echo -e "1. Create/Add Swap Space"
    echo -e "2. Remove Swap Space"
    echo -e "3. Show Current Swap Status"
    echo -e "4. Optimize Swap Settings"
    echo -e "5. Exit"
    echo -e "${YELLOW}--------------------------------${NC}"
    
    read -p "Enter your choice [1-5]: " choice
    case $choice in
        1) create_swap ;;
        2) remove_swap ;;
        3) show_status ;;
        4) optimize_swap ;;
        5) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
    
    read -p "Press [Enter] to return to main menu..."
    main_menu
}

# Start the script
main_menu
