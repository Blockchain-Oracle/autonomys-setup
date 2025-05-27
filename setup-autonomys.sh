#!/bin/bash

# 🚀 Autonomys Network Node & Farmer Setup Script
# This script will detect your OS, install Docker & Docker Compose,
# then set up your Autonomys node and farmer.

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

# --------------------------------------------------
# 1) Detect OS
# --------------------------------------------------
detect_os() {
    if [ -e /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_VERSION_ID=$VERSION_ID
        echo "🔍 Detected OS: $PRETTY_NAME"
    else
        echo "❌ Cannot detect operating system."
        exit 1
    fi
}

# --------------------------------------------------
# 2) Install Docker
# --------------------------------------------------
install_docker() {
    case "$OS_ID" in
        ubuntu|debian)
            echo "📦 Installing Docker on $OS_ID..."
            sudo apt update
            sudo apt install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            sudo install -m0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS_ID/gpg \
                | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            echo \
              "deb [arch=$(dpkg --print-architecture) \
              signed-by=/etc/apt/keyrings/docker.gpg] \
              https://download.docker.com/linux/$OS_ID \
              $(lsb_release -cs) stable" \
              | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io
            ;;
        centos|rhel)
            echo "📦 Installing Docker on $OS_ID..."
            sudo yum install -y yum-utils
            sudo yum-config-manager \
                --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io
            ;;
        fedora)
            echo "📦 Installing Docker on Fedora..."
            sudo dnf -y install dnf-plugins-core
            sudo dnf config-manager \
                --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io
            ;;
        *)
            echo "❌ Unsupported operating system: $OS_ID"
            exit 1
            ;;
    esac
    check_success "Docker installation"
}

# --------------------------------------------------
# 3) Install Docker Compose
# --------------------------------------------------
install_docker_compose() {
    echo "🔧 Installing Docker Compose plugin..."
    # Docker Compose as a plugin:
    if ! docker compose version &>/dev/null; then
        sudo apt update || true  # ensure cache exists on apt-based
        sudo apt install -y curl || true
        sudo curl -SL \
          "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
          -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    check_success "Docker Compose installation"
}

# --------------------------------------------------
# Perform detection & installs
# --------------------------------------------------
detect_os
install_docker
install_docker_compose

# Add user to docker group
echo "👤 Adding user to docker group..."
sudo usermod -aG docker $USER
check_success "User added to docker group"

# Start and enable Docker service
echo "🚀 Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker
check_success "Docker service started"

# --------------------------------------------------
# 4) Gather system info & verify hardware
# --------------------------------------------------
echo ""
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

WARNINGS=0
echo "🔍 Checking hardware requirements..."
if [ "$CPU_CORES" -lt 4 ]; then
    echo "⚠️  WARNING: Only $CPU_CORES CPU cores detected (min: 4)"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ CPU cores: $CPU_CORES"
fi
if [ "$RAM_GB" -lt 8 ]; then
    echo "⚠️  WARNING: Only ${RAM_GB}GB RAM detected (min: 8GB)"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ RAM: ${RAM_GB}GB"
fi

SYSTEM_RESERVE=8
NODE_STORAGE=100
TOTAL_RESERVE=$((SYSTEM_RESERVE + NODE_STORAGE))

echo ""
echo "💾 Disk Space Analysis:"
echo " • Available: ${AVAILABLE_SPACE}GB"
echo " • Node storage req’d: ${NODE_STORAGE}GB"
echo " • System reserve: ${SYSTEM_RESERVE}GB"
echo " • Total reserved: ${TOTAL_RESERVE}GB"

if [ "$AVAILABLE_SPACE" -gt "$TOTAL_RESERVE" ]; then
    RECOMMENDED_SIZE=$((AVAILABLE_SPACE - TOTAL_RESERVE))
    echo " • Recommended farming size: ${RECOMMENDED_SIZE}GB"
else
    RECOMMENDED_SIZE=100
    echo "⚠️  Insufficient disk! Using min 100GB."
    WARNINGS=$((WARNINGS + 1))
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "🚨 $WARNINGS hardware warning(s). See requirements: https://docs.autonomys.xyz/farming/intro"
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo "❌ Aborting. Please upgrade hardware."
        exit 1
    fi
fi

# --------------------------------------------------
# 5) Prompt for user input
# --------------------------------------------------
echo ""
read -p "🔑 Talisman reward address: " REWARD_ADDRESS
[ -z "$REWARD_ADDRESS" ] && { echo "❌ Reward address required!"; exit 1; }

echo ""
read -p "💾 Farming size in GB (min 100, rec ${RECOMMENDED_SIZE}): " FARMING_SIZE
if [ -z "$FARMING_SIZE" ]; then
    FARMING_SIZE=$RECOMMENDED_SIZE
elif [ "$FARMING_SIZE" -lt 100 ]; then
    read -p "⚠️  ${FARMING_SIZE}GB is below min. Continue? (y/N): " OK
    [[ ! "$OK" =~ ^[Yy]$ ]] && { echo "❌ Choose ≥100GB."; exit 1; }
fi

echo ""
read -p "📛 Node name (default: my-autonomys-node): " NODE_NAME
NODE_NAME=${NODE_NAME:-my-autonomys-node}

# --------------------------------------------------
# 6) Scaffold project
# --------------------------------------------------
echo ""
echo "📁 Creating project directory..."
mkdir -p ~/autonomys-network
cd ~/autonomys-network

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

# Management scripts
for script in start stop logs status; do
  cat > ${script}.sh << 'EOF'
#!/bin/bash
EOF
done

# start.sh
cat > start.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Autonomys Network..."
sudo docker compose up -d
echo "✅ Services started!"
EOF

# stop.sh
cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping Autonomys Network..."
sudo docker compose down
echo "✅ Services stopped!"
EOF

# logs.sh
cat > logs.sh << 'EOF'
#!/bin/bash
echo "📋 Showing logs..."
sudo docker compose logs --tail=1000 -f
EOF

# status.sh
cat > status.sh << 'EOF'
#!/bin/bash
echo "📊 Network Status:"
sudo docker compose ps
echo ""
echo "💾 Disk Usage:"
df -h /
echo ""
echo "🐳 Docker System Info:"
sudo docker system df
EOF

chmod +x *.sh
check_success "Management scripts created"

# Pull & launch
echo "📥 Pulling images..."
sudo docker compose pull
check_success "Images pulled"

echo "🚀 Launching services..."
sudo docker compose up -d
check_success "Services launched"

# Final summary
cat << EOF

🎉 SUCCESS! Autonomys Network is running.

📊 Configuration:
 • Node Name:     $NODE_NAME
 • Reward Addr:   $REWARD_ADDRESS
 • Farming Size:  ${FARMING_SIZE}GB
 • CPU Cores:     $CPU_CORES
 • RAM:           ${RAM_GB}GB
 • Disk Avail:    ${AVAILABLE_SPACE}GB

🔧 Commands:
 • ./status.sh   → status
 • ./logs.sh     → live logs
 • ./stop.sh     → stop
 • ./start.sh    → restart

⚠️  You may need to log out/in for docker group changes to apply.
🌐 Your node will sync & begin farming automatically.
💰 Rewards → $REWARD_ADDRESS

Happy farming! 🚜✨
EOF
