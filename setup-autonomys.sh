#!/bin/bash

# 🚀 Autonomys Network Node & Farmer Setup Script
# This script will install Docker and set up your Autonomys node and farmer

echo "🌟 Welcome to Autonomys Network Setup!"
echo "======================================"
echo ""

# Initialize variables
WARNINGS=0

# Function to check if command was successful
check_success() {
    if [ $? -eq 0 ]; then
        log_message "✅ $1 completed successfully!"
    else
        log_message "❌ Error: $1 failed!"
        exit 1
    fi
}

# Function to log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to log info messages
log_info() {
    log_message "ℹ️  INFO: $1"
}

# Function to log warning messages
log_warning() {
    log_message "⚠️  WARNING: $1"
    WARNINGS=$((WARNINGS + 1))
}

# Function to log error messages
log_error() {
    log_message "❌ ERROR: $1"
}

# Detect OS and version
detect_os() {
    log_info "Detecting operating system..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
        ID=$ID
    else
        log_error "Cannot detect OS version. Please ensure you're running a supported Linux distribution."
        exit 1
    fi
    echo "🖥️ Detected OS: $OS $VERSION"
    log_info "OS Detection completed: $OS $VERSION"
}

# Install Docker based on OS
install_docker() {
    if ! command -v docker &> /dev/null; then
        log_info "Docker not found, installing Docker for $OS..."
        echo "🐳 Installing Docker for $OS..."
        case $ID in
            debian|ubuntu)
                log_info "Installing Docker for Debian/Ubuntu..."
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
                log_info "Installing Docker for Fedora/RHEL/CentOS..."
                sudo dnf -y install dnf-plugins-core
                sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                ;;
            *)
                log_error "Unsupported OS: $OS"
                echo "❌ Unsupported OS: $OS"
                echo "📝 Please install Docker manually following the official guide:"
                echo "https://docs.docker.com/engine/install/"
                exit 1
                ;;
        esac
        check_success "Docker installation"
    else
        log_info "Docker is already installed"
        echo "✅ Docker is already installed!"
    fi
}

# Get system information with improved storage detection
get_system_info() {
    log_info "Gathering system information..."
    echo "📊 Checking system information..."
    
    # Get disk space in bytes and convert to GB (1 GB = 1000^3 bytes)
    TOTAL_BYTES=$(df -B1 / | awk 'NR==2{print $2}')
    AVAIL_BYTES=$(df -B1 / | awk 'NR==2{print $4}')
    
    # Convert to GB (1 GB = 1000^3 bytes)
    TOTAL_GB=$(echo "scale=2; $TOTAL_BYTES/1000/1000/1000" | bc)
    AVAIL_GB=$(echo "scale=2; $AVAIL_BYTES/1000/1000/1000" | bc)
    
    # Display in TB if > 1000 GB (1TB = 1000GB)
    if (( $(echo "$TOTAL_GB > 1000" | bc -l) )); then
        TOTAL_SPACE=$(echo "scale=2; $TOTAL_GB/1000" | bc)
        echo "💾 Total disk space: ${TOTAL_SPACE}TB"
        log_info "Total disk space: ${TOTAL_SPACE}TB"
    else
        TOTAL_SPACE=$TOTAL_GB
        echo "💾 Total disk space: ${TOTAL_SPACE}GB"
        log_info "Total disk space: ${TOTAL_SPACE}GB"
    fi
    
    if (( $(echo "$AVAIL_GB > 1000" | bc -l) )); then
        AVAILABLE_SPACE=$(echo "scale=2; $AVAIL_GB/1000" | bc)
        echo "💽 Available space: ${AVAILABLE_SPACE}TB"
        log_info "Available space: ${AVAILABLE_SPACE}TB"
    else
        AVAILABLE_SPACE=$AVAIL_GB
        echo "💽 Available space: ${AVAILABLE_SPACE}GB"
        log_info "Available space: ${AVAILABLE_SPACE}GB"
    fi
    
    RAM_GB=$(free -g | awk 'NR==2{print $2}')
    CPU_CORES=$(nproc)
    
    echo "🧠 RAM: ${RAM_GB}GB"
    echo "🖥️  CPU Cores: $CPU_CORES"
    echo ""
    
    log_info "System specs - RAM: ${RAM_GB}GB, CPU Cores: $CPU_CORES"
    
    # Check minimum requirements
    if [ $RAM_GB -lt 4 ]; then
        log_warning "RAM is below recommended 4GB (found ${RAM_GB}GB)"
    fi
    
    if [ $CPU_CORES -lt 2 ]; then
        log_warning "CPU cores below recommended 2 cores (found $CPU_CORES)"
    fi
}

