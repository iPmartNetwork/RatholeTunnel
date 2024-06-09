#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   sleep 1
   exit 1
fi

# Function to install unzip if not already installed
install_unzip() {
    if ! command -v unzip &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}unzip is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y unzip
        else
            echo -e "${RED}Error: Unsupported package manager. Please install unzip manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    else
        echo -e "${GREEN}unzip is already installed.${NC}"
    fi
}

# Install unzip
install_unzip

# Function to install jq if not already installed
install_jq() {
    if ! command -v jq &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}jq is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y jq
        else
            echo -e "${RED}Error: Unsupported package manager. Please install jq manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    else
        echo -e "${Cyan}jq is already installed.${NC}"
    fi
}

# Install jq
install_jq

install_iptables() {
    if ! command -v iptables &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}iptables is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y iptables
        else
            echo -e "${RED}Error: Unsupported package manager. Please install iptables manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    else
        echo -e "${Cyan}iptables is already installed.${NC}"
    fi
}

# Install iptables
install_iptables

install_bc() {
    if ! command -v bc &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}bc is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y bc
        else
            echo -e "${RED}Error: Unsupported package manager. Please install bc manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    else
        echo -e "${Cyan}bc is already installed.${NC}"
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
     ENTRY="185.199.108.133 raw.githubusercontent.com"
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
        echo -e "${RED}Unsupported operating system.${NC}"
        sleep 1
        exit 1
    fi
    if [[ "$ARCH" == "x86_64" ]]; then
    	DOWNLOAD_URL='https://github.com/iPmartNetwork/RatholeTunnel/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip'
    fi

    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}Failed to retrieve download URL.${NC}"
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
    echo -e "${CYAN}Server Country:${NC} $SERVER_COUNTRY"
    echo -e "${CYAN}Server IP:${NC} $SERVER_IP"
    echo -e "${CYAN}Server ISP:${NC} $SERVER_ISP"
}

# Function to display Rathole Core installation status
display_rathole_core_status() {
    if [[ -d "$config_dir" ]]; then
        echo -e "${CYAN}Rathole Core:${NC} ${Cyan}Installed${NC}"
    else
        echo -e "${CYAN}Rathole Core:${NC} ${RED}Not installed${NC}"
    fi
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"  
}


# Function for configuring tunnel
configure_tunnel() {

# check if the rathole-core installed or not
if [[ ! -d "$config_dir" ]]; then
    echo -e "\n${RED}Rathole-core directory not found. Install it first through option 7.${NC}\n"
    read -p "Press Enter to continue..."
    return 1
fi

    clear
    echo -e "${YELLOW}Configurating RatHole Tunnel...${NC}"
    echo -e "\e[93m═════════════════════════════════════════════\e[0m" 
    echo ''
    echo -e "1. For ${Cyan}IRAN${NC} Server\n"
    echo -e "2. For ${Cyan}Kharej${NC} Server\n"
    read -p "Enter your choice: " configure_choice
    case "$configure_choice" in
        1) iran_server_configuration ;;
        2) kharej_server_configuration ;;
        *) echo -e "${RED}Invalid option!${NC}" && sleep 1 ;;
    esac
    echo ''
    read -p "Press Enter to continue..."
}


#Global Variables
     iran_config_file="${config_dir}/server.toml"
     iran_service_name="rathole-iran.service"
     iran_service_file="/etc/systemd/system/${iran_service_name}"

   
    kharej_config_file="${config_dir}/client*.toml"
    kharej_service_name="rathole-kharej.service"
    kharej_service_file="/etc/systemd/system/${kharej_service_name}"
    
    
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

