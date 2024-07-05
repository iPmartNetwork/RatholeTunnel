#!/bin/bash

# Define a function to colorize text
colorize() {
    local color="$1"
    local text="$2"
    local style="${3:-normal}"
    
    # Define ANSI color codes
    local black="\033[30m"
    local red="\033[0;35m"
    local Purple="\033[0;35m"
    local green="\033[32m"
    local yellow="\033[33m"
    local blue="\033[34m"
    local magenta="\033[35m"
    local cyan="\033[36m"
    local white="\033[0;96m"
    local reset="\033[0m"
    local NC="\033[0m" # No Color
    
    # Define ANSI style codes
    local normal="\033[0m"
    local bold="\033[1m"
    local underline="\033[4m"
    # Select color code
    local color_code
    case $color in
        black) color_code=$black ;;
        red) color_code=$red ;;
        Purple) color_code=$Purple ;;
        green) color_code=$green ;;
        yellow) color_code=$yellow ;;
        blue) color_code=$blue ;;
        magenta) color_code=$magenta ;;
        cyan) color_code=$cyan ;;
        white) color_code=$white ;;
        *) color_code=$reset ;;  # Default case, no color
    esac
    # Select style code
    local style_code
    case $style in
        bold) style_code=$bold ;;
        underline) style_code=$underline ;;
        normal | *) style_code=$normal ;;  # Default case, normal text
    esac

    # Print the colored and styled text
    echo -e "${style_code}${color_code}${text}${reset}"
}

# Paths
HOST_PATH="/etc/hosts"
DNS_PATH="/etc/resolv.conf"

# Green, Yellow & Red Messages.
green_msg() {
    tput setaf 2
    echo "[*] ----- $1"
    tput sgr0
}

yellow_msg() {
    tput setaf 3
    echo "[*] ----- $1"
    tput sgr0
}

red_msg() {
    tput setaf 1
    echo "[*] ----- $1"
    tput sgr0
}

# Function to update system and install sqlite3
install_dependencies() {
    echo -e "${BLUE}Updating package list...${NC}"
    sudo apt update -y

    echo -e "${BLUE}Installing openssl...${NC}"
    sudo apt install -y openssl

    echo -e "${BLUE}Installing jq...${NC}"
    sudo apt install -y jq

    echo -e "${BLUE}Installing curl...${NC}"
    sudo apt install -y curl

    echo -e "${BLUE}Installing ufw...${NC}"
    sudo apt install -y ufw

    sudo apt -y install apt-transport-https locales apt-utils bash-completion libssl-dev socat

    sudo apt -y -q autoclean
    sudo apt -y clean
    sudo apt -q update
    sudo apt -y autoremove --purge
}

# Function to check if the system is Ubuntu or Debian-based
check_os() {
    if ! command -v lsb_release &> /dev/null; then
        echo -e "${Purple}This script requires lsb_release to identify the OS. Please install lsb-release.${NC}"
        exit 1
    fi

    os=$(lsb_release -is)
    if [[ "$os" != "Ubuntu" && "$os" != "Debian" ]]; then
        echo -e "${Purple}This script only supports Ubuntu and Debian-based systems.${NC}"
        exit 1
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Purple}This script must be run as root. Please run it with sudo.${NC}"
        exit 1
    fi
}

fix_etc_hosts(){
  echo
  yellow_msg "Fixing Hosts file."
  sleep 0.5

  cp $HOST_PATH /etc/hosts.bak
  yellow_msg "Default hosts file saved. Directory: /etc/hosts.bak"
  sleep 0.5

  # shellcheck disable=SC2046
  if ! grep -q $(hostname) $HOST_PATH; then
    echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
    green_msg "Hosts Fixed."
    echo
    sleep 0.5
  else
    green_msg "Hosts OK. No changes made."
    echo
    sleep 0.5
  fi
}

fix_dns(){
    echo
    yellow_msg "Fixing DNS Temporarily."
    sleep 0.5

    cp $DNS_PATH /etc/resolv.conf.bak
    yellow_msg "Default resolv.conf file saved. Directory: /etc/resolv.conf.bak"
    sleep 0.5

    sed -i '/nameserver/d' $DNS_PATH

    echo "nameserver 8.8.8.8" >> $DNS_PATH
    echo "nameserver 8.8.4.4" >> $DNS_PATH

    green_msg "DNS Fixed Temporarily."
    echo
    sleep 0.5
}

