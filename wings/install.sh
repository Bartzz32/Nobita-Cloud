#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Use service(8) when systemd is unavailable.
source "$SCRIPT_DIR/../lib/service-compat.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

CHECKMARK="✓"
CROSSMARK="✗"
ARROW="➤"
BULLET="●"

STEP=0
TOTAL_STEPS=7
START_TIME=$(date +%s)

print_banner() {
    clear
    echo -e "${BLUE}${NC}"
    echo -e "${BLUE}${NC}                                                            ${BLUE}${NC}"
    echo -e "${BLUE}${NC}  ${CYAN}:::       ::: ::::::::::: ::::    ::::  ::::::::   ::::::::  ${BLUE} ${NC}"
    echo -e "${BLUE}${NC}  ${CYAN}:+:       :+:     :+:     :+:+:   :+: :+:    :+: :+:    :+: ${BLUE}  ${NC}"
    echo -e "${BLUE}${NC}  ${CYAN}+:+       +:+     +:+     :+:+:+  +:+ +:+        +:+        ${BLUE}  ${NC}"
    echo -e "${BLUE}${NC}  ${CYAN}+#+  +:+  +#+     +#+     +#+ +:+ +#+ :#:        +#++:++#++ ${BLUE}  ${NC}"
    echo -e "${BLUE}${NC}  ${CYAN}+#+ +#+#+ +#+     +#+     +#+  +#+#+# +#+   +#+#        +#+ ${BLUE}  ${NC}"
    echo -e "${BLUE}${NC}  ${CYAN} #+#+# #+#+#      #+#     #+#   #+#+# #+#    #+# #+#    #+# ${BLUE}  ${NC}"
    echo -e "${BLUE}${NC}  ${CYAN}  ###   ###   ########### ###    ####  ########   ########  ${BLUE}  ${NC}"
    echo -e "${BLUE}${NC}  ${DIM}Pterodactyl Wings Installer - v1.0${NC}                     ${BLUE}${NC}"
    echo -e "${BLUE}${NC}"
    echo ""
}