# Function to configure Iran server
iran_server_configuration() {  
    clear
    echo -e "${YELLOW}Configuring IRAN server...${NC}\n" 
    
    # Read the tunnel port
    read -p "Enter the tunnel port: " tunnel_port
    while ! [[ "$tunnel_port" =~ ^[0-9]+$ ]]; do
        echo -e "${RED}Please enter a valid port number.${NC}"
        read -p "Enter the tunnel port: " tunnel_port
    done
    
    echo ''
    # Read the number of config ports and read each port
    read -p "Enter the number of your configs: " num_ports
    while ! [[ "$num_ports" =~ ^[0-9]+$ ]]; do
        echo -e "${RED}Please enter a valid number.${NC}"
        read -p "Enter the number of your configs: " num_ports
    done
    
    echo ''
    config_ports=()
    for ((i=1; i<=$num_ports; i++)); do
        read -p "Enter Config Port $i: " port
        while ! [[ "$port" =~ ^[0-9]+$ ]]; do
            echo -e "${RED}Please enter a valid port number.${NC}"
            read -p "Enter Config Port $i: " port
        done
        config_ports+=("$port")
    done

echo ''

# Initialize transport variable
local transport=""

# Keep prompting the user until a valid input is provided
while [[ "$transport" != "tcp" && "$transport" != "udp" && "$transport" != "ws" ]]; do
    # Prompt the user to input transport type
    read -p "Enter transport type (tcp/udp/ws): " transport

    # Check if the input is either tcp or udp
    if [[ "$transport" != "tcp" && "$transport" != "udp" && "$transport" != "ws" ]]; then
        echo -e "${RED}Invalid transport type. Please enter 'tcp' or 'udp' or 'ws'.${NC}"
    fi
done

echo ''
local_ip='0.0.0.0'

#Add IPv6 Support
read -p "Do you want to use IPv6 for connecting? (yes/no): " answer
echo ''
if [ "$answer" = "yes" ]; then
    echo -e "${Cyan}IPv6 selected.${NC}"
    local_ip='[::]'
elif [ "$answer" = "no" ]; then
    echo -e "${Cyan}IPv4 selected.${NC}"
else
    echo -e "${YELLOW}Invalid choice. IPv4 selected by default.${NC}"
fi
sleep 1

    # Generate server configuration file
    cat << EOF > "$iran_config_file"
[server]
bind_addr = "${local_ip}:${tunnel_port}"
default_token = "iPmart_tunnel"
heartbeat_interval = 30

[server.transport]
type = "tcp"

EOF

    # Add each config port to the configuration file
    for port in "${config_ports[@]}"; do
        cat << EOF >> "$iran_config_file"
[server.services.${port}]
type = "$transport"
bind_addr = "${local_ip}:${port}"

EOF
    done
    
    echo ''
    echo -e "${Cyan}IRAN server configuration completed.${NC}\n"
    echo -e "Starting Rathole server as a service...\n"

    # Create the systemd service unit file
    cat << EOF > "$iran_service_file"
[Unit]
Description=Rathole Server (Iran)
After=network.target

[Service]
Type=simple
ExecStart=${config_dir}/rathole ${iran_config_file}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to read the new unit file
    if systemctl daemon-reload; then
        echo "Systemd daemon reloaded."
    else
        echo -e "${RED}Failed to reload systemd daemon. Please check your system configuration.${NC}"
        return 1
    fi

    # Enable the service to start on boot
    if systemctl enable "$iran_service_name" >/dev/null 2>&1; then
        echo -e "${Cyan}Service '$iran_service_name' enabled to start on boot.${NC}"
    else
        echo -e "${RED}Failed to enable service '$iran_service_name'. Please check your system configuration.${NC}"
        return 1
    fi

    # Start the service
    if systemctl start "$iran_service_name"; then
        echo -e "${Cyan}Service '$iran_service_name' started.${NC}"
    else
        echo -e "${RED}Failed to start service '$service_name'. Please check your system configuration.${NC}"
        return 1
    fi
}