# Set the server TimeZone to the VPS IP address location.
set_timezone() {
    echo
    yellow_msg 'Setting TimeZone based on VPS IP address...'
    sleep 0.5

    get_location_info() {
        local ip_sources=("https://ipv4.icanhazip.com" "https://api.ipify.org" "https://ipv4.ident.me/")
        local location_info

        for source in "${ip_sources[@]}"; do
            local ip=$(curl -s "$source")
            if [ -n "$ip" ]; then
                location_info=$(curl -s "http://ip-api.com/json/$ip")
                if [ -n "$location_info" ]; then
                    echo "$location_info"
                    return 0
                fi
            fi
        done

        red_msg "Error: Failed to fetch location information from known sources. Setting timezone to UTC."
        sudo timedatectl set-timezone "UTC"
        return 1
    }

    # Fetch location information from three sources
    location_info_1=$(get_location_info)
    location_info_2=$(get_location_info)
    location_info_3=$(get_location_info)

    # Extract timezones from the location information
    timezones=($(echo "$location_info_1 $location_info_2 $location_info_3" | jq -r '.timezone'))

    # Check if at least two timezones are equal
    if [[ "${timezones[0]}" == "${timezones[1]}" || "${timezones[0]}" == "${timezones[2]}" || "${timezones[1]}" == "${timezones[2]}" ]]; then
        # Set the timezone based on the first matching pair
        timezone="${timezones[0]}"
        sudo timedatectl set-timezone "$timezone"
        green_msg "Timezone set to $timezone"
    else
        red_msg "Error: Failed to fetch consistent location information from known sources. Setting timezone to UTC."
        sudo timedatectl set-timezone "UTC"
    fi

    echo
    sleep 0.5
}

check_root
check_os
install_dependencies
fix_etc_hosts
fix_dns

