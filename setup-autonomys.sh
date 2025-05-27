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

# Get system information
echo "📊 Checking system information..."
TOTAL_SPACE=$(df -h / | awk 'NR==2{print $2}' | sed 's/G//')
AVAILABLE_SPACE=$(df -h / | awk 'NR==2{print $4}' | sed 's/G//')
RAM_GB=$(free -g | awk 'NR==2{print $2}')
CPU_CORES=$(nproc)

echo "💾 Total disk space: ${TOTAL_SPACE}GB"
echo "💽 Available space: ${AVAILABLE_SPACE}GB"
echo "🧠 RAM: ${RAM_GB}GB"
echo "🖥️  CPU Cores: $CPU_CORES"
echo ""

# Check hardware requirements against official specs
echo "🔍 Checking hardware requirements..."
WARNINGS=0

# Check CPU cores (minimum 4)
if [ "$CPU_CORES" -lt 4 ]; then
    echo "⚠️  WARNING: Only $CPU_CORES CPU cores detected. Official minimum: 4 cores"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ CPU cores: $CPU_CORES (meets requirement)"
fi

# Check RAM (minimum 8GB)
if [ "$RAM_GB" -lt 8 ]; then
    echo "⚠️  WARNING: Only ${RAM_GB}GB RAM detected. Official minimum: 8GB"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ RAM: ${RAM_GB}GB (meets requirement)"
fi

# Calculate farming size recommendations
SYSTEM_RESERVE=20      # Space for system operations
NODE_STORAGE=100       # Official node storage requirement
TOTAL_RESERVE=$((SYSTEM_RESERVE + NODE_STORAGE))  # 120GB total

echo ""
echo "💾 Disk Space Analysis:"
echo "• Available space: ${AVAILABLE_SPACE}GB"
echo "• Node storage needed: ${NODE_STORAGE}GB (official requirement)"
echo "• System space needed: ${SYSTEM_RESERVE}GB"
echo "• Total reserved: ${TOTAL_RESERVE}GB"

if [ "$AVAILABLE_SPACE" -gt "$TOTAL_RESERVE" ]; then
    RECOMMENDED_SIZE=$((AVAILABLE_SPACE - TOTAL_RESERVE))
    echo "• Recommended farming size: ${RECOMMENDED_SIZE}GB"
    echo "✅ Sufficient disk space available"
else
    RECOMMENDED_SIZE=100  # Official minimum farming size
    echo "⚠️  WARNING: Insufficient disk space!"
    echo "   Available: ${AVAILABLE_SPACE}GB"
    echo "   Required minimum: $((TOTAL_RESERVE + 100))GB (120GB reserved + 100GB farming)"
    echo "   Your setup may experience issues"
    WARNINGS=$((WARNINGS + 1))
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "🚨 $WARNINGS hardware warning(s) detected!"
    echo "📖 Official requirements: https://docs.autonomys.xyz/farming/intro"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo "❌ Setup cancelled. Please upgrade your hardware to meet requirements."
        exit 1
    fi
fi

echo ""

# Get user inputs
echo "🔑 Please provide your Talisman wallet address for rewards:"
read -p "Reward Address: " REWARD_ADDRESS

if [ -z "$REWARD_ADDRESS" ]; then
    echo "❌ Reward address is required!"
    exit 1
fi

echo ""
echo "💾 Enter the farming size in GB"
echo "   Recommended: ${RECOMMENDED_SIZE}GB"
echo "   Minimum: 100GB (official requirement)"
read -p "Farming Size (GB): " FARMING_SIZE

if [ -z "$FARMING_SIZE" ]; then
    FARMING_SIZE=$RECOMMENDED_SIZE
    echo "📝 Using recommended size: ${FARMING_SIZE}GB"
elif [ "$FARMING_SIZE" -lt 100 ]; then
    echo "⚠️  Warning: ${FARMING_SIZE}GB is below the official minimum of 100GB"
    read -p "Continue with ${FARMING_SIZE}GB? (y/N): " CONFIRM_SIZE
    if [[ ! "$CONFIRM_SIZE" =~ ^[Yy]$ ]]; then
        echo "❌ Please choose a size of 100GB or more"
        exit 1
    fi
fi

echo ""
echo "📛 Enter a name for your node (optional, default: 'my-autonomys-node'):"
read -p "Node Name: " NODE_NAME

if [ -z "$NODE_NAME" ]; then
    NODE_NAME="my-autonomys-node"
fi

echo ""
echo "🔄 Starting installation process..."
echo ""

# Update system
echo "🔄 Updating system packages..."
sudo apt update && sudo apt upgrade -y
check_success "System update"

# Install required packages
echo "📦 Installing required packages..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
check_success "Package installation"

# Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    check_success "Docker installation"
else
    echo "✅ Docker is already installed!"
fi

# Install Docker Compose
echo "🔧 Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    check_success "Docker Compose installation"
else
    echo "✅ Docker Compose is already installed!"
fi

# Add user to docker group
echo "👤 Adding user to docker group..."
sudo usermod -aG docker $USER
check_success "User added to docker group"

# Start and enable Docker
echo "🚀 Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker
check_success "Docker service started"

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