# Install Docker Compose
install_docker_compose() {
    log_info "Installing Docker Compose..."
    echo "🔧 Installing Docker Compose..."
    if ! command -v docker-compose &> /dev/null; then
        # First try to use the plugin that comes with Docker
        if docker compose version &> /dev/null; then
            log_info "Docker Compose plugin is already installed"
            echo "✅ Docker Compose plugin is already installed!"
            return
        fi
        
        # If plugin not available, install standalone version
        log_info "Installing standalone Docker Compose..."
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
        sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        check_success "Docker Compose installation"
    else
        log_info "Docker Compose is already installed"
        echo "✅ Docker Compose is already installed!"
    fi
}

# Calculate storage sizes with TB support
calculate_storage() {
    log_info "Calculating recommended storage size..."
    # Convert available space to GB for calculations
    if (( $(echo "$AVAILABLE_SPACE > 1000" | bc -l) )); then
        # If space is in TB, convert to GB (1TB = 1000GB)
        AVAIL_GB=$(echo "scale=2; $AVAILABLE_SPACE * 1000" | bc)
    else
        AVAIL_GB=$AVAILABLE_SPACE
    fi

    # Calculate recommended farming size (70% of available space)
    RECOMMENDED_SIZE=$(echo "scale=0; $AVAIL_GB * 0.7" | bc)
    
    # Ensure minimum requirements are met (100 GB minimum)
    if (( $(echo "$RECOMMENDED_SIZE < 100" | bc -l) )); then
        RECOMMENDED_SIZE=100
        log_warning "Available space is very low. Using minimum 100GB"
    fi

    # Format the display size
    if (( $(echo "$RECOMMENDED_SIZE >= 1000" | bc -l) )); then
        DISPLAY_SIZE=$(echo "scale=2; $RECOMMENDED_SIZE / 1000" | bc)
        echo "💾 Recommended farming size: ${DISPLAY_SIZE}TB"
        log_info "Recommended farming size: ${DISPLAY_SIZE}TB (${RECOMMENDED_SIZE}GB)"
    else
        echo "💾 Recommended farming size: ${RECOMMENDED_SIZE}GB"
        log_info "Recommended farming size: ${RECOMMENDED_SIZE}GB"
    fi
}

# Convert user input to GB
convert_to_gb() {
    local size=$1
    local unit=$2
    
    case $unit in
        [Tt][Bb])
            # 1TB = 1000GB
            echo "scale=0; $size * 1000" | bc
            ;;
        [Gg][Bb])
            echo "$size"
            ;;
        *)
            echo "$size"
            ;;
    esac
}

