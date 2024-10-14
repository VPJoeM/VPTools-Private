#!/bin/bash

set -x  # Enable debugging

select_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    local key_types=("id_rsa" "id_dsa" "id_ecdsa" "id_ed25519")
    local found_keys=()

    echo "Searching for SSH keys in $ssh_dir"

    # Search for keys in the default location
    for type in "${key_types[@]}"; do
        if [ -f "$ssh_dir/$type" ]; then
            echo "Found key: $ssh_dir/$type"
            found_keys+=("$ssh_dir/$type")
        fi
    done

    # Search for additional keys with common SSH key file extensions
    while IFS= read -r -d '' file; do
        if [[ "$file" =~ \.(pem|key)$ ]] && [[ ! " ${found_keys[@]} " =~ " ${file} " ]]; then
            echo "Found additional key: $file"
            found_keys+=("$file")
        fi
    done < <(find "$ssh_dir" -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "authorized_keys" ! -name "config" -print0)

    # Display found keys
    if [ ${#found_keys[@]} -eq 0 ]; then
        echo "No SSH keys found in $ssh_dir"
    else
        echo "Found SSH keys:"
        for i in "${!found_keys[@]}"; do
            echo "$((i+1)). ${found_keys[$i]}"
        done
    fi

    echo "Debug: Number of keys found: ${#found_keys[@]}"

    # Allow user to select a key or enter a custom path
    while true; do
        read -p "Select a key number, or enter a custom path (or 'q' to quit): " selection
        if [[ "$selection" == "q" ]]; then
            echo "Exiting script."
            exit 0
        elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#found_keys[@]}" ]; then
            SSH_KEY="${found_keys[$((selection-1))]}"
            break
        elif [ -f "$selection" ]; then
            SSH_KEY="$selection"
            break
        else
            echo "Invalid selection or file not found. Please try again."
        fi
    done

    # Verify the selected key
    if [ -r "$SSH_KEY" ]; then
        echo "Selected SSH key: $SSH_KEY"
    else
        echo "Error: Unable to read the SSH key at $SSH_KEY"
        exit 1
    fi
}

# Call the function
select_ssh_key

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

temp_inventory=$(mktemp)
echo "[gpu_nodes]" > "$temp_inventory"

# Set default username
ssh_user="ubuntu"

# Ask if user wants to use a custom username
read -p "Do you want to use a custom username? (default is 'ubuntu') [y/N]: " use_custom_user
if [[ $use_custom_user =~ ^[Yy]$ ]]; then
    read -p "Enter custom username: " custom_user
    ssh_user="$custom_user"
fi

echo "Using SSH user: $ssh_user"

echo "Please paste the IP addresses (one per line)."
echo "Press Ctrl+D when finished:"

# Read input and filter for valid IP addresses
mapfile -t input_lines < <(grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')

echo "Finished processing input."
echo ""

valid_ips=()
for ip in "${input_lines[@]}"; do
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        valid=true
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                valid=false
                break
            fi
        done
        if $valid; then
            valid_ips+=("$ip")
            echo "Valid IP found: $ip"
        else
            echo "Skipping invalid IP: $ip"
        fi
    else
        echo "Skipping invalid input: $ip"
    fi
done

if [ ${#valid_ips[@]} -eq 0 ]; then
    echo "Error: No valid IP addresses found. Please check your input and try again."
    exit 1
fi

echo "Processing ${#valid_ips[@]} valid IP addresses."

for public_ip in "${valid_ips[@]}"; do
    check_server "$public_ip" "$ssh_user"
done

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

find_yaml_files() {
    find "$1" -maxdepth 1 -name "*.yml" -o -name "*.yaml"
}

current_dir=$(pwd)
playbook_dir="$current_dir/voltagepark-collab/nccl_testing"

if [ ! -d "$playbook_dir" ]; then
    echo "Playbook directory not found. Using current directory."
    playbook_dir="$current_dir"
fi

yaml_files=($(find_yaml_files "$playbook_dir"))

if [ ${#yaml_files[@]} -eq 0 ]; then
    echo "No YAML files found in $playbook_dir"
    exit 1
fi

echo "Available playbooks:"
echo "NOTE: You most likely want to choose the option for mlx_ofed_lts_play.yml"
echo "--------------------------------------------------------------------"
for i in "${!yaml_files[@]}"; do
    echo "$((i+1)). $(basename "${yaml_files[$i]}")"
done

while true; do
    read -p "Enter the number of the playbook you want to run: " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#yaml_files[@]}" ]; then
        selected_playbook="${yaml_files[$((selection-1))]}"
        break
    else
        echo "Invalid selection. Please enter a number between 1 and ${#yaml_files[@]}."
    fi
done

echo "You selected: $selected_playbook"
echo "Selected playbook: $selected_playbook"
echo "Using inventory file: $temp_inventory"

echo "Running Ansible playbook..."

# Run the Ansible playbook and save the raw output to a variable
NCCL_TEST_RESULTS=$(ansible-playbook -i "$temp_inventory" "$selected_playbook")

# Check if the ansible-playbook command executed successfully
if [ $? -ne 0 ]; then
    echo "Error: Ansible playbook execution failed."
    exit 1
fi

# Clean up temporary files
rm "$temp_inventory"

echo "Temporary files removed."
echo "Parsing results..."

# Embedded Python script to parse the results
python3 << END
import re
import sys

def parse_nccl_output(content):
    tests = re.findall(r'# nThread.*?# Out of bounds.*?# Avg bus bandwidth.*?#', content, re.DOTALL)

    for test in tests:
        test_name = re.search(r'/build/(\w+)', test)
        if test_name:
            print(f"\nResults for {test_name.group(1)}:")
            print("=" * 40)

        headers = re.search(r'#\s+size.*?#', test, re.DOTALL)
        if headers:
            print(headers.group().strip())

        results = re.findall(r'^\s*\d.*', test, re.MULTILINE)
        for result in results:
            print(result.strip())

        out_of_bounds = re.search(r'# Out of bounds.*', test)
        if out_of_bounds:
            print(out_of_bounds.group().strip())

        avg_bandwidth = re.search(r'# Avg bus bandwidth.*', test)
        if avg_bandwidth:
            print(avg_bandwidth.group().strip())

# Read the NCCL_TEST_RESULTS from the environment variable
nccl_output = '''$NCCL_TEST_RESULTS'''
parse_nccl_output(nccl_output)
END

echo "Script completed."

# Function to parse and display results
parse_results() {
    echo "Parsing results..."
    
    # Get the hostname
    local hostname=$(hostname)
    
    echo "SINGLE NODE TESTS (Node: $hostname)"
    echo "-------------------------------------"
    
    echo "1. Single Node All-Reduce Test"
    echo "Description: Measures the performance of the all-reduce operation on a single node."
    echo "$NCCL_TEST_RESULTS" | sed -n '/^#.*size.*time.*algbw.*busbw/,/^# Out of bounds values : 0 OK$/p' | head -n 13
    
    echo "2. Single Node All-Gather Test"
    echo "Description: Evaluates the all-gather operation performance within a single node."
    echo "$NCCL_TEST_RESULTS" | sed -n '0,/^# Out of bounds values : 0 OK$/p' | tail -n 13 | head -n 13
    
    echo "3. Single Node Reduce-Scatter Test"
    echo "Description: Tests the reduce-scatter operation efficiency on a single node."
    echo "$NCCL_TEST_RESULTS" | sed -n '0,/^# Out of bounds values : 0 OK$/p' | tail -n 13 | head -n 13
    
    echo "CLUSTER WIDE TESTS"
    echo "------------------"
    
    echo "4. Multi-Node All-Reduce Test"
    echo "Description: Assesses the all-reduce operation across multiple nodes in the cluster."
    echo "$NCCL_TEST_RESULTS" | sed -n '0,/^# Out of bounds values : 0 OK$/p' | tail -n 13 | head -n 13
    
    echo "5. Multi-Node All-Gather Test"
    echo "Description: Measures the all-gather operation performance across the entire cluster."
    echo "$NCCL_TEST_RESULTS" | sed -n '0,/^# Out of bounds values : 0 OK$/p' | tail -n 13 | head -n 13
    
    echo "6. Multi-Node Reduce-Scatter Test"
    echo "Description: Evaluates the reduce-scatter operation efficiency across multiple nodes."
    echo "$NCCL_TEST_RESULTS" | sed -n '0,/^# Out of bounds values : 0 OK$/p' | tail -n 13 | head -n 13
}
