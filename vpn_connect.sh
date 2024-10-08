#!/bin/bash

# Ensure the script is running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

# Check if VPN_USER is set. If not, prompt the user to enter it.
if [ -z "$VPN_USER" ]; then
    read -p "Enter your VPN username: " VPN_USER

    # Ask if the user wants to save the VPN_USER for future runs
    read -p "Do you want to save this VPN username for future runs? (y/n): " save_choice

    if [ "$save_choice" = "y" ] || [ "$save_choice" = "Y" ]; then
        # Save the VPN_USER in the script file itself (assumes the script is executable and writable)
        sed -i '' "s/^VPN_USER=\".*\"/VPN_USER=\"$VPN_USER\"/" "$0"
        echo "VPN username saved to the script."
    else
        echo "VPN username not saved. You will be asked for it again in the future."
    fi
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
# If these are not filled in, the script will prompt for them.
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
                    echo "WARNING: Saving passwords is a security risk! If your device is lost, stolen, or compromised by malware, your VPN credentials could be exposed."
                    sed -i '' "s/^EVOQUE_PASS=\".*\"/EVOQUE_PASS=\"$VPN_PASS\"/" "$0"
                    echo "VPN password for Evoque saved to the script."
                else
                    echo "VPN password not saved. You will be asked for it again in the future."
                fi
            else
                VPN_PASS=$EVOQUE_PASS
            fi
            ;;
        "cyxtera")
            if [ -z "$CYXTERA_PASS" ]; then
                read -sp "Enter the VPN password for Cyxtera: " VPN_PASS
                echo
                read -p "Do you want to save this password for future runs? (y/n): " save_pass_choice
                if [ "$save_pass_choice" = "y" ] || [ "$save_pass_choice" = "Y" ]; then
                    echo "WARNING: Saving passwords is a security risk! If your device is lost, stolen, or compromised by malware, your VPN credentials could be exposed."
                    sed -i '' "s/^CYXTERA_PASS=\".*\"/CYXTERA_PASS=\"$VPN_PASS\"/" "$0"
                    echo "VPN password for Cyxtera saved to the script."
                else
                    echo "VPN password not saved. You will be asked for it again in the future."
                fi
            else
                VPN_PASS=$CYXTERA_PASS
            fi
            ;;
        "cyxtera_mgmt")
            if [ -z "$CYXTERA_MGMT_PASS" ]; then
                read -sp "Enter the VPN password for Cyxtera Management: " VPN_PASS
                echo
                read -p "Do you want to save this password for future runs? (y/n): " save_pass_choice
                if [ "$save_pass_choice" = "y" ] || [ "$save_pass_choice" = "Y" ]; then
                    echo "WARNING: Saving passwords is a security risk! If your device is lost, stolen, or compromised by malware, your VPN credentials could be exposed."
                    sed -i '' "s/^CYXTERA_MGMT_PASS=\".*\"/CYXTERA_MGMT_PASS=\"$VPN_PASS\"/" "$0"
                    echo "VPN password for Cyxtera Management saved to the script."
                else
                    echo "VPN password not saved. You will be asked for it again in the future."
                fi
            else
                VPN_PASS=$CYXTERA_MGMT_PASS
            fi
            ;;
        "h5")
            if [ -z "$H5_PASS" ]; then
                read -sp "Enter the VPN password for H5: " VPN_PASS
                echo
                read -p "Do you want to save this password for future runs? (y/n): " save_pass_choice
                if [ "$save_pass_choice" = "y" ] || [ "$save_pass_choice" = "Y" ]; then
                    echo "WARNING: Saving passwords is a security risk! If your device is lost, stolen, or compromised by malware, your VPN credentials could be exposed."
                    sed -i '' "s/^H5_PASS=\".*\"/H5_PASS=\"$VPN_PASS\"/" "$0"
                    echo "VPN password for H5 saved to the script."
                else
                    echo "VPN password not saved. You will be asked for it again in the future."
                fi
            else
                VPN_PASS=$H5_PASS
            fi
            ;;
        "cyrusone_mgmt")
            if [ -z "$CYRUSONE_MGMT_PASS" ]; then
                read -sp "Enter the VPN password for CyrusOne Management: " VPN_PASS
                echo
                read -p "Do you want to save this password for future runs? (y/n): " save_pass_choice
                if [ "$save_pass_choice" = "y" ] || [ "$save_pass_choice" = "Y" ]; then
                    echo "WARNING: Saving passwords is a security risk! If your device is lost, stolen, or compromised by malware, your VPN credentials could be exposed."
                    sed -i '' "s/^CYRUSONE_MGMT_PASS=\".*\"/CYRUSONE_MGMT_PASS=\"$VPN_PASS\"/" "$0"
                    echo "VPN password for CyrusOne Management saved to the script."
                else
                    echo "VPN password not saved. You will be asked for it again in the future."
                fi
            else
                VPN_PASS=$CYRUSONE_MGMT_PASS
            fi
            ;;
        "ftw1")
            if [ -z "$FTW1_PASS" ]; then
                read -sp "Enter the VPN password for FTW1: " VPN_PASS
                echo
                read -p "Do you want to save this password for future runs? (y/n): " save_pass_choice
                if [ "$save_pass_choice" = "y" ] || [ "$save_pass_choice" = "Y" ]; then
                    echo "WARNING: Saving passwords is a security risk! If your device is lost, stolen, or compromised by malware, your VPN credentials could be exposed."
                    sed -i '' "s/^FTW1_PASS=\".*\"/FTW1_PASS=\"$VPN_PASS\"/" "$0"
                    echo "VPN password for FTW1 saved to the script."
                else
                    echo "VPN password not saved. You will be asked for it again in the future."
                fi
            else
                VPN_PASS=$FTW1_PASS
            fi
            ;;
        "support_access")
            if [ -z "$SUPPORT_ACCESS_PASS" ]; then
                read -sp "Enter the VPN password for Support Access: " VPN_PASS
                echo
                read -p "Do you want to save this password for future runs? (y/n): " save_pass_choice
                if [ "$save_pass_choice" = "y" ] || [ "$save_pass_choice" = "Y" ]; then
                    echo "WARNING: Saving passwords is a security risk! If your device is lost, stolen, or compromised by malware, your VPN credentials could be exposed."
                    sed -i '' "s/^SUPPORT_ACCESS_PASS=\".*\"/SUPPORT_ACCESS_PASS=\"$VPN_PASS\"/" "$0"
                    echo "VPN password for Support Access saved to the script."
                else
                    echo "VPN password not saved. You will be asked for it again in the future."
                fi
            else
                VPN_PASS=$SUPPORT_ACCESS_PASS
            fi
            ;;
        *)
            echo "Invalid data center"
            exit 1
            ;;
    esac

    # Establish the VPN connection using the provided or stored password
    echo "$VPN_PASS" | sudo openconnect --protocol=gp -u $VPN_USER $1 --servercert $2 --passwd-on-stdin &

    # Wait for the VPN connection to establish
    sleep 5

    # Special handling for Evoque to add IDRAC route
    if [ "$DATACENTER" = "evoque" ]; then
        interface=$(ifconfig | grep -o 'utun[0-9]*' | head -1)  # macOS uses utun interfaces
        if netstat -nr | grep -q '172.16.4.0/22'; then
            sudo route delete 172.16.4.0/22
            echo "Previous IDRAC route cleared."
        fi
        sudo route add 172.16.4.0/22 -interface $interface
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