# Function for configuring Kharej server
kharej_server_configuration() {
    clear
    echo -e "${YELLOW}Configuring kharej server...${NC}\n"
    read -p "How many IRAN server do you have: " SERVER_NUM
    
    local EXEC_COMMAND="/bin/bash -c '"
    
#___________________________________________________________________ Start of the loop  

for ((j=1; j<=$SERVER_NUM; j++)); do

    clear
    echo -e "${Cyan}Let's create a tunnel for server $j${NC}" 
    echo -e "\e[93m═════════════════════════════════════════════\e[0m"  
    echo ''    
    # Read the server address
    read -p "Enter the IRAN server address [IPv4/IPv6]: " SERVER_ADDR

    echo ''
    # Read the tunnel port
    read -p "Enter the tunnel port: " tunnel_port
    while ! [[ "$tunnel_port" =~ ^[0-9]+$ ]]; do
        echo -e "${RED}Please enter a valid port number.${NC}"
        read -p "Enter the tunnel port: " tunnel_port
    done
    
    echo ''
    # Read the number of config ports and read each port
    read -p "Enter the number of your configs: " num_ports
    while ! [[ "$num_ports" =~ ^[0-9]+$ ]]; do
        echo -e "${RED}Please enter a valid number.${NC}"
        read -p "Enter the number of your configs: " num_ports
    done
    
    echo ''
    config_ports=()
    for ((i=1; i<=$num_ports; i++)); do
        read -p "Enter Config Port $i: " port
        while ! [[ "$port" =~ ^[0-9]+$ ]]; do
            echo -e "${RED}Please enter a valid port number.${NC}"
            read -p "Enter Config Port $i: " port
        done
        config_ports+=("$port")
    done

    echo ''
    # Initialize transport variable
    local transport=""

    # Keep prompting the user until a valid input is provided
    while [[ "$transport" != "tcp" && "$transport" != "udp" ]]; do
    # Prompt the user to input transport type
    read -p "Enter transport type (tcp/udp/ws): " transport

    # Check if the input is either tcp or udp or ws
    if [[ "$transport" != "tcp" && "$transport" != "udp" && "$transport" != "ws" ]]; then
        echo -e "${RED}Invalid transport type. Please enter 'tcp' or 'udp' or 'ws'.${NC}"
    fi
    done

    #this new format allow us to build various client_port.toml 
    local kharej_config_file="${config_dir}/client_p${tunnel_port}.toml"

#Add IPv6 Support
local_ip='0.0.0.0'
if check_ipv6 "$SERVER_ADDR"; then
    local_ip='[::]'
    # Remove brackets if present
    SERVER_ADDR="${SERVER_ADDR#[}"
    SERVER_ADDR="${SERVER_ADDR%]}"
fi

    # Generate server configuration file
    cat << EOF > "$kharej_config_file"
[client]
remote_addr = "${SERVER_ADDR}:${tunnel_port}"
default_token = "iPmart_tunnel"
heartbeat_timeout = 40
retry_interval = 1

[client.transport]
type = "tcp"

EOF

    # Add each config port to the configuration file
    for port in "${config_ports[@]}"; do
        cat << EOF >> "$kharej_config_file"
[client.services.${port}]
type = "$transport"
local_addr = "${local_ip}:${port}"

EOF
    done

# Now modify ExecCommand for our service file
    EXEC_COMMAND+="${config_dir}/rathole ${kharej_config_file} & "
    sleep 1
done
  
#______________________________________________________________________________End of the loop
    
    #delete last &
    EXEC_COMMAND="${EXEC_COMMAND% & }"
    #Need that last '
    EXEC_COMMAND+="'"
    
    echo ''
    echo -e "${Cyan}Kharej server configuration completed.${NC}\n"
    echo -e "${Cyan}Starting Rathole server as a service...${NC}\n"

    # Create the systemd service unit file
    cat << EOF > "$kharej_service_file"
[Unit]
Description=Rathole Server (Kharej)
After=network.target

[Service]
Type=simple
ExecStart=$EXEC_COMMAND
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to read the new unit file
    if systemctl daemon-reload; then
        echo "Systemd daemon reloaded."
    else
        echo -e "${RED}Failed to reload systemd daemon. Please check your system configuration.${NC}"
        return 1
    fi

    # Enable the service to start on boot
    if systemctl enable "$kharej_service_name" >/dev/null 2>&1; then
        echo -e "${Cyan}Service '$kharej_service_name' enabled to start on boot.${NC}"
    else
        echo -e "${RED}Failed to enable service '$kharej_service_name'. Please check your system configuration.${NC}"
        return 1
    fi

    # Start the service
    if systemctl start "$kharej_service_name"; then
        echo -e "${Cyan}Service '$kharej_service_name' started.${NC}"
    else
        echo -e "${RED}Failed to start service '$kharej_service_name'. Please check your system configuration.${NC}"
        return 1
    fi

}

