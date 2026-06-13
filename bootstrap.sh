#!/bin/bash
set -e

# --- System update ---
echo "

Updating package index...

"
# Include synaptics repo for DisplayLink drivers
wget -P ./Downloads https://www.synaptics.com/sites/default/files/Ubuntu/pool/stable/main/all/synaptics-repository-keyring.deb -d ./Downloads
sudo apt install ./Downloads/synaptics-repository-keyring.deb
sudo apt update && sudo apt upgrade -y

# --- DisplayLink drivers ---
echo "

Installing DisplayLink drivers

"
sudo apt install displaylink-driver

# --- Core tools (needed by later steps) ---
echo "

Installing core tools...

"
sudo apt install -y git curl wget gpg wl-clipboard
sudo apt install tmux
sudo snap install docker


# --- Proton Pass ---
echo "

Installing Proton Pass...

"
if command -v snap &> /dev/null; then
  sudo snap install proton-pass
else
  echo "WARNING: snap not available, skipping Proton Pass"
fi

# --- SSH server + Tailscale ---
echo "

Installing SSH server...

"
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
 
echo "

Installing Tailscale...

"
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
echo "Authenticate Tailscale in the browser, then press Enter to continue..."
read -r _

# SSH client config (keepalive to prevent dropped connections)
mkdir -p ~/.ssh
if ! grep -q "ServerAliveInterval" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config << 'SSHCONF'
Host *
  ServerAliveInterval 30
  ServerAliveCountMax 5
SSHCONF
  chmod 600 ~/.ssh/config
fi

# --- uv ---
echo "

Installing uv...

"
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
echo "Installing uv tools..."
uv tool install commitizen
uv tool install ruff@latest

# --- VSCode ---
echo "

Installing VSCode...

"
sudo rm -f /etc/apt/sources.list.d/vscode.list
sudo rm -f /usr/share/keyrings/microsoft.gpg
sudo rm -f /etc/apt/keyrings/microsoft.gpg
sudo rm -f /etc/apt/sources.list.d/vscode.sources
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update && sudo apt install -y code

# --- Brave ---
echo "

Installing Brave...

"
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] \
  https://brave-browser-apt-release.s3.brave.com/ stable main" \
  | sudo tee /etc/apt/sources.list.d/brave-browser.list
sudo apt update && sudo apt install -y brave-browser

# --- Spotify ---
echo "

Installing Spotify...

"
if command -v snap &> /dev/null; then
  sudo snap install spotify
else
  echo "WARNING: snap not available, skipping Spotify"
fi

# --- SSH key ---
echo "

Setting up ssh keys

"
mkdir -p ~/.ssh
if [ -f ~/.ssh/id_ed25519 ]; then
  echo "SSH key already exists at ~/.ssh/id_ed25519, skipping generation"
else
  echo "Enter your email for the SSH key:"
  read ssh_email
  ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519

  echo ""
  echo "Your public key:"
  cat ~/.ssh/id_ed25519.pub
  echo ""
  echo "Add the above key to GitHub at https://github.com/settings/ssh/new"
  echo "Press Enter when done..."
  read -r _
fi

# --- Dotfiles ---
echo "

Restoring dotfiles...

"
if [ -d "$HOME/.dotfiles" ]; then
  echo "Dotfiles repo already exists, skipping clone"
else
  git clone --bare git@github.com:wingos80/LinuxBootstrap.git "$HOME/.dotfiles"
fi

function dotfiles() {
  git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" "$@"
}

# Back up conflicting files before checkout
if ! dotfiles checkout 2>/dev/null; then
  echo "Backing up conflicting dotfiles..."
  mkdir -p "$HOME/.dotfiles-backup"
  dotfiles checkout 2>&1 | grep -E "^\s+" | awk '{print $1}' | while read -r file; do
    mkdir -p "$HOME/.dotfiles-backup/$(dirname "$file")"
    mv "$HOME/$file" "$HOME/.dotfiles-backup/$file"
  done
  dotfiles checkout
fi

dotfiles config --local status.showUntrackedFiles no

echo "

--------------------------------------------------------------
Done. Open a new terminal to pick up any shell config changes.
--------------------------------------------------------------

"
