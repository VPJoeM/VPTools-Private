#!/bin/bash

# Define SSH user, key, and repo information
LOCAL_USER="joe"
SSH_USER="ubuntu"
SSH_KEY="/home/$LOCAL_USER/.ssh/id_ed25519"
SSH_PUBLIC_KEY="/home/$LOCAL_USER/.ssh/id_ed25519.pub"
REPO_URL="git@github.com:voltagepark/voltagepark-collab.git"
TMP_DIR="/tmp"

# Prompt the user for host information
echo "Please paste the hosts information and press Ctrl+D when done:"
HOSTS_INFO=$(cat)

# Extract public IPs that start with "147"
PUBLIC_IPS=$(echo "$HOSTS_INFO" | grep "^147")

# Loop over each public IP, add the SSH keys (both private and public), and then run the commands
for HOST in $PUBLIC_IPS; do
    echo "Adding SSH key to $HOST..."

    # Copy the SSH public key to the remote host's authorized_keys
    ssh -t -i "$SSH_KEY" "$SSH_USER@$HOST" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" < "$SSH_PUBLIC_KEY"
    
    # Copy the SSH private key to the remote host (for git clone)
    scp -i "$SSH_KEY" "$SSH_KEY" "$SSH_USER@$HOST:~/.ssh/id_ed25519"
    
    # Set correct permissions for the private key on the remote host
    ssh -t -i "$SSH_KEY" "$SSH_USER@$HOST" "chmod 600 ~/.ssh/id_ed25519"

    echo "SSH keys added to $HOST. Connecting to $HOST for cloning operations..."

    ssh -t -i "$SSH_KEY" "$SSH_USER@$HOST" << EOF
        # Add GitHub to known hosts to avoid host verification errors
        ssh-keyscan -H github.com >> ~/.ssh/known_hosts

        # Clone the repository to /tmp using the copied SSH key
        GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519" git clone $REPO_URL $TMP_DIR/voltagepark-collab

        # Copy the contents of the src folder to /tmp
        cp -r $TMP_DIR/voltagepark-collab/nccl_testing/src/* $TMP_DIR

        # Clean up by removing the cloned repository
        rm -rf $TMP_DIR/voltagepark-collab

        echo "Done on $HOST."
EOF
done

echo "Script completed for all hosts."
