#!/bin/bash

# Ensure the script is running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

# Check if VPN_USER is set. If not, prompt the user to enter it.
if [ -z "$VPN_USER" ]; then
    read -p "Enter your VPN username: " VPN_USER
    echo "Your VPN username is $VPN_USER."

    # Give the user the option to manually add the username to the script
    echo "If you wish to save this username for future use, please add the following line to the script directly under the '#!/bin/bash' line:"
    echo "VPN_USER=\"$VPN_USER\""
    echo "This ensures your username will be used automatically next time."
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
    # Check if the password is already set, if not, prompt the user
    case $DATACENTER in
        "evoque")
            if [ -z "$EVOQUE_PASS" ]; then
                read -sp "Enter the VPN password for Evoque: " VPN_PASS
                echo
                read -p "Do you want to save this password for future runs? (y/n): " save_pass_choice
                if [ "$save_pass_choice" = "y" ] || [ "$save_pass_choice" = "Y" ]; then
                    echo "WARNING: Saving passwords is a security risk!"
                    sed -i '' "s/^EVOQUE_PASS=\".*\"/EVOQUE_PASS=\"$VPN_PASS\"/" "$0"
                    echo "VPN password for Evoque saved to the script."
                else
                    echo "VPN password not saved."
                fi
            else
                VPN_PASS=$EVOQUE_PASS
            fi
            ;;
        # Repeat similar checks for other datacenters...
    esac

    # Establish the VPN connection using the provided or stored password
    echo "$VPN_PASS" | sudo openconnect --protocol=gp -u $VPN_USER $1 --servercert $2 --passwd-on-stdin &
    
    # Wait for the VPN connection to establish
    sleep 5
    
    # Special handling for Evoque to add IDRAC route
    if [ "$DATACENTER" = "evoque" ]; then
        # Handle multiple utun interfaces
        utuns=$(ifconfig | grep -o 'utun[0-9]*' | sort -V)

        # If there are multiple utun interfaces, ask the user to choose
        if [ $(echo "$utuns" | wc -l) -gt 1 ]; then
            echo "Available utun interfaces:"
            echo "$utuns"
            read -p "Please select the utun interface to use (or press Enter to select the most recent): " selected_utun

            # If the user made a selection, use it; otherwise, select the most recent
            if [ -n "$selected_utun" ]; then
                interface=$selected_utun
            else
                interface=$(echo "$utuns" | tail -n 1)
            fi
        else
            # If there's only one utun, just use it
            interface=$utuns
        fi

        # Check and set the route
        if netstat -nr | grep -q '172.16.4.0/22'; then
            sudo route delete -net 172.16.4.0/22
            echo "Previous IDRAC route cleared."
        fi
        sudo route add -net 172.16.4.0/22 -interface $interface
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

# Map the user's choice to a data center and connect
case $choice in
    1)
        DATACENTER="h5"
        DC_IP=$h5
        DC_CERT=$h5_CERT
        ;;
    2)
        DATACENTER="evoque"
        DC_IP=$evoque
        DC_CERT=$evoque_CERT
        ;;
    3)
        DATACENTER="cyxtera"
        DC_IP=$cyxtera
        DC_CERT=$cyxtera_CERT
        ;;
    4)
        DATACENTER="cyxtera_mgmt"
        DC_IP=$cyxtera_MGMT
        DC_CERT=$cyxtera_MGMT_CERT
        ;;
    5)
        DATACENTER="cyrusone_mgmt"
        DC_IP=$cyrusone_MGMT
        DC_CERT=$cyrusone_MGMT_CERT
        ;;
    6)
        DATACENTER="ftw1"
        DC_IP=$ftw1
        DC_CERT=$ftw1_CERT
        ;;
    7)
        DATACENTER="support_access"
        DC_IP=$support_access
        DC_CERT=$support_access_CERT
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac

# Call the connect function with the chosen data center details
connect $DC_IP $DC_CERT