# Function to install unzip if not already installed
install_unzip() {
    if ! command -v unzip &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${Purple}unzip is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y unzip
        else
            echo -e "${Purple}Error: Unsupported package manager. Please install unzip manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}

# Install unzip
install_unzip

# Function to install jq if not already installed
install_jq() {
    if ! command -v jq &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${Purple}jq is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y jq
        else
            echo -e "${Purple}Error: Unsupported package manager. Please install jq manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}

# Install jq
install_jq

install_iptables() {
    if ! command -v iptables &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${Purple}iptables is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y iptables
        else
            echo -e "${Purple}Error: Unsupported package manager. Please install iptables manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}

# Install iptables
install_iptables

install_bc() {
    if ! command -v bc &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${Purple}bc is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y bc
        else
            echo -e "${Purple}Error: Unsupported package manager. Please install bc manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}

# Install bc
install_bc


config_dir="/root/rathole-core"
# Function to download and extract Rathole Core
download_and_extract_rathole() {
    # check if core installed already
    if [[ -d "$config_dir" ]]; then
        echo -e "${Cyan}Rathole Core is already installed.${NC}"
        sleep 1
        return 1
    fi

    # Define the entry to check/add
     ENTRY="199.232.68.133 raw.githubusercontent.com"
    # Check if the github entry exists in /etc/hosts
    if ! grep -q "$ENTRY" /etc/hosts; then
	echo "Github Entry not found. Adding to /etc/hosts..."
        echo "$ENTRY" >> /etc/hosts
    else
    echo "Github entry already exists in /etc/hosts."
    fi

    # Check operating system
    if [[ $(uname) == "Linux" ]]; then
        ARCH=$(uname -m)
        DOWNLOAD_URL=$(curl -sSL https://api.github.com/repos/rapiz1/rathole/releases/latest | grep -o "https://.*$ARCH.*linux.*zip" | head -n 1)
    else
        echo -e "${Purple}Unsupported operating system.${NC}"
        sleep 1
        exit 1
    fi
    if [[ "$ARCH" == "x86_64" ]]; then
    	DOWNLOAD_URL='https://github.com/iPmartNetwork/RatholeTunnel/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip'
    fi

    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${Purple}Failed to retrieve download URL.${NC}"
        sleep 1
        exit 1
    fi

    DOWNLOAD_DIR=$(mktemp -d)
    echo -e "Downloading Rathole from $DOWNLOAD_URL...\n"
    sleep 1
    curl -sSL -o "$DOWNLOAD_DIR/rathole.zip" "$DOWNLOAD_URL"
    echo -e "Extracting Rathole...\n"
    sleep 1
    unzip -q "$DOWNLOAD_DIR/rathole.zip" -d "$config_dir"
    echo -e "${Cyan}Rathole installation completed.${NC}\n"
    chmod u+x ${config_dir}/rathole
    rm -rf "$DOWNLOAD_DIR"
}

#Download and extract the Rathole core
download_and_extract_rathole

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Fetch server country using ip-api.com
SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')

# Fetch server isp using ip-api.com 
SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')

# Function to display ASCII logo
display_logo() {
    echo -e "${Purple}"
    cat << "EOF"
          
                 
══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════
EOF
    echo -e "${NC}"
}


# Function to display server location and IP
display_server_info() {
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"  
    echo -e "${Cyan}Server Country:${Purple} $SERVER_COUNTRY"
    echo -e "${Cyan}Server IP:${Purple} $SERVER_IP"
    echo -e "${Cyan}Server ISP:${Purple} $SERVER_ISP"
}

# Function to display Rathole Core installation status
display_rathole_core_status() {
    if [[ -d "$config_dir" ]]; then
        echo -e "${Cyan}Rathole Core:${NC} ${Cyan}Installed${NC}"
    else
        echo -e "${Purple}Rathole Core:${NC} ${Purple}Not installed${NC}"
    fi
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"  
}

# Function to check if a given string is a valid IPv6 address
check_ipv6() {
    local ip=$1
    # Define the IPv6 regex pattern
    ipv6_pattern="^([0-9a-fA-F]{1,4}:){7}([0-9a-fA-F]{1,4}|:)$|^(([0-9a-fA-F]{1,4}:){1,7}|:):((:[0-9a-fA-F]{1,4}){1,7}|:)$"
    # Remove brackets if present
    ip="${ip#[}"
    ip="${ip%]}"

    if [[ $ip =~ $ipv6_pattern ]]; then
        return 0  # Valid IPv6 address
    else
        return 1  # Invalid IPv6 address
    fi
}

check_port() {
    local PORT=$1

    if [ -z "$PORT" ]; then
        echo "Usage: check_port <port>"
        return 1
    fi

    if lsof -i -P -n | grep LISTEN | awk '{print $9}' | awk -F':' '{print $NF}' | grep -w $PORT > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function for configuring tunnel
configure_tunnel() {

# check if the rathole-core installed or not
if [[ ! -d "$config_dir" ]]; then
    echo -e "\n${Purple}Rathole-core directory not found. Install it first through 'Install Rathole core' option.${NC}\n"
    read -p "Press Enter to continue..."
    return 1
fi

    clear
    colorize cyan "Configurating rathole tunnel menu" bold
    echo
    colorize cyan "1. Configure for IRAN server"
    colorize Purple "2. Configure for KHAREJ server"
    echo
    read -p "Enter your choice: " configure_choice
    case "$configure_choice" in
        1) iran_server_configuration ;;
        2) kharej_server_configuration ;;
        *) echo -e "${Purple}Invalid option!${NC}" && sleep 1 ;;
    esac
    echo
    read -p "Press Enter to continue..."
}


#Global Variables
service_dir="/etc/systemd/system"
  
# Function to configure Iran server
iran_server_configuration() {  
    clear
    colorize cyan "Configuring IRAN server" bold
    
    echo
    
    #Add IPv6 Support
	local_ip='0.0.0.0'
	read -p " Listen for IPv6 address? (y/n): " answer
	if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
	    colorize yellow "IPv6 Enabled"
	    local_ip='[::]'
	elif [ "$answer" = "n" ]; then
	    colorize yellow "IPv4 Enabled"
	    local_ip='0.0.0.0'
	else
	    colorize yellow "Invalid choice. IPv4 enabled by default."
	    local_ip='0.0.0.0'
	fi

	echo 
	
	while true; do
	    echo -ne " Tunnel port: "
	    read -r tunnel_port
	
	    if [[ "$tunnel_port" =~ ^[0-9]+$ ]] && [ "$tunnel_port" -gt 22 ] && [ "$tunnel_port" -le 65535 ]; then
	        if check_port $tunnel_port; then
	            colorize red "Port $tunnel_port is in use."
	        else
	            break
	        fi
	    else
	        colorize red "Please enter a valid port number between 23 and 65535"
	    fi
	done
	
	echo
	
	# Initialize nodelay variable
	local nodelay=""
	# Keep prompting the user until a valid input is provided
	while [[ "$nodelay" != "true" && "$nodelay" != "false" ]]; do
	    echo -ne " tcp nodelay (true/false): " 
	    read -r nodelay
	    if [[ "$nodelay" != "true" && "$nodelay" != "false" ]]; then
	        colorize Purple "Invalid nodelay input. Please enter 'true' or 'false'"
	    fi
	done
    
    echo
    
    # Initialize transport variable
	local transport=""
	# Keep prompting the user until a valid input is provided
	while [[ "$transport" != "tcp" && "$transport" != "udp" ]]; do
	    # Prompt the user to input transport type
	    echo -ne " Transport type(tcp/udp): " 
	    read -r transport
	
	    # Check if the input is either tcp or udp
	    if [[ "$transport" != "tcp" && "$transport" != "udp" ]]; then
	        colorize red "Invalid transport type. Please enter 'tcp' or 'udp'"
	    fi
	done
	
	echo 

	echo -ne " Security Token (press enter to use default value): "
	read -r token
	if [[ -z "$token" ]]; then
		token="iPmart"
	fi

	echo 
	
	# Prompt for Ports
	echo -ne " Enter your ports separated by commas (e.g. 2053,2083,2096): "
	read -r input_ports
	input_ports=$(echo "$input_ports" | tr -d ' ')
	# Convert the input into an array, splitting by comma
	IFS=',' read -r -a ports <<< "$input_ports"
	# Iterate through each port and perform an action
	for port in "${ports[@]}"; do
		if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -gt 22 ] && [ "$port" -le 65535 ]; then
			if check_port $port; then
			    colorize Purple "[ERROR] Port $port is in use."
			else
				colorize green "[INFO] Port $port added to your configs"
			    config_ports+=("$port")
			fi
		else
			colorize Purple "[ERROR] Port $port is Invalid. Please enter a valid port number between 23 and 65535"
		fi
	  
	done
	
	if [ ${#config_ports[@]} -eq 0 ]; then
		colorize Purple "No ports were entered. Exiting." bold
		sleep 2
		return 1
	fi
	
	
    # Generate server configuration file
    cat << EOF > "${config_dir}/iran${tunnel_port}.toml"
[server]
bind_addr = "${local_ip}:${tunnel_port}"
default_token = "$token"
heartbeat_interval = 30

[server.transport]
type = "tcp"

[server.transport.tcp]
nodelay = $nodelay

EOF

    # Add each config port to the configuration file
    for port in "${config_ports[@]}"; do
        cat << EOF >> "${config_dir}/iran${tunnel_port}.toml"
[server.services.${port}]
type = "$transport"
bind_addr = "${local_ip}:${port}"

EOF
    done

    echo 

    # Create the systemd service unit file
    cat << EOF > "${service_dir}/rathole-iran${tunnel_port}.service"
[Unit]
Description=Rathole Iran Port $tunnel_port (Iran)
After=network.target

[Service]
Type=simple
ExecStart=${config_dir}/rathole ${config_dir}/iran${tunnel_port}.toml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to read the new unit file
    systemctl daemon-reload >/dev/null 2>&1

    # Enable and start the service to start on boot
    if systemctl enable --now "${service_dir}/rathole-iran${tunnel_port}.service" >/dev/null 2>&1; then
        colorize cyan "Iran service with port $tunnel_port enabled to start on boot and started."
    else
        colorize red "Failed to enable service with port $tunnel_port. Please check your system configuration."
        return 1
    fi
     
    echo
    colorize cyan "IRAN server configuration completed successfully."
}

# Function for configuring Kharej server
kharej_server_configuration() {
    clear
    colorize cyan "Configuring kharej server" bold 
    
    echo
 
	# Prompt for IRAN server IP address
	while true; do
	    echo -ne " IRAN server IP address [IPv4/IPv6]: " 
	    read -r SERVER_ADDR
	    if [[ -n "$SERVER_ADDR" ]]; then
	        break
	    else
	        colorize Purple "Server address cannot be empty. Please enter a valid address."
	        echo
	    fi
	done
	
    echo
    
    # Read the tunnel port
 	while true; do
	    echo -ne " Tunnel port: "
	    read -r tunnel_port
	
	    if [[ "$tunnel_port" =~ ^[0-9]+$ ]] && [ "$tunnel_port" -gt 22 ] && [ "$tunnel_port" -le 65535 ]; then
	        if check_port $tunnel_port; then
	            colorize Purple "Port $tunnel_port is in use."
	        else
	            break
	        fi
	    else
	        colorize Purple "Please enter a valid port number between 23 and 65535"
	    fi
	done
    
    echo
    
	# Initialize nodelay variable
	local nodelay=""
	# Keep prompting the user until a valid input is provided
	while [[ "$nodelay" != "true" && "$nodelay" != "false" ]]; do
	    echo -ne " tcp nodelay (true/false): " 
	    read -r nodelay
	    if [[ "$nodelay" != "true" && "$nodelay" != "false" ]]; then
	        colorize Purple "Invalid nodelay input. Please enter 'true' or 'false'"
	    fi
	done

	echo

    # Initialize transport variable
    local transport=""

	# Keep prompting the user until a valid input is provided
	while [[ "$transport" != "tcp" && "$transport" != "udp" ]]; do
	    # Prompt the user to input transport type
	    echo -ne " Transport type (tcp/udp): " 
	    read -r transport
	
	    # Check if the input is either tcp or udp
	    if [[ "$transport" != "tcp" && "$transport" != "udp" ]]; then
	        colorize red "Invalid transport type. Please enter 'tcp' or 'udp'"
	    fi
	done

	echo

	echo -ne " Security Token (press enter to use default value): "
	read -r token
	if [[ -z "$token" ]]; then
		token="iPmart"
	fi

	echo
	
		
	# Prompt for Ports
	echo -ne " Enter your ports separated by commas (e.g. 2053,2083,2096): "
	read -r input_ports
	input_ports=$(echo "$input_ports" | tr -d ' ')
	# Convert the input into an array, splitting by comma
	IFS=',' read -r -a ports <<< "$input_ports"
	# Iterate through each port and perform an action
	for port in "${ports[@]}"; do
		if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -gt 22 ] && [ "$port" -le 65535 ]; then
			if ! check_port $port; then
			    colorize yellow "[INFO] Port $port is not LISTEN. Forwarding to idle port error occured."
			fi
			colorize cyan "[INFO] Port $port added to your configs"
		    config_ports+=("$port")
		else
			colorize Purple "[ERROR] Port $port is Invalid. Please enter a valid port number between 23 and 65535"
		fi
	  
	done
	
	if [ ${#config_ports[@]} -eq 0 ]; then
		colorize Purple "No ports were entered. Exiting." bold
		sleep 2
		return 1
	fi
	
	
	#Add IPv6 Support
	local_ip='0.0.0.0'
	if check_ipv6 "$SERVER_ADDR"; then
	    local_ip='[::]'
	    # Remove brackets if present
	    SERVER_ADDR="${SERVER_ADDR#[}"
	    SERVER_ADDR="${SERVER_ADDR%]}"
	fi

    # Generate server configuration file
    cat << EOF > "${config_dir}/kharej${tunnel_port}.toml"
[client]
remote_addr = "${SERVER_ADDR}:${tunnel_port}"
default_token = "$token"
heartbeat_timeout = 40
retry_interval = 1

[client.transport]
type = "tcp"

[client.transport.tcp]
nodelay = $nodelay

EOF

    # Add each config port to the configuration file
    for port in "${config_ports[@]}"; do
        cat << EOF >> "${config_dir}/kharej${tunnel_port}.toml"
[client.services.${port}]
type = "$transport"
local_addr = "${local_ip}:${port}"

EOF
    done
    
    echo

    # Create the systemd service unit file
    cat << EOF > "${service_dir}/rathole-kharej${tunnel_port}.service"
[Unit]
Description=Rathole Kharej Port $tunnel_port 
After=network.target

[Service]
Type=simple
ExecStart=${config_dir}/rathole ${config_dir}/kharej${tunnel_port}.toml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to read the new unit file
    systemctl daemon-reload >/dev/null 2>&1

    # Enable and start the service to start on boot
    if systemctl enable --now "${service_dir}/rathole-kharej${tunnel_port}.service" >/dev/null 2>&1; then
        colorize cyan "Kharej service with port $tunnel_port enabled to start on boot and started."
    else
        colorize Purple "Failed to enable service with port $tunnel_port. Please check your system configuration."
        return 1
    fi

    echo
    colorize cyan "Kharej server configuration completed successfully."
}


# Function for checking tunnel status
check_tunnel_status() {
    echo
    
	# Check for .toml files
	if ! ls "$config_dir"/*.toml 1> /dev/null 2>&1; then
	    colorize red "No config files found in the rathole directory." bold
	    echo 
	    press_key
	    return 1
	fi

	clear
    colorize yellow "Checking all services status..." bold
    sleep 1
    echo
    for config_path in "$config_dir"/iran*.toml; do
        if [ -f "$config_path" ]; then
            # Extract config_name without directory path and change it to service name
			config_name=$(basename "$config_path")
			config_name="${config_name%.toml}"
			service_name="rathole-${config_name}.service"
            config_port="${config_name#iran}"
            
			# Check if the rathole-client-kharej service is active
			if systemctl is-active --quiet "$service_name"; then
				colorize cyan "Iran service with tunnel port $config_port is running"
			else
				colorize Purple "Iran service with tunnel port $config_port is not running"
			fi
   		fi
    done
    
    for config_path in "$config_dir"/kharej*.toml; do
        if [ -f "$config_path" ]; then
            # Extract config_name without directory path and change it to service name
			config_name=$(basename "$config_path")
			config_name="${config_name%.toml}"
			service_name="rathole-${config_name}.service"
            config_port="${config_name#kharej}"
            
			# Check if the rathole-client-kharej service is active
			if systemctl is-active --quiet "$service_name"; then
				colorize cyan "Kharej service with tunnel port $config_port is running"
			else
				colorize Purple "Kharej service with tunnel port $config_port is not running"
			fi
   		fi
    done
    
    
    echo
    press_key
}


# Function for destroying tunnel
tunnel_management() {
	echo
	# Check for .toml files
	if ! ls "$config_dir"/*.toml 1> /dev/null 2>&1; then
	    colorize red "No config files found in the rathole directory." bold
	    echo 
	    press_key
	    return 1
	fi
	
	clear
	colorize cyan "List of existing services to manage:" bold
	echo 
	
	#Variables
    local index=1
    declare -a configs

    for config_path in "$config_dir"/iran*.toml; do
        if [ -f "$config_path" ]; then
            # Extract config_name without directory path
            config_name=$(basename "$config_path")
            
            # Remove "iran" prefix and ".toml" suffix
            config_port="${config_name#iran}"
            config_port="${config_port%.toml}"
            
            configs+=("$config_path")
            echo -e "${MAGENTA}${index}${NC}) ${GREEN}Iran${NC} service, Tunnel port: ${YELLOW}$config_port${NC}"
            ((index++))
        fi
    done
    

    
    for config_path in "$config_dir"/kharej*.toml; do
        if [ -f "$config_path" ]; then
            # Extract config_name without directory path
            config_name=$(basename "$config_path")
            
            # Remove "kharej" prefix and ".toml" suffix
            config_port="${config_name#kharej}"
            config_port="${config_port%.toml}"
            
            configs+=("$config_path")
            echo -e "${MAGENTA}${index}${NC}) ${cyan}Kharej${NC} service, Tunnel port: ${YELLOW}$config_port${NC}"
            ((index++))
        fi
    done
    
    echo
	echo -ne "Enter your choice (0 to return): "
    read choice 
	
	# Check if the user chose to return
	if (( choice == 0 )); then
	    return
	fi
	#  validation
	while ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 || choice > ${#configs[@]} )); do
	    colorize Purple "Invalid choice. Please enter a number between 1 and ${#configs[@]}." bold
	    echo
	    echo -ne "Enter your choice (0 to return): "
	    read choice
		if (( choice == 0 )); then
			return
		fi
	done
	
	selected_config="${configs[$((choice - 1))]}"
	config_name=$(basename "${selected_config%.toml}")
	service_name="rathole-${config_name}.service"
	  
	clear
	colorize cyan "List of available commands for $config_name:" bold
	echo 
	colorize Purple "1. Remove this tunnel"
	colorize Purple "2. Restart this tunnel"
	colorize Purple "3. Add a new config for this tunnel"
	colorize Purple "4. Add a cronjob for this tunnel"
	colorize Purple "5. Remove existing cronjob for this tunnel"
	colorize Purple "6. View logs"
	echo 
	read -p "Enter your choice (0 to return): " choice
	
    case $choice in
        1) destroy_tunnel "$selected_config" ;;
        2) restart_service "$service_name" ;;
        3) add_new_config "$selected_config" ;;
        4) add_cron_job_menu "$service_name";;
        5) delete_cron_job "$service_name";;
        6) view_service_logs "$service_name" ;;
        0) return 1 ;;
        *) echo -e "${RED}Invalid option!${NC}" && sleep 1 && return 1;;
    esac
	
}

destroy_tunnel(){
	echo
	#Vaiables
	config_path="$1"
	config_name=$(basename "${config_path%.toml}")
    service_name="rathole-${config_name}.service"
    service_path="$service_dir/$service_name"
    
	# Prompt to confirm before removing Rathole-core directory
    echo -ne "${YELLOW}Do you want to remove Rathole-core? (y/n)${NC}: " 
    read -r confirm
	echo     
	if [[ $confirm == [yY] ]]; then
	    if [[ -d "$config_dir" ]]; then
	        rm -rf "$config_dir" >/dev/null 2>&1
	        echo -e "${cyan}Rathole-core directory removed.${NC}\n"
	    else
	        echo -e "${Purple}Rathole-core directory not found.${NC}\n"
	    fi
	else
	    echo -e "${YELLOW}Rathole core removal canceled.${NC}"
	fi

	# Check if config exists and delete it
	if [ -f "$config_path" ]; then
	  rm -f "$config_path" >/dev/null 2>&1
	fi

    delete_cron_job $service_name
    
        # Stop and disable the client service if it exists
    if [[ -f "$service_path" ]]; then
        if systemctl is-active "$service_name" &>/dev/null; then
            systemctl disable --now "$service_name" >/dev/null 2>&1
        fi
        rm -f "$service_path" >/dev/null 2>&1
    fi
    
        
    echo
    # Reload systemd to read the new unit file
    if systemctl daemon-reload >/dev/null 2>&1 ; then
        echo -e "Systemd daemon reloaded.\n"
    else
        echo -e "${Purple}Failed to reload systemd daemon. Please check your system configuration.${NC}"
    fi
    
    echo -e "${cyan}Tunnel destroyed successfully!${NC}\n"
    sleep 1

}


#Function to restart services
restart_service() {
    echo
    service_name="$1"
    colorize yellow "Restarting $service_name" bold
    echo
    
    # Check if service exists
    if systemctl list-units --type=service | grep -q "$service_name"; then
        systemctl restart "$service_name"
        colorize green "Service restarted successfully"

    else
        colorize red "Cannot restart the service" 
    fi
    echo
    press_key
}


# Function to add cron-tab job
add_cron_job() {
    local restart_time="$1"
    local reset_path="$2"
    local service_name="$3"

    # Save existing crontab to a temporary file
    crontab -l > /tmp/crontab.tmp

    # Append the new cron job to the temporary file
    echo "$restart_time $reset_path #$service_name" >> /tmp/crontab.tmp

    # Install the modified crontab from the temporary file
    crontab /tmp/crontab.tmp

    # Remove the temporary file
    rm /tmp/crontab.tmp
}
delete_cron_job() {
    echo
    local service_name="$1"
    
    crontab -l | grep -v "#$service_name" | crontab -
    rm -f "$config_dir/${service_name%.service}.sh" >/dev/null 2>&1
    
    colorize cyan "Cron job for $service_name deleted successfully." bold
    sleep 2
}

add_new_config(){
    echo
    colorize yellow "Under construction..." bold
    sleep 1

}

add_cron_job_menu() {
    echo
    service_name="$1"
    
    # Prompt user to choose a restart time interval
    echo "Select the restart time interval:"
    echo ''
    echo "1. Every 5 min"
    echo "2. Every 10 min"
    echo "3. Every 15 min"
    echo "4. Every 20 min"
    echo "5. Every 25 min"
    echo "6. Every 30 min"
    echo "7. Every 1 hour"
    echo "8. Every 2 hours"
    echo "9. Every 4 hours"
    echo "10. Every 6 hours"
    echo "11. Every 12 hours"
    echo "12. Every 24 hours"
    echo ''
    read -p "Enter your choice: " time_choice
    echo ''
    read -p "Enter your choice: " time_choice
    echo ''
    # Validate user input for restart time interval
    case $time_choice in
        1)
            restart_time="*/5 * * * *"
            ;;
        2)
            restart_time="*/10 * * * *"
            ;;
        3)
            restart_time="*/15 * * * *"
            ;;
        4)
            restart_time="*/20 * * * *"
            ;;
        5)
            restart_time="*/25 * * * *"
            ;;
        6)
            restart_time="*/30 * * * *"
            ;;
        7)
            restart_time="0 * * * *"
            ;;
        8)
            restart_time="0 */2 * * *"
            ;;
        9)
            restart_time="0 */4 * * *"
            ;;
        10)
            restart_time="0 */6 * * *"
            ;;
        11)
            restart_time="0 */12 * * *"
            ;;
        12)
            restart_time="0 0 * * *"
            ;;
        *)
            echo -e "${Purple}Invalid choice. Please enter a number between 1 and 12.${NC}\n"
            return 1
            ;;
    esac


    # remove cronjob created by thi script
    delete_cron_job $service_name  > /dev/null 2>&1
    
    # Path ro reset file
    reset_path="$config_dir/${service_name%.service}.sh"
    
    #add cron job to kill the running rathole processes
    cat << EOF > "$reset_path"
