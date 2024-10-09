#!/bin/bash

set -x  # Enable debugging

# Function to select SSH key
select_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    local keys=($(find "$ssh_dir" -type f -name "id_*" ! -name "*.pub"))

    if [ ${#keys[@]} -eq 0 ]; then
        echo "No SSH keys found in $ssh_dir"
        exit 1
    elif [ ${#keys[@]} -eq 1 ]; then
        echo "Using the only available SSH key: ${keys[0]}"
        SSH_KEY="${keys[0]}"
    else
        echo "Multiple SSH keys found. Please select one:"
        select key in "${keys[@]}"; do
            if [ -n "$key" ]; then
                SSH_KEY="$key"
                break
            else
                echo "Invalid selection. Please try again."
            fi
        done
    fi
}

# Call the function to select SSH key
select_ssh_key

# Array to store hostnames
declare -a hostnames

function check_server {
    local public_ip="$1"
    local ssh_user="$2"
    
    echo "Checking connectivity to IP: $public_ip"
    
    if ping -c 1 -W 2 "$public_ip" > /dev/null 2>&1; then
        echo "Server $public_ip is reachable."
        
        if timeout 10 ssh -n -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "${ssh_user}@${public_ip}" 'echo "SSH successful"' > /dev/null 2>&1; then
            echo "SSH connection to $public_ip successful."
            
            hostname=$(timeout 5 ssh -n -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 "${ssh_user}@${public_ip}" hostname)
            
            if [ -n "$hostname" ]; then
                echo "$hostname ansible_host=$public_ip" >> "$temp_inventory"
                hostnames+=("$hostname")
                echo "Added $hostname to inventory."
            else
                echo "Failed to get hostname for $public_ip. Using IP as hostname."
                echo "$public_ip ansible_host=$public_ip" >> "$temp_inventory"
                hostnames+=("$public_ip")
                echo "Added $public_ip to inventory."
            fi
        else
            echo "SSH connection to $public_ip failed. Please check your SSH key and firewall settings."
        fi
    else
        echo "Server $public_ip is not reachable. Please check your network connection and firewall settings."
    fi
}

# Create a temporary inventory file
temp_inventory=$(mktemp)
echo "[gpu_nodes]" > "$temp_inventory"

# Ask for SSH user
read -p "Enter the SSH user for the remote servers: " ssh_user

echo "Please paste the IP addresses (one per line)."
echo "Press Ctrl+D when finished:"

# Read input into an array
mapfile -t input_lines

echo "Finished processing input."
echo ""

# Process the collected lines
for line in "${input_lines[@]}"; do
    if [[ -n "$line" ]]; then
        echo "Processing line: $line"
        if [[ $line =~ ^147\. ]]; then
            public_ip=$line
            check_server "$public_ip" "$ssh_user"
        else
            echo "Skipping invalid IP: $line"
        fi
    fi
done

# After processing all IPs
if [ ${#hostnames[@]} -eq 0 ]; then
    echo "Error: No valid hosts found. Please check your SSH key, user, and firewall settings."
    exit 1
fi

echo ""
echo "[gpu_nodes:vars]" >> "$temp_inventory"
echo "ansible_user=$ssh_user" >> "$temp_inventory"
echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" >> "$temp_inventory"
echo "ansible_ssh_private_key_file=\"$SSH_KEY\"" >> "$temp_inventory"

echo "Inventory file created successfully."
echo "Final inventory file contents:"
cat "$temp_inventory"

echo "Debug: Collected hostnames: ${hostnames[*]}"

set +x  # Disable debugging

# Function to find YAML files in a directory
find_yaml_files() {
    find "$1" -maxdepth 1 -name "*.yml" -o -name "*.yaml"
}

# Check for playbooks in voltagepark-collab/nccl_testing
current_dir=$(pwd)
playbook_dir="$current_dir/voltagepark-collab/nccl_testing"

if [ ! -d "$playbook_dir" ]; then
    echo "Directory $playbook_dir not found."
    read -p "Enter the path to the directory containing the playbooks: " custom_path
    if [ -d "$custom_path" ]; then
        playbook_dir="$custom_path"
    else
        echo "Invalid directory. Using current directory."
        playbook_dir="$current_dir"
    fi
fi

yaml_files=($(find_yaml_files "$playbook_dir"))

if [ ${#yaml_files[@]} -eq 0 ]; then
    echo "No YAML files found in $playbook_dir."
    echo "Using current directory as a fallback."
    playbook_dir="$current_dir"
    yaml_files=($(find_yaml_files "$playbook_dir"))
fi

# Available playbooks
echo "Available playbooks:"
echo "NOTE: You most likely want to choose the option for mlx_ofed_lts_play.yml"
echo "--------------------------------------------------------------------"
for i in "${!yaml_files[@]}"; do
    echo "$((i+1)). $(basename "${yaml_files[$i]}")"
done

# Select playbook
read -p "Enter the number of the playbook you want to run: " playbook_choice
selected_playbook="${yaml_files[$((playbook_choice-1))]}"

if [ ! -f "$selected_playbook" ]; then
    echo "Invalid selection. Exiting."
    exit 1
fi

echo "Selected playbook: $selected_playbook"

# Ask if user wants to start at a specific task
read -p "Do you want to start at a specific task? (y/n): " start_at_task_choice

if [[ $start_at_task_choice =~ ^[Yy]$ ]]; then
    read -p "Enter the task name to start at: " start_at_task
fi

# Ask for the number of forks
echo "Choose the number of Ansible forks (default is 20):"
read -r -p "Enter the number of forks (5-30, default 20): " forks
forks=${forks:-20}

# Validate forks input
if ! [[ "$forks" =~ ^[0-9]+$ ]] || [ "$forks" -lt 5 ] || [ "$forks" -gt 30 ]; then
    echo "Invalid input. Using default value of 20 forks."
    forks=20
fi

echo "Running Ansible playbook: $selected_playbook"

# Use tee to display output in real-time and capture it
playbook_output_file=$(mktemp)
ansible-playbook -i "$temp_inventory" "$selected_playbook" ${start_at_task:+--start-at-task "$start_at_task"} -f "$forks" -vv | tee "$playbook_output_file"
playbook_exit_code=${PIPESTATUS[0]}

echo "Playbook execution completed with exit code: $playbook_exit_code"

if [ $playbook_exit_code -ne 0 ]; then
    echo "Error: Ansible playbook execution failed with exit code $playbook_exit_code."
    exit $playbook_exit_code
fi

# Function to parse and display NCCL test results
function parse_nccl_results {
    echo "NCCL Test Results Summary:"
    echo "=========================="
    
    if [ -f "$playbook_output_file" ]; then
        # Extract the results for each test
        grep -A 20 "Results for" "$playbook_output_file" | sed 's/^ok: \[g[0-9]*\] => {//' | sed 's/^    "msg": "//' | sed 's/"$//' | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'
    else
        echo "No playbook output file found."
    fi
}

# Call the function to parse and display results
parse_nccl_results

# Clean up
rm "$temp_inventory"
rm "$playbook_output_file"
echo "Temporary files removed."

echo "Script completed successfully."
