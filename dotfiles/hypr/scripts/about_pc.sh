#!/bin/bash
# About PC — Show system information in a floating terminal

# Gather system info
DISTRO=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME=" | cut -d'"' -f2)
KERNEL=$(uname -r)
UPTIME=$(uptime -p | sed 's/up //')
CPU=$(lscpu 2>/dev/null | grep "Model name:" | sed 's/Model name:\s*//')
GPU=$(lspci 2>/dev/null | grep -i 'vga\|3d' | sed 's/.*: //')
RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
HOST=$(hostnamectl hostname 2>/dev/null || hostname)
DE="Hyprland $(hyprctl version -j 2>/dev/null | jq -r '.tag' 2>/dev/null || echo '')"
SHELL_NAME=$(basename "$SHELL")
PKGS=$(pacman -Q 2>/dev/null | wc -l)
RESOLUTION=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0] | "\(.width)x\(.height) @ \(.refreshRate)Hz"' 2>/dev/null)

# Arch Linux ASCII logo (colored)
LOGO=(
  "\033[1;36m      /\ \\033[0m"
  "\033[1;36m     /  \ \\033[0m"
  "\033[1;36m    /    \ \\033[0m"
  "\033[1;36m   /      \ \\033[0m"
  "\033[1;36m  /   ,,   \ \\033[0m"
  "\033[1;36m /   |  |  -\ \\033[0m"
  "\033[1;36m/_-''    ''-_\ \\033[0m"
)

INFO=(
  "\033[1;37mOS          \033[0;36m$DISTRO\033[0m"
  "\033[1;37mKernel      \033[0;36m$KERNEL\033[0m"
  "\033[1;37mResolution  \033[0;36m$RESOLUTION\033[0m"
  "\033[1;37mDE          \033[0;36m$DE\033[0m"
  "\033[1;37mShell       \033[0;36m$SHELL_NAME\033[0m"
  "\033[1;37mPackages    \033[0;36m$PKGS (pacman)\033[0m"
  "\033[1;37mCPU         \033[0;36m$CPU\033[0m"
  "\033[1;37mGPU         \033[0;36m$GPU\033[0m"
  "\033[1;37mRAM         \033[0;36m$RAM_USED / $RAM_TOTAL\033[0m"
  "\033[1;37mDisk (/)    \033[0;36m$DISK_USED / $DISK_TOTAL\033[0m"
  "\033[1;37mUptime      \033[0;36m$UPTIME\033[0m"
  "\033[1;37mHost        \033[0;36m$HOST\033[0m"
)

echo ""
echo -e "\033[1;34m   ╭───────────────────────────────────╮\033[0m"
echo -e "\033[1;34m   │\033[1;36m         ⚡ About This PC          \033[1;34m│\033[0m"
echo -e "\033[1;34m   ╰───────────────────────────────────╯\033[0m"
echo ""

max_lines=${#INFO[@]}
logo_lines=${#LOGO[@]}

for ((i = 0; i < max_lines; i++)); do
  logo_part="${LOGO[i]}"
  info_part="${INFO[i]}"

  printf "   %-20b %b\n" "$logo_part" "$info_part"
done

echo ""
echo -e "\033[1;34m   ─────────────────────────────────────\033[0m"
echo ""

# keep the window open
read -r -p " Press Enter to close..."
