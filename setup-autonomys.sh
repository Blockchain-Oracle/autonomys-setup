#!/bin/bash

# 🚀 Autonomys Network Node & Farmer Setup Script
# This script will install Docker and set up your Autonomys node and farmer

echo "🌟 Welcome to Autonomys Network Setup!"
echo "======================================"
echo ""

# Function to check if command was successful
check_success() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 completed successfully!"
    else
        echo "❌ Error: $1 failed!"
        exit 1
    fi
}

# Detect OS and version
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
        ID=$ID
    else
        echo "❌ Cannot detect OS version. Please ensure you're running a supported Linux distribution."
        exit 1
    fi
    echo "🖥️ Detected OS: $OS $VERSION"
}

# Install Docker based on OS
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "🐳 Installing Docker for $OS..."
        case $ID in
            debian|ubuntu)
                # Remove old versions if they exist
                for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
                    sudo apt-get remove -y $pkg 2>/dev/null || true
                done

                # Add Docker's official GPG key
                sudo apt-get update
                sudo apt-get install -y ca-certificates curl gnupg
                sudo install -m 0755 -d /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                sudo chmod a+r /etc/apt/keyrings/docker.gpg

                # Add the repository to sources list
                echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

                # Install Docker packages
                sudo apt-get update
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                ;;
            fedora|rhel|centos)
                sudo dnf -y install dnf-plugins-core
                sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                ;;
            *)
                echo "❌ Unsupported OS: $OS"
                echo "📝 Please install Docker manually following the official guide:"
                echo "https://docs.docker.com/engine/install/"
                exit 1
                ;;
        esac
        check_success "Docker installation"
    else
        echo "✅ Docker is already installed!"
    fi
}

# Get system information with improved storage detection
get_system_info() {
    echo "📊 Checking system information..."
    
    # Get disk space in bytes and convert to TB/GB
    TOTAL_BYTES=$(df -B1 / | awk 'NR==2{print $2}')
    AVAIL_BYTES=$(df -B1 / | awk 'NR==2{print $4}')
    
    # Convert to TB if > 1024GB
    TOTAL_GB=$(echo "scale=2; $TOTAL_BYTES/1024/1024/1024" | bc)
    AVAIL_GB=$(echo "scale=2; $AVAIL_BYTES/1024/1024/1024" | bc)
    
    if (( $(echo "$TOTAL_GB > 1024" | bc -l) )); then
        TOTAL_SPACE=$(echo "scale=2; $TOTAL_GB/1024" | bc)
        echo "💾 Total disk space: ${TOTAL_SPACE}TB"
    else
        TOTAL_SPACE=$TOTAL_GB
        echo "💾 Total disk space: ${TOTAL_SPACE}GB"
    fi
    
    if (( $(echo "$AVAIL_GB > 1024" | bc -l) )); then
        AVAILABLE_SPACE=$(echo "scale=2; $AVAIL_GB/1024" | bc)
        echo "💽 Available space: ${AVAILABLE_SPACE}TB"
    else
        AVAILABLE_SPACE=$AVAIL_GB
        echo "💽 Available space: ${AVAILABLE_SPACE}GB"
    fi
    
    RAM_GB=$(free -g | awk 'NR==2{print $2}')
    CPU_CORES=$(nproc)
    
    echo "🧠 RAM: ${RAM_GB}GB"
    echo "🖥️  CPU Cores: $CPU_CORES"
    echo ""
}

# Install Docker Compose
install_docker_compose() {
    echo "🔧 Installing Docker Compose..."
    if ! command -v docker-compose &> /dev/null; then
        # First try to use the plugin that comes with Docker
        if command -v docker-compose-plugin &> /dev/null || command -v docker-compose &> /dev/null; then
            echo "✅ Docker Compose plugin is already installed!"
            return
        fi
        
        # If plugin not available, install standalone version
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
        sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        check_success "Docker Compose installation"
    else
        echo "✅ Docker Compose is already installed!"
    fi
}

