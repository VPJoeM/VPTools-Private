#!/bin/bash

# Ensure the script is running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

SCRIPT_PATH=$(realpath "$0")
CONFIG_FILE="$HOME/.vpn_config"

# Function to load passwords from the config file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        touch "$CONFIG_FILE"
    fi
}

# Function to save username and passwords in the script
save_to_script() {
    local var_name="$1"
    local var_value="$2"
    local script="$SCRIPT_PATH"
    
    # If the variable already exists, replace its value, otherwise append it
    if grep -q "^$var_name=" "$script"; then
        sed -i "s|^$var_name=.*|$var_name=\"$var_value\"|" "$script"
    else
        echo "$var_name=\"$var_value\"" >> "$script"
    fi
}

# Load any existing passwords
load_config

# Check if VPN_USER is set. If not, prompt the user to enter it and offer to save it.
if [ -z "$VPN_USER" ]; then
    read -p "Enter your VPN username: " VPN_USER
    echo "Your VPN username is $VPN_USER."

    # Ask if the user wants to save the username
    read -p "Do you want to save your VPN username for future use? (y/n): " save_user
    if [ "$save_user" = "y" ] || [ "$save_user" = "Y" ]; then
        echo "Saving your VPN username..."
        save_to_script "VPN_USER" "$VPN_USER"
    fi
else
    echo "Using saved VPN username: $VPN_USER."
fi

# Prompt the user to kill all running openconnect VPNs
read -p "Do you want to kill all existing openconnect VPNs before continuing? (y/n): " kill_choice

if [ "$kill_choice" = "y" ] || [ "$kill_choice" = "Y" ]; then
    echo "Killing all existing openconnect VPNs..."
    sudo pkill openconnect
    echo "All openconnect VPNs have been killed."
else
    echo "Proceeding without killing existing openconnect VPNs."
fi

# Define data center connection information
evoque="209.249.182.82"
evoque_CERT="pin-sha256:4PBOnwuqOcUVxoHn5MPCOeJlp7TDyoMyV5SciMBHg20="
cyxtera="216.200.147.154"
cyxtera_CERT="pin-sha256:4k0l440p5HOK2oY3D2FVOTujNscoffjhKl82x75PlfA="
cyxtera_MGMT="216.200.15.58"
cyxtera_MGMT_CERT="pin-sha256:2Z/s/bTbk/fL5XpO/r8T47B+UR0stLSOaYvyE1gINj4="
h5="209.249.95.182"
h5_CERT="pin-sha256:7KL7YGPkXKoCtwRSpDgVcl7t6EltY3XviVixK1at8yY="
cyrusone="209.249.240.90"
cyrusone_CERT="pin-sha256:ruDu2cJUzy9rNMnEpLozhh2gyyKCd5ism2fFLBHsM/k"
cyrusone_MGMT="209.249.240.98"
cyrusone_MGMT_CERT="pin-sha256:ruDu2cJUzy9rNMnEpLozhh2gyyKCd5ism2fFLBHsM/k"
ftw1="216.200.147.154"
ftw1_CERT="pin-sha256:4k0l440p5HOK2oY3D2FVOTujNscoffjhKl82x75PlfA="
support_access="216.200.15.58"
support_access_CERT="pin-sha256:2Z/s/bTbk/fL5XpO/r8T47B+UR0stLSOaYvyE1gINj4="

# Optional: Define passwords here
EVOQUE_PASS=""
CYXTERA_PASS=""
CYXTERA_MGMT_PASS=""
H5_PASS=""
CYRUSONE_MGMT_PASS=""
FTW1_PASS=""
SUPPORT_ACCESS_PASS=""