# Function for destroying tunnel
destroy_tunnel() {
    echo ''
    echo -e "${YELLOW}Destroying tunnel...${NC}\n"
    sleep 1
    
    # Prompt to confirm before removing Rathole-core directory
    read -p "Are you sure you want to remove Rathole-core? (y/n): " confirm
    echo ''
    
if [[ $confirm == [yY] ]]; then
    if [[ -d "$config_dir" ]]; then
        rm -rf "$config_dir"
        echo -e "${Cyan}Rathole-core directory removed.${NC}\n"
    else
        echo -e "${RED}Rathole-core directory not found.${NC}\n"
    fi
else
    echo -e "${YELLOW}Rathole core removal canceled.${NC}\n"
fi


# Check if server.toml exists and delete it
if [ -f "$iran_config_file" ]; then
  rm -f "$iran_config_file"
fi

# Check if client.toml exists and delete it
if ls $kharej_config_file 1> /dev/null 2>&1; then
    for file in $kharej_config_file; do
         rm -f $file
    done
fi

    # remove cronjob created by thi script
    delete_cron_job 
    echo ''
    # Stop and disable the client service if it exists
    if [[ -f "$kharej_service_file" ]]; then
        if systemctl is-active "$kharej_service_name" &>/dev/null; then
            systemctl stop "$kharej_service_name"
            systemctl disable "$kharej_service_name"
        fi
        rm -f "$kharej_service_file"
    fi


    # Stop and disable the Iran server service if it exists
    if [[ -f "$iran_service_file" ]]; then
        if systemctl is-active "$iran_service_name" &>/dev/null; then
            systemctl stop "$iran_service_name"
            systemctl disable "$iran_service_name"
        fi
        rm -f "$iran_service_file"
    fi
    
    echo ''
    # Reload systemd to read the new unit file
    if systemctl daemon-reload; then
        echo -e "Systemd daemon reloaded.\n"
    else
        echo -e "${Purple}Failed to reload systemd daemon. Please check your system configuration.${NC}"
    fi
    
    echo -e "${Cyan}Tunnel destroyed successfully!${NC}\n"
    read -p "Press Enter to continue..."
}


# Function for checking tunnel status
check_tunnel_status() {
    echo ''
    echo -e "${YELLOW}Checking tunnel status...${NC}\n"
    sleep 1
    
    # Check if the rathole-client-kharej service is active
    if systemctl is-active --quiet "$kharej_service_name"; then
        echo -e "${Cyan}Kharej service is running on this server.${NC}"
    else
        echo -e "${Purple}Kharej service is not running on this server.${NC}"
    fi
    
    echo ''
    # Check if the rathole-server-iran service is active
    if systemctl is-active --quiet "$iran_service_name"; then
        echo -e "${Cyan}IRAN service is running on this server..${NC}"
    else
        echo -e "${Purple}IRAN service is not running on this server..${NC}"
    fi
    echo ''
    read -p "Press Enter to continue..."
}