# Calculate storage sizes with TB support
calculate_storage() {
    # Convert available space to GB for calculations
    if (( $(echo "$AVAILABLE_SPACE > 1024" | bc -l) )); then
        # If space is in TB, convert to GB
        AVAIL_GB=$(echo "scale=2; $AVAILABLE_SPACE * 1024" | bc)
    else
        AVAIL_GB=$AVAILABLE_SPACE
    fi

    # Calculate recommended farming size (70% of available space)
    RECOMMENDED_SIZE=$(echo "scale=0; $AVAIL_GB * 0.7" | bc)
    
    # Ensure minimum requirements are met
    if (( $(echo "$RECOMMENDED_SIZE < 100" | bc -l) )); then
        RECOMMENDED_SIZE=100
    fi

    # Format the display size
    if (( $(echo "$RECOMMENDED_SIZE >= 1024" | bc -l) )); then
        DISPLAY_SIZE=$(echo "scale=2; $RECOMMENDED_SIZE / 1024" | bc)
        echo "💾 Recommended farming size: ${DISPLAY_SIZE}TB"
    else
        echo "💾 Recommended farming size: ${RECOMMENDED_SIZE}GB"
    fi

    return $RECOMMENDED_SIZE
}

# Convert user input to GB
convert_to_gb() {
    local size=$1
    local unit=$2
    
    case $unit in
        [Tt][Bb])
            echo "scale=0; $size * 1024" | bc
            ;;
        [Gg][Bb])
            echo "$size"
            ;;
        *)
            echo "$size"
            ;;
    esac
}

# Get farming size with TB support
get_farming_size() {
    echo "💾 Enter the farming size (e.g., 500GB, 2TB)"
    echo "   Recommended: ${RECOMMENDED_SIZE}GB"
    echo "   Minimum: 100GB"
    read -p "Farming Size: " FARMING_INPUT
    
    # Extract number and unit
    FARMING_NUM=$(echo $FARMING_INPUT | sed 's/[^0-9.]//g')
    FARMING_UNIT=$(echo $FARMING_INPUT | sed 's/[0-9.]//g')
    
    # Convert to GB for internal use
    FARMING_SIZE=$(convert_to_gb $FARMING_NUM $FARMING_UNIT)
    
    if [ -z "$FARMING_SIZE" ]; then
        FARMING_SIZE=$RECOMMENDED_SIZE
        echo "📝 Using recommended size: ${FARMING_SIZE}GB"
    elif [ $(echo "$FARMING_SIZE < 100" | bc -l) -eq 1 ]; then
        echo "⚠️  Warning: ${FARMING_SIZE}GB is below the official minimum of 100GB"
        read -p "Continue with ${FARMING_SIZE}GB? (y/N): " CONFIRM_SIZE
        if [[ ! "$CONFIRM_SIZE" =~ ^[Yy]$ ]]; then
            echo "❌ Please choose a size of 100GB or more"
            exit 1
        fi
    fi
}

# Update system packages based on OS
update_system() {
    echo "🔄 Updating system packages..."
    case $ID in
        debian|ubuntu)
            sudo apt update && sudo apt upgrade -y
            ;;
        fedora|rhel|centos)
            sudo dnf upgrade -y
            ;;
        *)
            echo "⚠️ Unknown package manager. Skipping system update."
            return
            ;;
    esac
    check_success "System update"
}

# Install required packages based on OS
install_required_packages() {
    echo "📦 Installing required packages..."
    case $ID in
        debian|ubuntu)
            sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg bc
            ;;
        fedora|rhel|centos)
            sudo dnf install -y curl dnf-plugins-core bc
            ;;
        *)
            echo "⚠️ Unknown package manager. Please install required packages manually:"
            echo "- curl"
            echo "- bc (GNU calculator)"
            echo "- software-properties-common"
            return
            ;;
    esac
    check_success "Package installation"
}

# Manage system services
manage_service() {
    local service=$1
    local action=$2
    
    # Check if systemd is available
    if command -v systemctl &> /dev/null; then
        sudo systemctl $action $service
    # Check if service command is available
    elif command -v service &> /dev/null; then
        sudo service $service $action
    else
        echo "⚠️ Could not detect init system. Please $action $service manually."
        return 1
    fi
}

# Start and enable Docker service
start_docker() {
    echo "🚀 Starting Docker service..."
    manage_service docker start
    if command -v systemctl &> /dev/null; then
        sudo systemctl enable docker
    fi
    check_success "Docker service started"
}

# Main script starts here
detect_os
get_system_info
calculate_storage

# Update system and install requirements
update_system
install_required_packages

# Install Docker and Docker Compose
install_docker
install_docker_compose

# Configure Docker
start_docker

# Add user to docker group
echo "👤 Adding user to docker group..."
sudo usermod -aG docker $USER
check_success "User added to docker group"

# Create project directory
echo "📁 Creating project directory..."
mkdir -p ~/autonomys-network
cd ~/autonomys-network

# Create docker-compose.yml file
echo "📝 Creating Docker Compose configuration..."
cat > docker-compose.yml << EOF
version: '3.8'

