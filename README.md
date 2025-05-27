# 🚜 Autonomys Network Node & Farmer Setup

> **One-click setup script for running Autonomys Network node and farmer on a fresh VPS**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)
[![Autonomys](https://img.shields.io/badge/Autonomys-Mainnet-green.svg)](https://autonomys.xyz/)

## 🌟 Features

- **🚀 One-Command Setup** - Complete installation on fresh VPS
- **🐳 Docker Management** - Automatic Docker & Docker Compose installation
- **💾 Smart Sizing** - Intelligent farming size recommendations based on available disk space
- **🔧 Management Scripts** - Easy-to-use scripts for logs, status, start/stop
- **💰 Reward Ready** - Configure your Talisman wallet for automatic rewards
- **🛡️ Production Ready** - Health checks, auto-restart, and proper logging

## 📋 Prerequisites

### System Requirements (Official Autonomys Specs)
| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 4 Cores+ | Intel Core i7-6700 or equivalent |
| **RAM** | 8GB | 16GB+ |
| **Node Storage** | 100GB | 256GB |
| **Farm Storage** | 100GB | ♾️ (Unlimited) |

check the docs for latest recommend System Requirements [Autonomys Docs](https://docs.autonomys.xyz/farming/intro)

### Additional Requirements
- **Fresh Ubuntu/Debian VPS** (18.04+ recommended)
- **Talisman wallet address** for rewards
- **Root or sudo access**
- **Stable internet connection** with good bandwidth

## 🚀 Quick Start

### 1. Download the Setup Script

```bash
curl -O https://raw.githubusercontent.com/Blockchain-Oracle/autonomys-setup/main/setup-autonomys.sh
chmod +x setup-autonomys.sh
```

### 2. Run the Setup

```bash
sudo ./setup-autonomys.sh
```

### 3. Follow the Interactive Prompts

The script will ask for:
- 🔑 **Talisman wallet address** (for rewards)
- 💾 **Farming size** (recommended size calculated automatically)
- 📛 **Node name** (optional, default: "my-autonomys-node")

### 4. Wait for Setup to Complete

The script will:
- Update your system
- Install Docker & Docker Compose
- Pull Autonomys images
- Start your node and farmer
- Create management scripts

## 🎯 What Gets Installed

### System Components
- Docker Engine (latest stable)
- Docker Compose (latest)
- Required system packages (curl, ca-certificates, etc.)

### Autonomys Services
- **Node**: `ghcr.io/autonomys/node:mainnet-2025-may-08`
- **Farmer**: `ghcr.io/autonomys/farmer:mainnet-2025-may-08`

### Project Structure
```
~/autonomys-network/
├── docker-compose.yml    # Main configuration
├── start.sh             # Start services
├── stop.sh              # Stop services  
├── logs.sh              # View logs
└── status.sh            # Check status
```

## 🔧 Management Commands

### Using Helper Scripts
```bash
cd ~/autonomys-network

# View real-time logs
./logs.sh

# Check service status
./status.sh

# Stop all services
./stop.sh

# Start all services
./start.sh
```

### Using Docker Compose Directly
```bash
cd ~/autonomys-network

# View logs (last 1000 lines, follow)
sudo docker-compose logs --tail=1000 -f

# Check service status
sudo docker-compose ps

# Stop services
sudo docker-compose down

# Start services
sudo docker-compose up -d

# Restart services
sudo docker-compose restart
```

## 📊 Monitoring Your Setup

### Check Node Status
```bash
# View logs for specific service
sudo docker-compose logs -f node
sudo docker-compose logs -f farmer

# Check resource usage
sudo docker stats

# View system resources
df -h
free -h
```

### Important Log Messages to Look For
- ✅ **Node sync**: "Syncing" → "Idle" (fully synced)
- ✅ **Farmer connection**: "Connected to node"
- ✅ **Plotting**: "Plotting sector" (initial setup)
- ✅ **Farming**: "Successfully submitted solution"

## 🔥 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check logs for errors
sudo docker-compose logs

# Restart services
sudo docker-compose restart

# Check disk space (need 8GB+ free)
df -h
```

#### Node Not Syncing
```bash
# Check node logs
sudo docker-compose logs -f node

# Verify ports are open (30333, 30433)
sudo netstat -tlnp | grep -E ':(30333|30433|30533)'
```

#### Farmer Not Connecting
```bash
# Check farmer logs
sudo docker-compose logs -f farmer

# Verify node is healthy
sudo docker-compose ps
```

#### Performance Issues
```bash
# Check system resources
htop
sudo docker stats

# Check disk I/O
iostat -x 1
```

### Reset Everything
```bash
cd ~/autonomys-network

# Stop and remove everything (keeps your farming data)
sudo docker-compose down

# Remove all data (WARNING: This deletes your plots!)
sudo docker-compose down -v

# Start fresh
sudo docker-compose up -d
```

## ⚙️ Configuration

### Changing Reward Address
1. Edit `docker-compose.yml`
2. Find `--reward-address` line
3. Replace with your new address
4. Restart: `sudo docker-compose restart farmer`

### Changing Farming Size
1. Edit `docker-compose.yml`
2. Find `path=/var/subspace,size=XXXGb` line
3. Change size value
4. Restart: `sudo docker-compose restart farmer`

### Changing Node Name
1. Edit `docker-compose.yml`
2. Find `--name` parameter
3. Change the value
4. Restart: `sudo docker-compose restart node`

## 🛡️ Security Considerations

- **Firewall**: Consider restricting access to ports 30333, 30433, 30533
- **Updates**: Regularly update images with `sudo docker-compose pull && sudo docker-compose up -d`
- **Monitoring**: Set up monitoring for disk space and service health
- **Backups**: Your farming plots are stored in Docker volumes - consider backup strategies

## 📈 Optimization Tips

### For Better Performance
- **SSD Storage**: Use SSD for better I/O performance
- **More RAM**: 4GB+ recommended for larger farms
- **Network**: Stable internet connection with good bandwidth
- **Monitoring**: Use tools like `htop`, `iotop` to monitor resources

### For Larger Farms
- **Multiple Disks**: Mount additional storage for larger farming
- **Resource Limits**: Consider setting Docker resource limits
- **Load Balancing**: For multiple nodes, consider load balancing

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📞 Support

- **Autonomys Discord**: [Join the community](https://discord.gg/autonomys)
- **Documentation**: [Official Docs](https://docs.autonomys.xyz/)
- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/autonomys-setup/issues)

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ℹ️ Additional Information

### Official Hardware Requirements
| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 4 Cores+ | Intel Core i7-6700 or equivalent |
| **RAM** | 8GB | 16GB+ |
| **Node Storage** | 100GB | 256GB |
| **Farm Storage** | 100GB | ♾️ (Unlimited) |

- **OS**: Ubuntu 18.04+, Debian 10+, or compatible Linux distribution
- **Network**: Stable internet connection with good bandwidth
- **Storage Type**: SSD strongly recommended for better performance

> 📖 **Source**: [Official Autonomys Documentation](https://docs.autonomys.xyz/farming/intro)

### Port Usage
- **30333**: Node P2P communication
- **30433**: DSN (Distributed Storage Network)
- **30533**: Farmer P2P communication
- **9944**: RPC endpoint (localhost only)

### Docker Images
- Node: `ghcr.io/autonomys/node:mainnet-2025-may-08`
- Farmer: `ghcr.io/autonomys/farmer:mainnet-2025-may-08`

---

**🚜 Happy Farming with Autonomys Network! 🌟**

*Built with ❤️  By Blockchain Oracle for the Autonomys community*