#! /bin/bash
pids=\$(pgrep rathole)
sudo kill -9 \$pids
sudo systemctl daemon-reload
sudo systemctl restart $service_name
EOF

    # make it +x !
    chmod +x "$reset_path"
    
    # Add cron job to restart the specified service at the chosen time
    add_cron_job  "$restart_time" "$reset_path" "$service_name"
    echo
    colorize green "Cron-job added successfully to restart the service '$service_name'." bold
    sleep 2
}

view_service_logs (){
	clear
	journalctl -eu "$1"

}
update_script(){
# Define the destination path
DEST_DIR="/usr/bin/"
RATHOLE_SCRIPT="rathole"
SCRIPT_URL="https://github.com/iPmartNetwork/RatholeTunnel/raw/main/beta.sh"

echo ''
# Check if ipmart.sh exists in /bin/bash
if [ -f "$DEST_DIR/$RATHOLE_SCRIPT" ]; then
    # Remove the existing rathole
    rm "$DEST_DIR/$RATHOLE_SCRIPT"
    if [ $? -eq 0 ]; then
        echo -e "${Cyan}Existing $RATHOLE_SCRIPT has been successfully removed from $DEST_DIR.${NC}"
    else
        echo -e "${Purple}Failed to remove existing $RATHOLE_SCRIPT from $DEST_DIR.${NC}"
        sleep 1
        return 1
    fi
else
    echo -e "${YELLOW}$RATHOLE_SCRIPT does not exist in $DEST_DIR. No need to remove.${NC}"
fi
echo ''
# Download the new rathole.sh from the GitHub URL
echo -e "${CYAN}Downloading the new $RATHOLE_SCRIPT from $SCRIPT_URL...${NC}"

curl -s -L -o "$DEST_DIR/$RATHOLE_SCRIPT" "$SCRIPT_URL"

echo ''
if [ $? -eq 0 ]; then
    echo -e "${Cyan}New $RATHOLE_SCRIPT has been successfully downloaded to $DEST_DIR.${NC}\n"
    chmod +x "$DEST_DIR/$RATHOLE_SCRIPT"
    echo -e "${CYAN}Please exit the script and type 'rathole' to run it again${NC}\n"
    read -p "Press any key to continue..."
    exit 0
else
    echo -e "${Purple}Failed to download $RATHOLE_SCRIPT from $SCRIPT_URL.${NC}"
    sleep 1
    return 1
fi

}

