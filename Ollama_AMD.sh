#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting full Ollama setup on AMD-based node..."

# Step 1: Update the system and install prerequisites
echo "Updating system and installing prerequisites..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl apt-transport-https ca-certificates software-properties-common

# Step 2: Install Docker
if ! [ -x "$(command -v docker)" ]; then
  echo "Docker not found, installing Docker..."
  # Add Docker’s official GPG key and set up stable repository
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # Install Docker Engine
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io

  # Enable Docker and start the service
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "Docker is already installed, skipping Docker installation."
fi

# Step 3: Pull the latest Ollama Docker image and start the container
echo "Pulling and deploying the Ollama container..."
docker pull ghcr.io/open-webui/open-webui:ollama

# Stop any running Ollama container
docker stop open-webui || true
docker rm open-webui || true

# Step 4: Run the container with AMD GPU support
docker run -d -p 3000:8080 \
  --device=/dev/kfd:/dev/kfd \
  --device=/dev/dri:/dev/dri \
  -v ollama:/root/.ollama \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:ollama \
  bash -c "ollama pull llama3.2 && ./start-webui.sh"

echo "Ollama setup complete. Web UI should be available on port 3000."
