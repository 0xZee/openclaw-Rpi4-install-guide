# -----------------------
# To run : 
# chmod +x setup_rpi.sh
# ./setup_rpi.sh
# -----------------------

#!/usr/bin/env bash

set -e

echo "🚀 Starting Raspberry Pi setup..."
echo "------------------------------------"
echo " "
echo "------------------------------------"

# ----------------------------
# 1. System update & cleanup
# ----------------------------
echo "🔧 Updating system..."
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt autoclean

echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# 2. Set timezone (Paris)
# ----------------------------
echo "🕒 Setting timezone to Europe/Paris..."
sudo timedatectl set-timezone Europe/Paris

echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# 3. Secure SSH
# ----------------------------
echo "🔐 Securing SSH..."

SSHD_CONFIG="/etc/ssh/sshd_config"

sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' $SSHD_CONFIG
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' $SSHD_CONFIG
sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' $SSHD_CONFIG
sudo sed -i 's/^#\?Port.*/Port 22/' $SSHD_CONFIG

sudo systemctl restart ssh

echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# 4. UFW Firewall
# ----------------------------
echo "🔥 Installing and configuring UFW..."

sudo apt install -y ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp

if ! sudo ufw status | grep -q "Status: active"; then
    sudo ufw --force enable
fi

echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# 5. Fail2Ban
# ----------------------------
echo "🛡️ Installing Fail2Ban..."

sudo apt install -y fail2ban

JAIL_LOCAL="/etc/fail2ban/jail.local"

sudo bash -c "cat > $JAIL_LOCAL" <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# 6. Memory Optimization
# ----------------------------
echo "⚙️ Configuring memory..."

# GPU memory
CONFIG_TXT="/boot/config.txt"
if ! grep -q "^gpu_mem=" $CONFIG_TXT; then
    echo "gpu_mem=16" | sudo tee -a $CONFIG_TXT
else
    sudo sed -i 's/^gpu_mem=.*/gpu_mem=16/' $CONFIG_TXT
fi

echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# 7. Swap configuration
# ----------------------------
echo "💾 Configuring swap..."

# Disable default dphys swap if active
if systemctl is-active --quiet dphys-swapfile; then
    sudo systemctl stop dphys-swapfile
    sudo systemctl disable dphys-swapfile
fi

# Create swapfile if not exists
if [ ! -f /swapfile ]; then
    echo "Creating 2GB swapfile..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
fi

# Enable swap
sudo swapon /swapfile || true

# Persist in fstab if not already present
if ! grep -q "/swapfile" /etc/fstab; then
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# 8. Node.js 22
# ----------------------------
echo "🚀 Installing Node.js 22..."

if ! command -v node >/dev/null 2>&1 || [[ "$(node -v)" != v22* ]]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
    sudo apt install -y nodejs
fi

echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# 9. Node Compile Cache
# ----------------------------
echo "⚡ Setting Node compile cache..."

BASHRC="$HOME/.bashrc"

# Create cache directory once
mkdir -p /var/tmp/node-compile-cache

# Remove any previous cache config (clean update)
sed -i '/# Node compile cache/,+2d' "$BASHRC"

# Add fresh config
cat >> "$BASHRC" <<'EOF'

# Node compile cache (Hermes agent)
export NODE_COMPILE_CACHE=/var/tmp/node-compile-cache
EOF

# Apply immediately
export NODE_COMPILE_CACHE=/var/tmp/node-compile-cache

echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# 10. Unattended Upgrades
# ----------------------------
echo "🔒 Enabling automatic security updates..."

sudo apt install -y unattended-upgrades

sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrades' <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF


echo "------------------------------------"
echo " "
echo "------------------------------------"
# ----------------------------
# Done
# ----------------------------
echo "✅ Setup complete!"
echo "⚠️ Reboot recommended: sudo reboot"

echo "------------------------------------"
echo " "
echo "------------------------------------"