optimize_tcp() {
    echo -e "${BLUE}Optimizing TCP settings for better performance...${NC}"

    # Backup current sysctl settings
    sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup

    # Apply performance optimizations
    sudo bash -c 'cat <<EOF >> /etc/sysctl.conf
# TCP performance optimizations
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Additional optimizations
fs.file-max = 67108864
net.core.default_qdisc = fq_codel
net.core.netdev_max_backlog = 32768
net.core.optmem_max = 262144
net.core.somaxconn = 65536
net.core.rmem_max = 33554432
net.core.rmem_default = 1048576
net.core.wmem_max = 33554432
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 16384 1048576 33554432
net.ipv4.tcp_wmem = 16384 1048576 33554432
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fin_timeout = 25
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_max_orphans = 819200
net.ipv4.tcp_max_syn_backlog = 20480
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_mem = 65536 1048576 33554432
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_notsent_lowat = 32768
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.udp_mem = 65536 1048576 33554432
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.unix.max_dgram_qlen = 256
vm.min_free_kbytes = 65536
vm.swappiness = 10
vm.vfs_cache_pressure = 250
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.neigh.default.gc_thresh1 = 512
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_stale_time = 60
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
kernel.panic = 1
vm.dirty_ratio = 20
EOF'

    # Apply the new sysctl settings
    sudo sysctl -p

    echo -e "${GREEN}TCP settings optimized.${NC}"
}