#Function to restart services
restart_services() {
    echo ''
    echo -e "${YELLOW}Restarting IRAN & Kharej services...${NC}\n"
    sleep 1
    # Check if rathole-client-kharej.service exists
    if systemctl list-units --type=service | grep -q "$kharej_service_name"; then
        systemctl restart "$kharej_service_name"
        echo -e "${Cyan}Kharej service restarted.${NC}"
    fi

    # Check if rathole-server-iran.service exists
    if systemctl list-units --type=service | grep -q "$iran_service_name"; then
        systemctl restart "$iran_service_name"
        echo -e "${Cyan}IRAN service restarted.${NC}"
    fi

    # If neither service exists
    if ! systemctl list-units --type=service | grep -q "$kharej_service_name" && \
       ! systemctl list-units --type=service | grep -q "$iran_service_name"; then
        echo -e "${Purple}There is no service to restart.${NC}"
    fi
    
     echo ''
     read -p "Press Enter to continue..."
}

# Function to add cron-tab job
add_cron_job() {
    local reset_path=$1
    local restart_time=$2

    # Save existing crontab to a temporary file
    crontab -l > /tmp/crontab.tmp

    # Append the new cron job to the temporary file
    echo "$restart_time $reset_path # Added by rathole_script" >> /tmp/crontab.tmp

    # Install the modified crontab from the temporary file
    crontab /tmp/crontab.tmp

    # Remove the temporary file
    rm /tmp/crontab.tmp
}
delete_cron_job() {
    # Delete all cron jobs added by this script
    crontab -l | grep -v '# Added by rathole_script' | crontab -
    rm -f /etc/reset.sh >/dev/null 2>&1
    echo -e "${Cyan}Cron jobs added by this script have been deleted successfully.${NC}"
}


# Main function to add or delete cron job for restarting services
cronjob_main() {
     clear
     # Prompt user for action
    echo -e "Select an option: \n"
    echo -e "${Cyan}1. Add a cron-job to restart a service${NC}\n"
    echo -e "${Purple}2. Delete cron jobs added by this script${NC}\n"
    read -p "Enter your choice: " action_choice
    echo ''
    # Validate user input
    case $action_choice in
        1)
            add_cron_job_menu
            ;;
        2)
            delete_cron_job
            ;;
        *)
            echo -e "${Purple}Invalid choice. Please enter 1 or 2.${NC}"
            return 1
            ;;
    esac
    echo ''
    read -p "Press Enter to continue..."
}

add_cron_job_menu() {
    clear
    # Prompt user to choose a service
    echo -e "Select the service you want to restart:\n"
    echo -e "${Cyan}1. Kharej service${NC}"
    echo -e "${Cyan}2. IRAN service${NC}"
    echo ''
    read -p "Enter your choice: " service_choice
    echo ''
    # Validate user input
    case $service_choice in
        1)
            service_name="$kharej_service_name"
            ;;
        2)
            service_name="$iran_service_name"
            ;;
        *)
            echo -e "${Purple}Invalid choice. Please enter 1 or 2.${NC}"
            return 1
            ;;
    esac

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
    delete_cron_job > /dev/null 2>&1
    
    # Path ro reset file
    reset_path='/etc/reset.sh'
    
    #add cron job to kill the running rathole processes
    cat << EOF > "$reset_path"
#! /bin/bash
pids=\$(pgrep rathole)
sudo kill -9 $pids
sudo systemctl daemon-reload
sudo systemctl restart $service_name
EOF

    # make it +x !
    chmod +x "$reset_path"
    
    # Add cron job to restart the specified service at the chosen time
    add_cron_job "$reset_path" "$restart_time"

    echo -e "${Cyan}Cron-job added successfully to restart the service '$service_name'.${NC}"
}