# Function to connect to a data center
connect() {
    # Dynamically set the password prompt based on the selected data center
    case $DATACENTER in
        "evoque")
            DC_NAME="Evoque"
            DC_IP=$evoque
            DC_CERT=$evoque_CERT
            ;;
        "cyxtera")
            DC_NAME="Cyxtera"
            DC_IP=$cyxtera
            DC_CERT=$cyxtera_CERT
            ;;
        "cyxtera_mgmt")
            DC_NAME="Cyxtera Management"
            DC_IP=$cyxtera_MGMT
            DC_CERT=$cyxtera_MGMT_CERT
            ;;
        "h5")
            DC_NAME="H5"
            DC_IP=$h5
            DC_CERT=$h5_CERT
            ;;
        "cyrusone_mgmt")
            DC_NAME="CyrusOne Management"
            DC_IP=$cyrusone_MGMT
            DC_CERT=$cyrusone_MGMT_CERT
            ;;
        "ftw1")
            DC_NAME="FTW1"
            DC_IP=$ftw1
            DC_CERT=$ftw1_CERT
            ;;
        "support_access")
            DC_NAME="Support Access"
            DC_IP=$support_access
            DC_CERT=$support_access_CERT
            ;;
        *)
            echo "Invalid data center"
            exit 1
            ;;
    esac

    # Check if the password is already set, if not, prompt the user for the selected data center
    DATACENTER_PASS="${DATACENTER}_PASS"
    if [ -z "${!DATACENTER_PASS}" ]; then
        read -sp "Enter the VPN password for $DC_NAME: " VPN_PASS
        echo

        # Ask if the user wants to save the password
        read -p "Do you want to save your VPN password for $DC_NAME for future use? (y/n): " save_pass
        if [ "$save_pass" = "y" ] || [ "$save_pass" = "Y" ]; then
            echo "Saving your VPN password for $DC_NAME..."
            save_to_script "${DATACENTER}_PASS" "$VPN_PASS"
        fi
    else
        VPN_PASS=${!DATACENTER_PASS}
    fi

    # Establish the VPN connection using the provided or stored password
    echo "$VPN_PASS" | sudo openconnect --protocol=gp -u $VPN_USER $DC_IP --servercert $DC_CERT --passwd-on-stdin &

    # Wait for the VPN connection to establish
    sleep 5

    # Special handling for Evoque to add IDRAC route
    if [ "$DATACENTER" = "evoque" ]; then
        # Wait for the VPN interface (utun or tunX) to be available
        for i in {1..10}; do
            # Check if any tun or utun interface is available
            interface=$(ip addr show | grep -o 'utun[0-9]*\|tun[0-9]*' | sort -V | tail -n 1)
            if [ -n "$interface" ]; then
                echo "Found VPN interface: $interface"
                break
            else
                echo "Waiting for VPN interface..."
                sleep 1
            fi
        done

        if [ -z "$interface" ]; then
            echo "VPN interface not found. Cannot add IDRAC route."
            exit 1
        fi

        # Check and set the route using ip command
        if ip route | grep -q '172.16.4.0/22'; then
            sudo ip route del 172.16.4.0/22
            echo "Previous IDRAC route cleared."
        fi
        sudo ip route add 172.16.4.0/22 dev "$interface"
        echo "New IDRAC route added for Evoque."
    fi
}

# Stop the VPN connection if CONTROL is set to stop
if [ "$1" = "stop" ]; then
    read -p "Enter the data center (e.g., evoque, cyxtera): " DATACENTER
    test -f /var/tmp/$DATACENTER.pid && kill $(cat /var/tmp/$DATACENTER.pid)
    exit 0
fi

# Display the list of data centers for the user to choose from
echo "Please select a data center:"
echo "1) H5"
echo "2) Evoque"
echo "3) Cyxtera"
echo "4) Cyxtera Management"
echo "5) CyrusOne Management"
echo "6) FTW1/Clusterware-Penguin"
echo "7) Support Access"

# Get the user's choice
read -p "Enter the number of your choice: " choice

# Map the user's choice to a data center
case $choice in
    1)
        DATACENTER="h5"
        ;;
    2)
        DATACENTER="evoque"
        ;;
    3)
        DATACENTER="cyxtera"
        ;;
    4)
        DATACENTER="cyxtera_mgmt"
        ;;
    5)
        DATACENTER="cyrusone_mgmt"
        ;;
    6)
        DATACENTER="ftw1"
        ;;
    7)
        DATACENTER="support_access"
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac

# Call the connect function with the chosen data center details
connect
