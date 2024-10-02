#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Ansible is installed, if not, install it
if ! command_exists ansible; then
    echo "Ansible is not installed. Attempting to install..."
    sudo apt-get update
    sudo apt-get install -y ansible
    if ! command_exists ansible; then
        echo "Failed to install Ansible. Please install it manually and run this script again."
        exit 1
    fi
    echo "Ansible has been successfully installed."
else
    echo "Ansible is already installed."
fi

# Function to prompt for yes/no questions
ask_yes_no() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Check if SSH keys are copied to the Ansible host
if ! ask_yes_no "Have you copied your public and private SSH keys to the Ansible host?"; then
    echo "Please copy your SSH keys to the Ansible host before proceeding."
    exit 1
fi

# Ask about IP type
if ask_yes_no "Are you using public IPs? (If no, we'll assume you're using private IPs)"; then
    ip_type="public"
else
    ip_type="private"
    echo "Note: When using private IPs, ensure you run this playbook from inside the cluster."
fi

# Function to validate IP address
validate_ip() {
    if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Ask for the number of nodes
while true; do
    read -p "How many GPU nodes are you using? " node_count
    if [[ "$node_count" =~ ^[0-9]+$ ]] && [ "$node_count" -gt 0 ]; then
        break
    else
        echo "Please enter a valid number greater than 0."
    fi
done

# Create a temporary inventory file
temp_inventory=$(mktemp)
cat << EOF > "$temp_inventory"
all:
  children:
    gpu_nodes:
      hosts:
EOF

# Prompt for IP addresses
for ((i=1; i<=node_count; i++)); do
    while true; do
        read -p "Enter a name for GPU node $i: " node_name
        read -p "Enter the $ip_type IP address for $node_name: " ip
        if validate_ip "$ip"; then
            echo "        $node_name:" >> "$temp_inventory"
            echo "          ansible_host: $ip" >> "$temp_inventory"
            break
        else
            echo "Invalid IP address. Please try again."
        fi
    done
done

# Add the remaining inventory content
cat << EOF >> "$temp_inventory"
      vars:
        ansible_user: ubuntu
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

  vars:
    ansible_ssh_private_key_file: "{{ lookup('env', 'SSH_AUTH_SOCK') }}"
EOF

echo "Inventory file created successfully."

# Run the Ansible playbook
echo "Running Ansible playbook..."
ansible-playbook -i "$temp_inventory" mix_ofed_lts_play.yml

# Clean up
rm "$temp_inventory"
echo "Temporary inventory file removed."