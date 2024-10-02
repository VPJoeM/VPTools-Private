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

# Create a temporary inventory file
temp_inventory=$(mktemp)
echo "[gpu_nodes]" > "$temp_inventory"

echo "Please paste your node information below. Press Ctrl+D when finished:"
node_id=""
private_ip=""
public_ip=""

while IFS= read -r line; do
    if [[ -z "$line" ]]; then
        if [[ -n "$node_id" && -n "$ip" ]]; then
            echo "$node_id ansible_host=$ip" >> "$temp_inventory"
            node_id=""
            private_ip=""
            public_ip=""
        fi
        continue
    fi
    
    if [[ -z "$node_id" ]]; then
        node_id="$line"
    elif [[ "$line" =~ ^10\. ]]; then
        private_ip="$line"
    elif [[ "$line" =~ ^147\. ]]; then
        public_ip="$line"
        if [[ "$ip_type" == "public" ]]; then
            ip="$public_ip"
        else
            ip="$private_ip"
        fi
    fi
done

# Add the last node if there's any remaining
if [[ -n "$node_id" && -n "$ip" ]]; then
    echo "$node_id ansible_host=$ip" >> "$temp_inventory"
fi

# Add variables for all hosts
echo "" >> "$temp_inventory"
echo "[gpu_nodes:vars]" >> "$temp_inventory"
echo "ansible_user=ubuntu" >> "$temp_inventory"
echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> "$temp_inventory"
echo "ansible_ssh_private_key_file=\"{{ lookup('env', 'SSH_AUTH_SOCK') }}\"" >> "$temp_inventory"

echo "Inventory file created successfully."

# Function to prompt for directory path
prompt_for_directory() {
    local dir_path
    while true; do
        read -p "Enter the path to the directory containing Ansible playbooks: " dir_path
        
        # Expand the path (resolve ~)
        dir_path=$(eval echo "$dir_path")
        
        if [ -d "$dir_path" ]; then
            echo "$dir_path"
            return 0
        else
            echo "Directory not found: $dir_path"
            echo "Current working directory: $(pwd)"
            echo "Please enter a valid path."
        fi
    done
}

# Prompt for the playbook directory
playbook_dir=$(prompt_for_directory)

# List YAML files in the directory and let user choose
yaml_files=($(find "$playbook_dir" -maxdepth 1 -name "*.yml" -o -name "*.yaml"))
if [ ${#yaml_files[@]} -eq 0 ]; then
    echo "No YAML files found in the specified directory: $playbook_dir"
    echo "Files in the directory:"
    ls -la "$playbook_dir"
    exit 1
fi

echo "Available playbooks:"
for i in "${!yaml_files[@]}"; do
    echo "$((i+1)). $(basename "${yaml_files[$i]}")"
done

while true; do
    read -p "Enter the number of the playbook you want to run: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#yaml_files[@]}" ]; then
        playbook_path="${yaml_files[$((choice-1))]}"
        break
    else
        echo "Invalid choice. Please enter a number between 1 and ${#yaml_files[@]}."
    fi
done

# Run the Ansible playbook
echo "Running Ansible playbook: $(basename "$playbook_path")..."
ansible-playbook -i "$temp_inventory" "$playbook_path"

# Clean up
rm "$temp_inventory"
echo "Temporary inventory file removed."