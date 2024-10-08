#!/bin/bash

# Prompt for username
read -p "Enter the username to create: " username

# Prompt for SSH public key
echo "Please paste the user's SSH public key:"
read ssh_key

# Generate a random password
password=$(openssl rand -base64 12)

# Create the user
sudo useradd -m -s /bin/bash "$username"

# Set the password
echo "$username:$password" | sudo chpasswd

# Add user to sudo group
sudo usermod -aG sudo "$username"

# Create .ssh directory and authorized_keys file
sudo -u "$username" mkdir -p /home/"$username"/.ssh
echo "$ssh_key" | sudo -u "$username" tee /home/"$username"/.ssh/authorized_keys > /dev/null
sudo chmod 700 /home/"$username"/.ssh
sudo chmod 600 /home/"$username"/.ssh/authorized_keys

# Output results
echo "User created successfully!"
echo "Username: $username"
echo "Password: $password"
echo "The user has been added to the sudo group."
echo "The provided SSH public key has been added to the user's authorized_keys file."
