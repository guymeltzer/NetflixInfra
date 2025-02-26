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


cat << EOF > /home/ubuntu/datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF


cat << EOF > /home/ubuntu/dashboards.yml
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Create default_dashboard.json file
cat << EOF > /home/ubuntu/default_dashboard.json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 9,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "up",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Uptime",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "schemaVersion": 22,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Default Dashboard",
  "uid": null,
  "variables": {
    "list": []
  },
  "version": 0
}
EOF

# Clone the repository containing the docker-compose.y`ml file
git clone https://github.com/guymeltzer/NetflixInfra.git
cd NetflixInfra

# Copy the configuration files to the correct location
sudo cp /home/ubuntu/prometheus.yml ./prometheus.yml
sudo cp /home/ubuntu/nginx.conf ./nginx.conf

# Copy the new configuration files
sudo cp /home/ubuntu/datasources.yml ./datasources.yml
sudo cp /home/ubuntu/dashboards.yml ./dashboards.yml
sudo cp /home/ubuntu/default_dashboard.json ./default_dashboard.json

# Copy docker-compose.yml (if needed)
sudo cp /home/ubuntu/docker-compose.yml ./docker-compose.yml
sudo chown -R 472:472 ./datasources.yml ./dashboards.yml ./default_dashboard.json
sudo chown 472:472 /home/ubuntu/datasources.yml /home/ubuntu/dashboards.yml /home/ubuntu/default_dashboard.json

# Log in to Docker Hub
echo "Candy2025!" | docker login -u "guymeltzer" --password-stdin

# Start the Netflix stack using Docker Compose
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}"
sudo docker-compose up -d