print_step() {
    STEP=$((STEP + 1))
    local title=$1
    local icon=$2
    echo ""
    echo -e "  ${WHITE}${icon}  Step ${STEP}/${TOTAL_STEPS}: ${title}${NC}"
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_header() {
    local title=$1
    local width=52
    local pad=$(( (width - ${#title}) / 2 ))
    printf "  ${MAGENTA}╔"
    printf '═%.0s' $(seq 1 $width)
    printf "╗${NC}\n"
    printf "  ${MAGENTA}║${NC}%*s${CYAN}%s${NC}%*s${MAGENTA}║${NC}\n" $pad "" "$title" $((width - pad - ${#title})) ""
    printf "  ${MAGENTA}╚"
    printf '═%.0s' $(seq 1 $width)
    printf "╝${NC}\n"
}

print_status() {
    echo -e "  ${YELLOW}${BULLET}${NC} ${DIM}$1...${NC}"
}

print_ok() {
    echo -e "  ${GREEN}${CHECKMARK}${NC} $1"
}

print_fail() {
    echo -e "  ${RED}${CROSSMARK}${NC} $1"
}

print_info() {
    echo -e "  ${CYAN}${ARROW}${NC} $1"
}

check_success() {
    local code=$1
    local msg=$2
    shift 2
    if [ "$code" -eq 0 ]; then
        print_ok "$msg"
        return 0
    else
        print_fail "$msg"
        [ $# -gt 0 ] && echo -e "  ${RED}  $*${NC}"
        return 1
    fi
}

# Simple spinner for long-running tasks
spinner() {
    local pid=$1
    local msg=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${YELLOW}%s${NC} ${DIM}%s...${NC}" "${spin:$i:1}" "$msg"
        i=$(( (i + 1) % ${#spin} ))
        sleep 0.1
    done
    printf "\r  ${GREEN}${CHECKMARK}${NC} ${DIM}%s${NC}  \n" "$msg"
}

confirm() {
    local prompt=$1
    local default=${2:-y}
    local yn
    if [ "$default" = "y" ]; then
        prompt="$prompt [${GREEN}Y${NC}/${RED}n${NC}]"
    else
        prompt="$prompt [${GREEN}y${NC}/${RED}N${NC}]"
    fi
    echo -e "  ${CYAN}?${NC} $prompt "
    read -r yn
    yn=${yn:-$default}
    case "$yn" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

elapsed() {
    local now
    now=$(date +%s)
    local diff=$((now - START_TIME))
    local mins=$((diff / 60))
    local secs=$((diff % 60))
    printf "%02d:%02d" "$mins" "$secs"
}

section_start() {
    SECTION_START=$(date +%s)
}

section_end() {
    local now
    now=$(date +%s)
    local diff=$((now - SECTION_START))
    local mins=$((diff / 60))
    local secs=$((diff % 60))
    printf "${DIM}(%02d:%02d)${NC}" "$mins" "$secs"
}

show_progress() {
    local current=$1
    local total=$2
    local pct=$(( current * 100 / total ))
    local bar_width=40
    local filled=$(( pct * bar_width / 100 ))
    local empty=$(( bar_width - filled ))
    printf "\r  ${DIM}[${NC}"
    printf "${GREEN}%*s${NC}" "$filled" "" | tr ' ' '▓'
    printf "${DIM}%*s${NC}" "$empty" "" | tr ' ' '░'
    printf "${DIM}] ${NC}%3d%%" "$pct"
    [ "$current" -eq "$total" ] && echo ""
}

# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
print_banner

echo -e "  ${DIM}System Information:${NC}"
echo -e "  ${DIM}  OS    : $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "unknown")${NC}"
echo -e "  ${DIM}  Kernel: $(uname -r)${NC}"
echo -e "  ${DIM}  Arch  : $(uname -m)${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    print_fail "This script must be run as root"
    exit 1
fi

confirm "Begin Pterodactyl Wings installation?" || {
    print_info "Installation cancelled by user"
    exit 0
}
echo ""

# ─────────────────────────────────────────────
# STEP 1: Docker
# ─────────────────────────────────────────────
print_step "Docker Engine" "🐳"

if command -v docker &>/dev/null; then
    print_ok "Docker already installed ($(docker --version 2>/dev/null))"
else
    print_status "Downloading & installing Docker"
    section_start
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash > /dev/null 2>&1 &
    spinner $! "Installing Docker"
    check_success $? "Docker installed" "$(section_end)"
fi

print_status "Ensuring Docker service is running"
service docker start > /dev/null 2>&1
check_success $? "Docker service ready"

# ─────────────────────────────────────────────
# STEP 2: GRUB
# ─────────────────────────────────────────────
print_step "Kernel Parameters" "⚙️"

GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    print_status "Configuring GRUB with swapaccount=1"
    section_start
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' "$GRUB_FILE"
    sudo update-grub > /dev/null 2>&1 || print_info "update-grub skipped (non-Debian system)"
    check_success $? "GRUB updated" "$(section_end)"
else
    print_info "GRUB config not found at $GRUB_FILE - skipping"
fi

# ─────────────────────────────────────────────
# STEP 3: Wings Binary
# ─────────────────────────────────────────────
print_step "Wings Binary" "📦"

sudo mkdir -p /etc/pterodactyl
check_success $? "Created /etc/pterodactyl"

print_status "Detecting system architecture"
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH="amd64"  ;;
    aarch64) ARCH="arm64"  ;;
    armv7l)  ARCH="arm32"  ;;
    *)       print_fail "Unsupported architecture: $ARCH"; exit 1 ;;
esac
print_ok "Architecture: $ARCH"

if [ -f /usr/local/bin/wings ]; then
    print_ok "Wings binary already present"
else
    print_status "Downloading Wings (linux_$ARCH)"
    section_start
    curl -L -o /usr/local/bin/wings \
        "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$ARCH" &
    spinner $! "Downloading Wings"
    check_success $? "Wings downloaded" "$(section_end)"
fi

print_status "Setting executable permissions"
sudo chmod u+x /usr/local/bin/wings
check_success $? "Permissions set"

WINGS_VERSION=$(/usr/local/bin/wings --version 2>/dev/null || echo "unknown")
print_info "Wings version: $WINGS_VERSION"

# ─────────────────────────────────────────────
# STEP 4: Systemd Service
# ─────────────────────────────────────────────
print_step "Service" "🔧"

WINGS_SERVICE_FILE="/etc/init.d/wings"
section_start

if [ -f "$WINGS_SERVICE_FILE" ]; then
    print_ok "Service file already exists"
else
        print_status "Creating wings init script"
        sudo tee "$WINGS_SERVICE_FILE" > /dev/null <<'EOF'
#!/bin/sh
DAEMON="/usr/local/bin/wings"
PIDFILE="/var/run/wings.pid"
LOGFILE="/var/log/wings.log"
case "$1" in
    start) mkdir -p /var/run; cd /etc/pterodactyl || exit 1; nohup "$DAEMON" >>"$LOGFILE" 2>&1 & echo $! > "$PIDFILE" ;;
    stop) [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null || true; rm -f "$PIDFILE" ;;
    restart) "$0" stop; "$0" start ;;
    status) [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null ;;
    *) echo "Usage: $0 {start|stop|restart|status}"; exit 2 ;;
esac
EOF
        sudo chmod 0755 "$WINGS_SERVICE_FILE"
    check_success $? "Service file created"
fi

print_status "Starting wings service"
systemctl start wings > /dev/null 2>&1
check_success $? "Service started" "$(section_end)"

sudo mkdir -p /etc/certs/wing
check_success $? "Certificate directory ready"
if [ -f /etc/certs/wing/fullchain.pem ] && [ -f /etc/certs/wing/privkey.pem ]; then
    print_ok "SSL certificates already exist"
else
    print_status "Generating self-signed certificate (3650 days)"
    sudo openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
        -subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
        -keyout /etc/certs/wing/privkey.pem -out /etc/certs/wing/fullchain.pem \
        > /dev/null 2>&1
    check_success $? "Certificate generated" "$(section_end)"
fi

CERT_INFO=$(sudo openssl x509 -in /etc/certs/wing/fullchain.pem -noout -subject -dates 2>/dev/null | tr '\n' '; ' | sed 's/; /\n  /g')
echo -e "  ${DIM}  $CERT_INFO${NC}"

CERT_INFO=$(sudo openssl x509 -in /etc/certs/wing/fullchain.pem -noout -subject -dates 2>/dev/null | tr '\n' '; ' | sed 's/; /\n  /g')
echo -e "  ${DIM}  $CERT_INFO${NC}"

# ─────────────────────────────────────────────
# STEP 6: Helper Command
# ─────────────────────────────────────────────
print_step "Helper Command" "🖥️"

print_status "Creating /usr/local/bin/wing helper"
sudo tee /usr/local/bin/wing > /dev/null <<'EOF'
#!/bin/bash
echo ""
echo "  Pterodactyl Wings Helper"
echo "  ────────────────────────"
echo "  start    sudo service wings start"
echo "  stop     sudo service wings stop"
echo "  restart  sudo service wings restart"
echo "  status   sudo service wings status"
echo "  logs     sudo tail -f /var/log/wings.log"
echo ""
EOF

sudo chmod +x /usr/local/bin/wing
check_success $? "Helper command installed"

# ─────────────────────────────────────────────
# STEP 7: Summary
# ─────────────────────────────────────────────
print_step "Installation Summary" "✅"

TOTAL_ELAPSED=$(elapsed)

echo ""
echo -e "  ${WHITE}┌─────────────────────────────────────────────────────────┐${NC}"
echo -e "  ${WHITE}│${NC}  ${GREEN}All steps completed successfully${NC}                         ${WHITE}│${NC}"
echo -e "  ${WHITE}├─────────────────────────────────────────────────────────┤${NC}"
printf "  ${WHITE}│${NC}  ${DIM}Duration${NC}          ${WHITE}%-37s${NC} ${WHITE}│${NC}\n" "$TOTAL_ELAPSED"
printf "  ${WHITE}│${NC}  ${DIM}Wings binary${NC}       ${WHITE}%-37s${NC} ${WHITE}│${NC}\n" "/usr/local/bin/wings"
printf "  ${WHITE}│${NC}  ${DIM}Config dir${NC}         ${WHITE}%-37s${NC} ${WHITE}│${NC}\n" "/etc/pterodactyl"
printf "  ${WHITE}│${NC}  ${DIM}SSL certs${NC}          ${WHITE}%-37s${NC} ${WHITE}│${NC}\n" "/etc/certs/wing"
printf "  ${WHITE}│${NC}  ${DIM}Service${NC}            ${WHITE}%-37s${NC} ${WHITE}│${NC}\n" "wings ($(service wings status >/dev/null 2>&1 && echo running || echo stopped))"
printf "  ${WHITE}│${NC}  ${DIM}Docker${NC}             ${WHITE}%-37s${NC} ${WHITE}│${NC}\n" "$(docker --version 2>/dev/null)"
echo -e "  ${WHITE}└─────────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "  ${CYAN}${ARROW}${NC}  Start Wings:  ${WHITE}sudo service wings start${NC}"
echo -e "  ${CYAN}${ARROW}${NC}  Helper:       ${WHITE}wing${NC}"
echo -e "  ${CYAN}${ARROW}${NC}  Logs:         ${WHITE}sudo tail -f /var/log/wings.log${NC}"
echo ""