services:
  node:
    image: ghcr.io/autonomys/node:mainnet-2025-may-08
    container_name: autonomys-node
    volumes:
      - node-data:/var/subspace:rw
    ports:
      - "0.0.0.0:30333:30333/tcp"
      - "0.0.0.0:30433:30433/tcp"
    restart: unless-stopped
    command:
      [
        "run",
        "--chain", "mainnet",
        "--base-path", "/var/subspace",
        "--listen-on", "/ip4/0.0.0.0/tcp/30333",
        "--dsn-listen-on", "/ip4/0.0.0.0/tcp/30433",
        "--rpc-cors", "all",
        "--rpc-methods", "unsafe",
        "--rpc-listen-on", "0.0.0.0:9944",
        "--farmer",
        "--name", "$NODE_NAME"
      ]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9944/health"]
      timeout: 5s
      interval: 30s
      retries: 60

  farmer:
    depends_on:
      node:
        condition: service_healthy
    image: ghcr.io/autonomys/farmer:mainnet-2025-may-08
    container_name: autonomys-farmer
    volumes:
      - farmer-data:/var/subspace:rw
    ports:
      - "0.0.0.0:30533:30533/tcp"
    restart: unless-stopped
    command:
      [
        "farm",
        "--node-rpc-url", "ws://node:9944",
        "--listen-on", "/ip4/0.0.0.0/tcp/30533",
        "--reward-address", "$REWARD_ADDRESS",
        "path=/var/subspace,size=${FARMING_SIZE}G"
      ]

volumes:
  node-data:
  farmer-data:
EOF

check_success "Docker Compose file created"

# Create useful scripts
echo "📋 Creating management scripts..."

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Autonomys Network..."
sudo docker-compose up -d
echo "✅ Services started!"
echo "📊 Use 'sudo docker-compose ps' to check status"
EOF
chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping Autonomys Network..."
sudo docker-compose down
echo "✅ Services stopped!"
EOF
chmod +x stop.sh

# Create logs script
cat > logs.sh << 'EOF'
#!/bin/bash
echo "📋 Showing logs (Press Ctrl+C to exit)..."
sudo docker-compose logs --tail=1000 -f
EOF
chmod +x logs.sh

# Create status script
cat > status.sh << 'EOF'
#!/bin/bash
echo "📊 Autonomys Network Status:"
echo "=========================="
sudo docker-compose ps
echo ""
echo "💾 Disk Usage:"
df -h /
echo ""
echo "🐳 Docker System Info:"
sudo docker system df
EOF
chmod +x status.sh

check_success "Management scripts created"

# Pull Docker images
echo "📥 Pulling Docker images (this may take a few minutes)..."
sudo docker-compose pull
check_success "Docker images pulled"

# Start the services
echo "🚀 Starting Autonomys Network services..."
sudo docker-compose up -d
check_success "Services started"

echo ""
echo "🎉 SUCCESS! Autonomys Network is now running!"
echo "============================================="
echo ""
echo "📊 Your Configuration:"
echo "• Node Name: $NODE_NAME"
echo "• Reward Address: $REWARD_ADDRESS"
echo "• Farming Size: ${FARMING_SIZE}GB"
echo "• CPU Cores: $CPU_CORES"
echo "• RAM: ${RAM_GB}GB"
echo "• Available Disk: ${AVAILABLE_SPACE}GB"
echo ""
echo "🔧 Useful Commands:"
echo "• Check status: ./status.sh"
echo "• View logs: ./logs.sh"
echo "• Stop services: ./stop.sh"
echo "• Start services: ./start.sh"
echo ""
echo "📋 Or use Docker Compose directly:"
echo "• sudo docker-compose ps (check status)"
echo "• sudo docker-compose logs --tail=1000 -f (view logs)"
echo "• sudo docker-compose down (stop)"
echo "• sudo docker-compose up -d (start)"
echo ""
echo "⚠️  IMPORTANT: You may need to log out and back in for Docker permissions to take effect!"
echo ""
echo "🌐 Your node will sync with the network and start farming automatically."
echo "💰 Rewards will be sent to: $REWARD_ADDRESS"
echo ""
if [ "$WARNINGS" -gt 0 ]; then
    echo "⚠️  Remember: Your system has hardware warnings. Monitor performance closely."
    echo "📖 Official requirements: https://docs.autonomys.xyz/farming/intro"
    echo ""
fi
echo "Happy farming! 🚜✨"