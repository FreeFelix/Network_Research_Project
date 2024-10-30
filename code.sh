#!/bin/bash


LOG_FILE="custom_log_file.log"  # Define a custom log file

# Function to write logs with timestamps
function LOG() {
    local MESSAGE="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $MESSAGE" | tee -a "$LOG_FILE"
}

# Function to install required applications, skipping if they are already installed.
function INSTALL() {
    tools=("sshpass" "openssh-server" "openssh-client" "nmap" "whois" "tor" "perl" "geoip-bin")

    for app in "${tools[@]}"; do
        if dpkg -s "$app" | grep -q "install ok installed"; then
            LOG "$app is already installed."
        else
            LOG "Installing $app..."
            sudo apt-get install -y "$app"
        fi
    done
}


INSTALL

# Function to check if the network connection is anonymous
function ANONYMOUS() {
    LOG "Checking anonymity..."

    IP=$(curl -s https://icanhazip.com)
    CNTRY=$(whois "$IP" | grep -i 'country' | head -n 1 | awk '{print $2}')

    if [ "$CNTRY" == "RW" ]; then
        LOG "You are not anonymous! Exiting..."
        exit 1
    else
        SPOOFED_COUNTRY=$(geoiplookup "$IP" | awk '{print $4}' | sed 's/,//g')
        LOG "You are anonymous - Spoofed country: $SPOOFED_COUNTRY"
    fi
}


ANONYMOUS

# Function to collect details from a remote server and perform port scanning
function REMOTE_DETAILS() {
    LOG "Starting remote details collection..."

    read -p "[*] Enter the remote server's IP or hostname: " SERVER_IP
    read -p "[*] Enter the remote USERNAME: " USERNAME
    read -s -p "[*] Enter the remote SSH password: " PASSWORD
    echo ""  # Print a blank line for formatting

    LOG_AUDIT
    LOG "Fetching details from the remote server..."

    # Store the output of the SSH session locally and log relevant information
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USERNAME@$SERVER_IP << 'EOF' >> remote_output.log 
    
        echo "Remote Server IP: $(hostname -I)"
        echo "Remote Server Uptime:"
        uptime
        REMOTE_IP=$(curl -s https://icanhazip.com)
        echo "Remote Public IP: $REMOTE_IP"
        whois $REMOTE_IP >> whois.lst
        REMOTE_CNTRY=$(geoiplookup $REMOTE_IP | awk '{print $4}' | sed 's/,//g')
        echo "Remote Server Country: $REMOTE_CNTRY"

        if ! command -v nmap &> /dev/null; then
            echo "[!] nmap is not installed on the remote server."
        else
            echo "Scanning open ports on the remote server IP: $(hostname -I)..."
            nmap -Pn -F $(hostname -I) >> nmap_file.lst
        fi
EOF

    LOG "SSH session completed. Fetching remote files..."

    # Download files from the remote server
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no $USERNAME@$SERVER_IP:whois.lst . \
        && LOG "Downloaded whois.lst successfully."
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no $USERNAME@$SERVER_IP:nmap_file.lst . \
        && LOG "Downloaded nmap_file.lst successfully."

    LOG "Remote details collection completed. See remote_output.log for details."
}

# Function to log audit data
function LOG_AUDIT() {
    LOG "Appending log entry in the audit log file."
    echo "$(date) - Audit log entry" >> "$LOG_FILE"
}

# Call the function to execute the script
REMOTE_DETAILS
