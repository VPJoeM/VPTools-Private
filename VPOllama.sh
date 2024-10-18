#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting full Ollama setup on NVIDIA H100 node..."

# Step 1: Update the system and install prerequisites
echo "Updating system and installing prerequisites..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl apt-transport-https ca-certificates software-properties-common

# Step 2: Install Docker
if ! [ -x "$(command -v docker)" ]; then
  echo "Docker not found, installing Docker..."
  # Add Docker’s official GPG key and set up the stable repository
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io

  # Enable and start Docker
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "Docker is already installed, skipping Docker installation."
fi

# Step 3: Install NVIDIA Container Toolkit (if needed)
if ! [ -x "$(command -v nvidia-container-runtime)" ]; then
  echo "Installing NVIDIA Container Toolkit..."
  distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
  curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
  curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

  sudo apt-get update -y
  sudo apt-get install -y nvidia-container-toolkit

  # Restart Docker to apply changes
  sudo systemctl restart docker
fi

# Step 4: Pull the latest Ollama Docker image and start the container
echo "Pulling and deploying the Ollama container..."
docker pull ghcr.io/open-webui/open-webui:ollama

# Stop any running Ollama container
docker stop open-webui || true
docker rm open-webui || true

# Run the container using your working command
docker run -d -p 3000:8080 --gpus=all -v ollama:/root/.ollama -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:ollama

# Step 5: Download Ollama model inside the running container
echo "Downloading the latest Ollama model inside the container..."
docker exec -it open-webui ollama pull llama3.2

echo "Ollama setup complete. Web UI should be available on port 3000."
