#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/service-compat.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# UI Elements
CHECKMARK="✓"
CROSSMARK="✗"
ARROW="➤"

# Function to print section headers
print_header() {
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}${CYAN}   $1${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
}

print_status() {
    echo -e "${YELLOW}${ARROW} $1...${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECKMARK} $1${NC}"
}

print_error() {
    echo -e "${RED}${CROSSMARK} $1${NC}"
}

# Function to check if command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1"
        return 0
    else
        print_error "$2"
        return 1
    fi
}

# Clear screen and show welcome
clear
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}${CYAN}     PTERODACTYL WINGS INSTALLER     ${NC}${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

# ------------------------
# 1. Docker install
# ------------------------
print_header "INSTALLING DOCKER"
print_status "Installing Docker"
curl -sSL https://get.docker.com/ | CHANNEL=stable bash
check_success "Docker installed"

print_status "Starting Docker service"
service docker start > /dev/null 2>&1
check_success "Docker service started"

# ------------------------
# 2. Update GRUB
# ------------------------
print_header "UPDATING SYSTEM"
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    print_status "Updating GRUB"
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' $GRUB_FILE
    sudo update-grub > /dev/null 2>&1
    check_success "GRUB updated"
fi

# ------------------------
# 3. Wings install
# ------------------------
print_header "INSTALLING WINGS"
print_status "Creating directories"
sudo mkdir -p /etc/pterodactyl
check_success "Directories created"

print_status "Detecting architecture"
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then 
    ARCH="amd64"
else 
    ARCH="arm64"
fi

print_status "Downloading Wings"
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$ARCH" > /dev/null 2>&1
check_success "Wings downloaded"

print_status "Setting permissions"
sudo chmod u+x /usr/local/bin/wings
check_success "Permissions set"

# ------------------------
# 4. Wings service
# ------------------------
print_header "CONFIGURING SERVICE"
print_status "Creating service file"
WINGS_SERVICE_FILE="/etc/init.d/wings"
sudo tee $WINGS_SERVICE_FILE > /dev/null <<EOF
#!/bin/sh
DAEMON="/usr/local/bin/wings"
PIDFILE="/var/run/wings.pid"
LOGFILE="/var/log/wings.log"
case "\$1" in
    start) mkdir -p /var/run; cd /etc/pterodactyl || exit 1; nohup "\$DAEMON" >>"\$LOGFILE" 2>&1 & echo \$! > "\$PIDFILE" ;;
    stop) [ -f "\$PIDFILE" ] && kill "\$(cat "\$PIDFILE")" 2>/dev/null || true; rm -f "\$PIDFILE" ;;
    restart) "\$0" stop; "\$0" start ;;
    status) [ -f "\$PIDFILE" ] && kill -0 "\$(cat "\$PIDFILE")" 2>/dev/null ;;
    *) echo "Usage: \$0 {start|stop|restart|status}"; exit 2 ;;
esac
EOF
sudo chmod 0755 "$WINGS_SERVICE_FILE"
check_success "Service file created"

print_status "Starting service"
systemctl start wings > /dev/null 2>&1
check_success "Service started"

# ------------------------
# 5. SSL Certificate
# ------------------------
print_header "GENERATING SSL"
print_status "Creating certificate"
sudo mkdir -p /etc/certs/wing
cd /etc/certs/wing || exit
sudo openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
-subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" \
-keyout privkey.pem -out fullchain.pem > /dev/null 2>&1
check_success "SSL certificate generated"

# ------------------------
# 6. Helper command
# ------------------------
print_header "CREATING HELPER"
print_status "Creating wing command"
sudo tee /usr/local/bin/wing > /dev/null <<'EOF'
#!/bin/bash
echo ""
echo "Wings Helper Commands:"
echo "  start    : sudo service wings start"
echo "  stop     : sudo service wings stop"
echo "  status   : sudo service wings status"
echo "  restart  : sudo service wings restart"
echo "  logs     : sudo tail -f /var/log/wings.log"
echo ""
EOF

sudo chmod +x /usr/local/bin/wing
check_success "Helper created"

# ------------------------
# Complete
# ------------------------
print_header "COMPLETE"
echo -e "${GREEN}${CHECKMARK} Installation finished${NC}"
echo ""
echo -e "${CYAN}Start Wings:${NC}"
echo -e "  sudo service wings start"
echo ""
echo -e "${CYAN}Use helper:${NC}"
echo -e "  wing"
echo ""