# Validate Talisman wallet address (Fixed version)
validate_talisman_address() {
    local address=$1
    
    # Check if address is empty
    if [ -z "$address" ]; then
        log_error "Address cannot be empty"
        return 1
    fi
    
    # Substrate addresses are base58 encoded and typically 47-48 characters long
    # They can start with various characters depending on the network prefix
    # Valid base58 characters: 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz
    if [[ $address =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{40,50}$ ]]; then
        # Additional length check for typical Substrate addresses
        local addr_length=${#address}
        if [ $addr_length -ge 40 ] && [ $addr_length -le 50 ]; then
            log_info "Talisman wallet address validation passed (length: $addr_length)"
            return 0
        fi
    fi
    
    log_error "Invalid Talisman wallet address format"
    return 1
}

# Get user inputs
get_user_inputs() {
    log_info "Starting user input collection..."
    echo "📝 Please provide the following information:"
    echo ""
    
    # Get node name
    while true; do
        read -p "🏷️  Enter your node name (e.g., MyAutonomysNode): " NODE_NAME
        if [ -n "$NODE_NAME" ]; then
            log_info "Node name set to: $NODE_NAME"
            break
        else
            echo "❌ Node name cannot be empty!"
        fi
    done
    
    # Get Talisman wallet address
    while true; do
        echo ""
        echo "💰 TALISMAN WALLET ADDRESS"
        echo "=========================="
        echo ""
        echo "Please enter your Talisman wallet address where you want to receive farming rewards."
        echo ""
        echo "📝 Your Talisman wallet address should:"
        echo "   • Be a valid Substrate/Polkadot format address"
        echo "   • Be approximately 40-50 characters long"
        echo "   • Example: 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
        echo "   • Example: sudZUSne8ZzFkuVj5YwoJXjFaQQgmL7i2kciCXRBVMNdv6XgD"
        echo ""
        read -p "Enter your Talisman wallet address: " REWARD_ADDRESS
        
        if [ -n "$REWARD_ADDRESS" ]; then
            if validate_talisman_address "$REWARD_ADDRESS"; then
                echo "✅ Wallet address validated successfully!"
                log_info "Reward address validated and set"
                break
            else
                echo ""
                echo "❌ Invalid wallet address format!"
                echo "   Please ensure you're entering a valid Talisman/Substrate address."
                echo "   It should be 40-50 characters long and contain only valid base58 characters."
            fi
        else
            echo "❌ Wallet address cannot be empty!"
        fi
    done
    
    # Get farming size
    echo ""
    get_farming_size
    
    echo ""
    log_info "User inputs collected successfully"
}

# Get farming size with TB support
get_farming_size() {
    log_info "Getting farming size from user..."
    echo ""
    echo "💾 STORAGE ALLOCATION FOR FARMING"
    echo "=================================="
    echo ""
    echo "Your available disk space: ${AVAILABLE_SPACE}GB"
    if (( $(echo "$AVAILABLE_SPACE > 1000" | bc -l) )); then
        AVAIL_TB=$(echo "scale=2; $AVAILABLE_SPACE / 1000" | bc)
        echo "                          (${AVAIL_TB}TB)"
    fi
    echo ""
    echo "📝 Enter farming size in GB:"
    echo "   • For 2TB enter: 2048"
    echo "   • For 1TB enter: 1000" 
    echo "   • For 500GB enter: 500"
    echo "   • Minimum required: 100GB"
    echo "   • Recommended: ${RECOMMENDED_SIZE}GB"
    echo ""
    echo "💡 Note: 1TB = 1000GB (decimal), so 2TB = 2000GB"
    echo ""
    
    while true; do
        read -p "Enter farming size in GB: " FARMING_INPUT
        
        # Check if input is a number
        if [[ $FARMING_INPUT =~ ^[0-9]+$ ]]; then
            FARMING_SIZE=$FARMING_INPUT
            
            if [ $FARMING_SIZE -lt 100 ]; then
                echo ""
                echo "⚠️  Warning: ${FARMING_SIZE}GB is below the official minimum of 100GB"
                read -p "Continue with ${FARMING_SIZE}GB? (y/N): " CONFIRM_SIZE
                if [[ "$CONFIRM_SIZE" =~ ^[Yy]$ ]]; then
                    log_warning "User chose farming size below minimum: ${FARMING_SIZE}GB"
                    break
                else
                    echo "❌ Please choose a size of 100GB or more"
                    continue
                fi
            else
                # Display confirmation with TB conversion if applicable
                if [ $FARMING_SIZE -ge 1000 ]; then
                    FARMING_TB=$(echo "scale=2; $FARMING_SIZE / 1000" | bc)
                    echo "✅ Farming size set to: ${FARMING_SIZE}GB (${FARMING_TB}TB)"
                    log_info "Farming size set to: ${FARMING_SIZE}GB (${FARMING_TB}TB)"
                else
                    echo "✅ Farming size set to: ${FARMING_SIZE}GB"
                    log_info "Farming size set to: ${FARMING_SIZE}GB"
                fi
                break
            fi
        elif [ -z "$FARMING_INPUT" ]; then
            FARMING_SIZE=$RECOMMENDED_SIZE
            log_info "Using recommended farming size: ${FARMING_SIZE}GB"
            echo "📝 Using recommended size: ${FARMING_SIZE}GB"
            break
        else
            echo "❌ Please enter a valid number in GB (e.g., 1000 for 1TB, 2000 for 2TB)"
        fi
    done
}

# Update system packages based on OS
update_system() {
    log_info "Updating system packages..."
    echo "🔄 Updating system packages..."
    case $ID in
        debian|ubuntu)
            sudo apt update && sudo apt upgrade -y
            ;;
        fedora|rhel|centos)
            sudo dnf upgrade -y
            ;;
        *)
            log_warning "Unknown package manager. Skipping system update."
            echo "⚠️ Unknown package manager. Skipping system update."
            return
            ;;
    esac
    check_success "System update"
}

# Install required packages based on OS
install_required_packages() {
    log_info "Installing required packages..."
    echo "📦 Installing required packages..."
    case $ID in
        debian|ubuntu)
            sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg bc
            ;;
        fedora|rhel|centos)
            sudo dnf install -y curl dnf-plugins-core bc
            ;;
        *)
            log_warning "Unknown package manager for required packages installation"
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
    
    log_info "Managing service: $service ($action)"
    
    # Check if systemd is available
    if command -v systemctl &> /dev/null; then
        sudo systemctl $action $service
    # Check if service command is available
    elif command -v service &> /dev/null; then
        sudo service $service $action
    else
        log_warning "Could not detect init system for service management"
        echo "⚠️ Could not detect init system. Please $action $service manually."
        return 1
    fi
}

