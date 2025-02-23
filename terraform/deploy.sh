#!/bin/bash

# Update and install Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.17.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create necessary directories for volumes
sudo mkdir -p /mnt/ebs/catalog-data /mnt/ebs/prometheus-data /mnt/ebs/grafana-data

# Create prometheus.yml file
cat << EOF > /home/ubuntu/prometheus.yml
global:
  scrape_interval: 15s  # How often to scrape targets by default.
  evaluation_interval: 15s  # How often to evaluate rules.

# A scrape configuration for monitoring Prometheus itself
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']  # Prometheus's own metrics

  - job_name: 'availability-agent'
    static_configs:
      - targets: ['availability-agent:8081']  # Replace with the actual port used by your agent
EOF

# Create nginx.conf file
cat << EOF > /home/ubuntu/nginx.conf
events {
    worker_connections 1024;  # Set the max number of connections per worker
}

http {
    # HTTP context: This is where you define your server blocks
    server {
        listen 8080;  # Nginx will listen on port 80 (inside the container)

        # Define a location block to handle the root URL (frontend)
        location / {
            # Proxy requests to the backend (netflix-frontend) on port 3000
            proxy_pass http://netflix-frontend:3000;  # Ensure the backend service is available
            proxy_set_header Host \$host;  # Set the Host header to the incoming request's host
            proxy_set_header X-Real-IP \$remote_addr;  # Forward the real client IP address
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;  # Preserve the client's original IP
            proxy_set_header X-Forwarded-Proto \$scheme;  # Preserve the original protocol (HTTP/HTTPS)
        }

        # Optional: Define another location block to handle requests to '/api' for the catalog service
    }
}
EOF

# Clone the repository containing the docker-compose.yaml file
git clone https://github.com/guymeltzer/NetflixInfra.git
cd NetflixInfra

# Copy the configuration files to the correct location
sudo cp /home/ubuntu/prometheus.yml ./prometheus.yml
sudo cp /home/ubuntu/nginx.conf ./nginx.conf

# Copy docker-compose.yml (if needed)
sudo cp /path/to/your/docker-compose.yml ./docker-compose.yml

# Log in to Docker Hub
echo "Candy2025!" | docker login -u "guymeltzer" --password-stdin

# Start the Netflix stack using Docker Compose
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}"
sudo docker-compose up -d