# main maenu for showing ports monitoring options
ports_monitor_menu(){
    clear
    # Prompt user to choose a option
    echo -e "Select the option you want to do:\n"
    echo -e "${Cyan}1. Add ports for monitoring traffic${NC}\n"
    echo -e "${Cyan}2. View traffic usage${NC}\n"
    echo -e "${Purple}3. Remove iptables rules${NC}\n"
    read -p "Enter your choice: " option_choice
    echo ''
    # Validate user input
    case $option_choice in
        1)
			add_iptables_rules
            ;;
        2)
			view_traffic_usage
            ;;
        3)
        	del_iptables_rules
        	;;
        *)
            echo -e "${Purple}Invalid choice. Please enter valid number.${NC}"
            sleep 1
            return 1
            ;;
    esac
}

add_iptables_rules() {
    echo ''
    # Prompt user to enter ports
    read -p "Enter the desired ports separated by commas : " ports
    IFS=',' read -r -a port_array <<< "$ports"
	echo ''
    for port in "${port_array[@]}"; do
        # Check if the entered value is a valid integer
        if grep -wqE '^[0-9]+$' <<< "$port"; then
            # Check if the port with comment "rathole" already exists
            if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT -m comment --comment "rathole" &>/dev/null; then
                iptables -A INPUT -p tcp --dport "$port" -j ACCEPT -m comment --comment "rathole"
                echo -e "${Cyan}Port $port added to iptables.${NC}"
            else
                echo -e "${YELLOW}Port $port already exists in iptables. Skipping...${NC}"
            fi
        else
            echo -e "${Purple}Invalid port number: $port. Skipping...${NC}"
        fi
    done
    echo ''
    echo -e "${Cyan}All desired ports added to iptables successfully${NC}"
    echo ''
    read -p "Press any key to continue..."
}


# Function to draw a horizontal line
draw_line() {
    printf "$+----------+------------+\n"
}

# Function to draw table rows
draw_row() {
    printf "| %-8s | %-10s |\n" "$1" "$2"
}

# Main function to draw the table
view_traffic_usage() {
	clear
    draw_line
    draw_row "Port" "Traffic (B)"
    draw_line
    # Use command substitution to get port numbers dynamically
    ports=$(iptables -L -v --numeric | grep -i -w "rathole" | grep -o 'tcp dpt:[0-9]\+' | awk -F':' '{print $2}')
    # Use command substitution to get traffic information dynamically
    traffic=$(iptables -L -v --numeric | grep -i -w "rathole" | awk '{print $2}')
    for port in $ports; do
        # Find the corresponding traffic value for each port
        index=$(echo $ports | tr ' ' '\n' | grep -n -w $port | cut -d ':' -f1)
        traffic_val=$(echo $traffic | tr ' ' '\n' | sed -n ${index}p)
        draw_row "$port" "$traffic_val"
    done
    draw_line
    echo ''
    read -p "Press any key to continue..."
}

del_iptables_rules(){
	iptables-save | grep -v 'rathole' > /tmp/iptables-filtered.rules
	iptables-restore < /tmp/iptables-filtered.rules
    echo -e "${Cyan}All iptables rules related to this script deleted successfully${NC}"
    echo ''
    read -p "Press any key to continue..."
}

# Function to check the security token
check_security_token() {
echo ''
echo -e "${Purple}IMPORTANT!${NC} ${Cyan}The security token must be same in the iran and kharej server.${NC}\n"

# Check if server.toml exists and update it
if [ -f "$iran_config_file" ]; then
     port=$(cat "$iran_config_file" | grep -oP 'bind_addr = "0\.0\.0\.0:\K[0-9]+' | head -n1)  
     change_security_token "$iran_config_file" "$port"
     restart_services
     return 0
fi

# Check if client.toml exists and update it
if ls $kharej_config_file 1> /dev/null 2>&1; then
     for file in $kharej_config_file; do
         filename=$(basename "$file")   
         change_security_token "$file" "${filename:8:-5}"
         echo -e "${Cyan} _____________________________________________ ${NC}"
	 echo ''
         sleep 1
     done
  restart_services
  return 0
fi

echo -e "${Purple}Configs files not found!${NC}\n"
read -p "Press any key to continue..."
}