# Function to enable BBR
enable_bbr() {
    echo -e "${BLUE}Enabling BBR...${NC}"

    # Check if BBR is already enabled
    if lsmod | grep -q bbr; then
        echo -e "${GREEN}BBR is already enabled.${NC}"
    else
        # Load the TCP BBR module
        sudo modprobe tcp_bbr

        # Ensure BBR is loaded on boot
        echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/modules.conf

        # Set BBR as the default congestion control algorithm
        sudo bash -c 'echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf'
        sudo bash -c 'echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf'

        # Apply the new sysctl settings
        sudo sysctl -p

        echo -e "${GREEN}BBR enabled.${NC}"
    fi
}

# Main function to perform all optimizations
optimize_network() {
    optimize_tcp
    enable_bbr
}

# Color codes
Purple='\033[0;35m'
Cyan='\033[0;36m'
cyan='\033[0;36m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
White='\033[0;96m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color 

# Function to display menu
display_menu() {
    clear
    display_logo
    display_server_info
    display_rathole_core_status
    echo ''
    echo -e "${White}1.  Install Rathole Core${NC}"
    echo -e "${Cyan}2.  Configure tunnel${NC}"
    echo -e "${White}3.  Destroy tunnel${NC}"
    echo -e "${Cyan}4. Check tunnel status${NC}"
    echo -e "${White}5.  Optimize the Network settings${NC}"
    echo -e "${Cyan}6.  Fix TimeZone${NC}"
    echo -e "${White}7.  update_script"
    echo -e "${Cyan}0.  Exit"
    echo ''
    echo "-------------------------------"
}

# Function to read user input
read_option() {
    read -p "Enter your choice [1-7]: " choice
    case $choice in
        1) download_and_extract_rathole ;;
        2) configure_tunnel ;;
        3) destroy_tunnel ;;
	4) check_tunnel_status ;;
        5) optimize_network;;
        6) set_timezone;;
        7) update_script ;;
        0) exit 0 ;;
        *) echo -e "${Purple}Invalid option!${NC}" && sleep 1 ;;
    esac
}

# Main script
while true
do
    display_menu
    read_option
done