# Start and enable Docker service
start_docker() {
    log_info "Starting Docker service..."
    echo "🚀 Starting Docker service..."
    manage_service docker start
    if command -v systemctl &> /dev/null; then
        sudo systemctl enable docker
        log_info "Docker service enabled for auto-start"
    fi
    check_success "Docker service started"
}

# Create Docker Compose file with proper variable substitution
create_docker_compose() {
    log_info "Creating Docker Compose configuration..."
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
        "--name", "${NODE_NAME}"
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
        "--reward-address", "${REWARD_ADDRESS}",
        "path=/var/subspace,size=${FARMING_SIZE}G"
      ]

volumes:
  node-data:
  farmer-data:
EOF
    
    log_info "Docker Compose file created successfully"
    check_success "Docker Compose file created"
}

# Create management scripts
create_management_scripts() {
    log_info "Creating management scripts..."
    echo "📋 Creating management scripts..."

    # Create start script
    cat > start.sh << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Starting Autonomys Network..."
docker-compose up -d
if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Services started successfully!"
    echo "📊 Use 'docker-compose ps' to check status"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Failed to start services!"
fi
EOF
    chmod +x start.sh

    # Create stop script
    cat > stop.sh << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🛑 Stopping Autonomys Network..."
docker-compose down
if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Services stopped successfully!"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Failed to stop services!"
fi
EOF
    chmod +x stop.sh

    # Create logs script
    cat > logs.sh << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📋 Showing logs (Press Ctrl+C to exit)..."
docker-compose logs --tail=1000 -f
EOF
    chmod +x logs.sh

    # Create status script
    cat > status.sh << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📊 Autonomys Network Status:"
echo "=========================="
docker-compose ps
echo ""
echo "💾 Disk Usage:"
df -h /
echo ""
echo "🐳 Docker System Info:"
docker system df
echo ""
echo "📊 Container Resource Usage:"
docker stats --no-stream
EOF
    chmod +x status.sh

    log_info "Management scripts created successfully"
    check_success "Management scripts created"
}

# Main script execution starts here
main() {
    log_info "Starting Autonomys Network setup script..."
    
    # Detect OS and get system info
    detect_os
    get_system_info
    calculate_storage
    
    # Get user inputs
    get_user_inputs
    
    # Update system and install requirements
    update_system
    install_required_packages
    
    # Install Docker and Docker Compose
    install_docker
    install_docker_compose
    
    # Configure Docker
    start_docker
    
    # Add user to docker group
    log_info "Adding user to docker group..."
    echo "👤 Adding user to docker group..."
    sudo usermod -aG docker $USER
    check_success "User added to docker group"
    
    # Create project directory
    log_info "Creating project directory..."
    echo "📁 Creating project directory..."
    mkdir -p ~/autonomys-network
    cd ~/autonomys-network
    
    # Create configuration files and scripts
    create_docker_compose
    create_management_scripts
    
    # Pull Docker images
    log_info "Pulling Docker images..."
    echo "📥 Pulling Docker images (this may take a few minutes)..."
    docker-compose pull
    check_success "Docker images pulled"
    
    # Start the services
    log_info "Starting Autonomys Network services..."
    echo "🚀 Starting Autonomys Network services..."
    docker-compose up -d
    check_success "Services started"
    
    # Display success message
    display_success_message
}

# Display final success message
display_success_message() {
    echo ""
    echo "🎉 SUCCESS! Autonomys Network is now running!"
    echo "============================================="
    echo ""
    echo "📊 Your Configuration:"
    echo "• Node Name: $NODE_NAME"
    echo "• Reward Address: $REWARD_ADDRESS"
    echo "• Farming Size: ${FARMING_SIZE}GB"
    if [ $FARMING_SIZE -ge 1000 ]; then
        FARMING_TB=$(echo "scale=2; $FARMING_SIZE / 1000" | bc)
        echo "                (${FARMING_TB}TB)"
    fi
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
    echo "• docker-compose ps (check status)"
    echo "• docker-compose logs --tail=1000 -f (view logs)"
    echo "• docker-compose down (stop)"
    echo "• docker-compose up -d (start)"
    echo ""
    echo "⚠️  IMPORTANT: You may need to log out and back in for Docker permissions to take effect!"
    echo ""
    echo "🌐 Your node will sync with the network and start farming automatically."
    echo "💰 Rewards will be sent to: $REWARD_ADDRESS"
    echo ""
    
    if [ "$WARNINGS" -gt 0 ]; then
        echo "⚠️  Remember: Your system has $WARNINGS hardware warnings. Monitor performance closely."
        echo "📖 Official requirements: https://docs.autonomys.xyz/farming/intro"
        echo ""
    fi
    
    log_info "Setup completed successfully with $WARNINGS warnings"
    echo "Happy farming! 🚜✨"
}

# Run the main function
main