# Function to update the security token
change_security_token() {
  local file_path=$1
  local port_num=$2

  # Show the current token
  current_token=$(grep -Po '(?<=^default_token = ")[^"]*' "$file_path")
  if [ -z "$current_token" ]; then
    echo -e "${Purple}default_token not found in $file_path${NC}"
    return 1
  fi
  
  echo -e "${Cyan}Current tunnel port number:${NC} ${MAGENTA}$port_num${NC}"  
  echo -e "${Cyan}Current token:${NC} ${MAGENTA}$current_token${NC}"
  echo ''
  random_token=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32)
  echo -e "${Cyan}Random generated token:${NC} ${MAGENTA}$random_token${NC}"
  echo ''
  # Ask user for new token
  read -p "Enter new token (or press Enter to use default value): " new_token

  # Set default token if user didn't enter anything
  if [ -z "$new_token" ]; then
    new_token="iPmart_tunnel"
  fi

  # Update the token in the file
  sed -i "s/^default_token = \".*\"/default_token = \"$new_token\"/" "$file_path"
  echo''
  echo -e "${Cyan}Token updated successfully in $file_path${NC}\n"
}

update_script(){
# Define the destination path
DEST_DIR="/usr/bin/"
RATHOLE_SCRIPT="rathole"
SCRIPT_URL="https://github.com/iPmartNetwork/RatholeTunnel/raw/main/test2.sh"

echo ''
# Check if rathole.sh exists in /bin/bash
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
echo -e "${Cyan}Downloading the new $RATHOLE_SCRIPT from $SCRIPT_URL...${NC}"

curl -s -L -o "$DEST_DIR/$RATHOLE_SCRIPT" "$SCRIPT_URL"

echo ''
if [ $? -eq 0 ]; then
    echo -e "${Cyan}New $RATHOLE_SCRIPT has been successfully downloaded to $DEST_DIR.${NC}\n"
    chmod +x "$DEST_DIR/$RATHOLE_SCRIPT"
    echo -e "${Cyan}Please exit the script and type 'rathole' to run it again${NC}\n"
    read -p "Press any key to continue..."
    exit 0
else
    echo -e "${Purple}Failed to download $RATHOLE_SCRIPT from $SCRIPT_URL.${NC}"
    sleep 1
    return 1
fi

}

# Color codes
Purple='\033[0;35m'
Cyan='\033[0;36m'
YELLOW='\033[0;33m'
White='\033[0;96m'
MAGENTA="\e[95m"
RED='\033[0;35m'
NC='\033[0m' # No Color

# Function to display menu
display_menu() {
    clear
    display_logo
    display_server_info
    display_rathole_core_status
    echo ''
    echo -e "${White}1. Install Rathole Core${NC}"
    echo -e "${Cyan}2. Configure tunnel${NC}"
    echo -e "${White}3. Destroy tunnel${NC}"
    echo -e "${Cyan}4. Check tunnel status${NC}"
    echo -e "${White}5. Restart services${NC}"
    echo -e "${Cyan}6. Add & remove cron-job reset timer"
    echo -e "${White}7. Port traffic monitoring"
    echo -e "${Cyan}8. update_script"
    echo -e "${White}9. exit 0"
    echo ''
    echo "-------------------------------"
}

# Function to read user input
read_option() {
    read -p "Enter your choice [1-9]: " choice
    case $choice in
        1) download_and_extract_rathole ;;
        2) configure_tunnel ;;
        3) destroy_tunnel ;;
        4) check_tunnel_status ;;
        5) restart_services ;;
        6) cronjob_main ;;
        7) ports_monitor_menu ;;
        8) update_script ;;
        9) exit 0 ;;
        *) echo -e "${Purple}Invalid option!${NC}" && sleep 1 ;;
    esac
}

# Main script
while true
do
    display_menu
    read_option
done
