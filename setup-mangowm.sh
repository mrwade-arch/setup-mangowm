#!/bin/bash
# =============================================================================
# CachyOS + MangoWM Setup Script
# Run as your normal user (not root) after first boot
# =============================================================================

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[*]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
ok()      { echo -e "${GREEN}[✓]${NC} $1"; }

# =============================================================================
# SANITY CHECKS
# =============================================================================

[[ $EUID -eq 0 ]] && error "Don't run this as root. Run as your normal user."
ping -c 1 -W 2 8.8.8.8 &>/dev/null || error "No internet connection detected."

# =============================================================================
# 1. SYSTEM UPDATE
# =============================================================================

info "Updating system..."
sudo pacman -Syu --noconfirm

# =============================================================================
# 2. PARU (AUR HELPER)
# =============================================================================

if ! command -v paru &>/dev/null; then
    info "Installing paru..."
    sudo pacman -S --needed --noconfirm git base-devel
    cd /tmp
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    cd ~
    ok "paru installed"
else
    ok "paru already installed"
fi

# =============================================================================
# 3. MANGOWM DEPENDENCIES
# =============================================================================

info "Installing MangoWM build dependencies..."
sudo pacman -S --needed --noconfirm \
    wayland \
    wayland-protocols \
    wlroots \
    libinput \
    pixman \
    xcb-util-renderutil \
    xcb-util-wm \
    xorg-xwayland \
    meson \
    ninja \
    pkg-config \
    gcc \
    make \
    git

# =============================================================================
# 4. BUILD & INSTALL MANGOWM
# =============================================================================

info "Cloning and building MangoWM..."
cd ~/src 2>/dev/null || mkdir -p ~/src && cd ~/src

if [ -d "mangowm" ]; then
    warning "MangoWM directory exists, pulling latest..."
    cd mangowm && git pull
else
    git clone https://github.com/mangowm/mangowm
    cd mangowm
fi

if [ -f "meson.build" ]; then
    meson setup build --wipe
    ninja -C build
    sudo ninja -C build install
elif [ -f "Makefile" ]; then
    make
    sudo make install
else
    error "Unknown build system in MangoWM repo. Check the repo manually."
fi

ok "MangoWM built and installed"
cd ~

# =============================================================================
# 5. TERMINAL — FOOT
# =============================================================================

info "Installing foot terminal..."
sudo pacman -S --needed --noconfirm foot

mkdir -p ~/.config/foot
cat > ~/.config/foot/foot.ini << 'EOF'
[main]
font=monospace:size=11
pad=8x8

[colors]
background=0d1117
foreground=c9d1d9
regular0=21262d
regular1=ff7b72
regular2=3fb950
regular3=d29922
regular4=58a6ff
regular5=bc8cff
regular6=39c5cf
regular7=b1bac4
bright0=6e7681
bright1=ffa198
bright2=56d364
bright3=e3b341
bright4=79c0ff
bright5=d2a8ff
bright6=56d4dd
bright7=f0f6fc
EOF

ok "foot configured"

# =============================================================================
# 6. APP LAUNCHER — WOFI
# =============================================================================

info "Installing wofi (app launcher)..."
sudo pacman -S --needed --noconfirm wofi

mkdir -p ~/.config/wofi
cat > ~/.config/wofi/config << 'EOF'
width=400
height=300
location=center
show=drun
prompt=Run
filter_rate=100
allow_markup=true
no_actions=true
halign=fill
orientation=vertical
content_halign=fill
insensitive=true
allow_images=true
image_size=24
gtk_dark=true
EOF

ok "wofi configured"

# =============================================================================
# 7. STATUS BAR — WAYBAR
# =============================================================================

info "Installing waybar..."
sudo pacman -S --needed --noconfirm waybar

mkdir -p ~/.config/waybar
cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 28,
    "modules-left": ["clock", "cpu", "memory"],
    "modules-center": [],
    "modules-right": ["pulseaudio", "bluetooth", "network", "battery"],
    "clock": {
        "format": "{:%a %b %d  %H:%M}",
        "tooltip": false
    },
    "cpu": {
        "format": " {usage}%",
        "interval": 2
    },
    "memory": {
        "format": " {used:0.1f}G",
        "interval": 5
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": " muted",
        "format-icons": {"default": ["", "", ""]}
    },
    "bluetooth": {
        "format": " {status}",
        "format-connected": " {device_alias}"
    },
    "network": {
        "format-wifi": " {essid}",
        "format-ethernet": " eth",
        "format-disconnected": " off"
    },
    "battery": {
        "format": "{icon} {capacity}%",
        "format-icons": ["", "", "", "", ""]
    }
}
EOF

cat > ~/.config/waybar/style.css << 'EOF'
* {
    font-family: monospace;
    font-size: 12px;
    border: none;
    border-radius: 0;
    padding: 0 6px;
}
window#waybar {
    background: rgba(13, 17, 23, 0.92);
    color: #c9d1d9;
}
#clock, #cpu, #memory, #pulseaudio, #network, #bluetooth, #battery {
    padding: 0 8px;
    color: #c9d1d9;
}
#battery.critical { color: #ff7b72; }
EOF

ok "waybar configured"

# =============================================================================
# 8. NOTIFICATIONS — MAKO
# =============================================================================

info "Installing mako (notifications)..."
sudo pacman -S --needed --noconfirm mako libnotify

mkdir -p ~/.config/mako
cat > ~/.config/mako/config << 'EOF'
background-color=#0d1117
text-color=#c9d1d9
border-color=#30363d
border-radius=6
border-size=1
font=monospace 11
width=320
height=100
margin=10
padding=12
default-timeout=5000
EOF

ok "mako configured"

# =============================================================================
# 9. SCREENSHOTS — GRIM + SLURP
# =============================================================================

info "Installing screenshot tools..."
sudo pacman -S --needed --noconfirm grim slurp wl-clipboard

mkdir -p ~/screenshots
ok "grim + slurp installed (use: grim -g \"\$(slurp)\" ~/screenshots/shot.png)"

# =============================================================================
# 10. PIPEWIRE AUDIO
# =============================================================================

info "Installing pipewire audio..."
sudo pacman -S --needed --noconfirm \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber \
    pavucontrol

systemctl --user enable pipewire pipewire-pulse wireplumber
ok "pipewire configured"

# =============================================================================
# 11. BLUETOOTH
# =============================================================================

info "Installing bluetooth..."
sudo pacman -S --needed --noconfirm bluez bluez-utils bluetui
sudo systemctl enable bluetooth
sudo systemctl start bluetooth
ok "bluetooth enabled (use bluetui for TUI control)"

# =============================================================================
# 12. NETWORKING
# =============================================================================

info "Ensuring NetworkManager is running..."
sudo systemctl enable --now NetworkManager
ok "NetworkManager active"

# =============================================================================
# 13. FIREFOX
# =============================================================================

info "Installing Firefox..."
sudo pacman -S --needed --noconfirm firefox
ok "Firefox installed"

# =============================================================================
# 14. NEOVIM
# =============================================================================

info "Installing Neovim..."
sudo pacman -S --needed --noconfirm neovim

mkdir -p ~/.config/nvim
cat > ~/.config/nvim/init.lua << 'EOF'
-- Basic Neovim config
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.updatetime = 50
vim.opt.clipboard = "unnamedplus"

-- Leader key
vim.g.mapleader = " "

-- Basic keymaps
vim.keymap.set("n", "<leader>w", ":w<CR>")
vim.keymap.set("n", "<leader>q", ":q<CR>")
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
EOF

ok "Neovim configured"

# =============================================================================
# 15. QUALITY OF LIFE EXTRAS
# =============================================================================

info "Installing QoL tools..."
sudo pacman -S --needed --noconfirm \
    ripgrep \
    fd \
    bat \
    eza \
    fzf \
    htop \
    btop \
    man-db \
    wget \
    curl \
    unzip \
    zip \
    p7zip \
    xdg-utils \
    xdg-user-dirs \
    ttf-jetbrains-mono-nerd \
    noto-fonts \
    noto-fonts-emoji \
    brightnessctl \
    playerctl

xdg-user-dirs-update
ok "QoL tools installed"

# =============================================================================
# 16. BASH CONFIG
# =============================================================================

info "Configuring bash..."
cat > ~/.bashrc << 'EOF'
# MangoWM CachyOS Environment

# Aliases
alias ls='eza --icons'
alias ll='eza -la --icons'
alias lt='eza --tree --icons'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias vim='nvim'
alias vi='nvim'
alias v='nvim'
alias ss='grim -g "$(slurp)" ~/screenshots/$(date +%Y%m%d_%H%M%S).png'
alias bt='bluetui'
alias vol='pavucontrol &'

# Env
export EDITOR=nvim
export BROWSER=firefox
export XDG_CURRENT_DESKTOP=mangowm

# fzf
[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash

# Prompt
PS1='\[\033[01;32m\]\u\[\033[00m\]@\[\033[01;34m\]\h\[\033[00m\]:\[\033[01;36m\]\w\[\033[00m\]\$ '
EOF

ok "bash configured"

# =============================================================================
# 17. TTY AUTOSTART — .bash_profile
# =============================================================================

info "Configuring TTY autostart for MangoWM..."
cat > ~/.bash_profile << 'EOF'
# Source bashrc
[[ -f ~/.bashrc ]] && source ~/.bashrc

# Launch MangoWM on TTY1 login
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=mangowm
    export XDG_CURRENT_DESKTOP=mangowm
    export MOZ_ENABLE_WAYLAND=1
    export QT_QPA_PLATFORM=wayland
    export SDL_VIDEODRIVER=wayland
    export _JAVA_AWT_WM_NONREPARENTING=1
    exec mangowm
fi
EOF

ok "TTY autostart configured — MangoWM will launch automatically on tty1 login"

# =============================================================================
# 18. TTL MANGLE TO 65 (HOTSPOT BYPASS) — nftables, permanent
# =============================================================================

info "Setting up TTL mangling to 65 via nftables..."

sudo pacman -S --needed --noconfirm nftables

# Write the nftables TTL mangle config
sudo tee /etc/nftables.d/ttl-mangle.nft > /dev/null << 'EOF'
# TTL mangle — sets outgoing TTL to 65 to avoid tethering detection
# IPv4
table ip mangle {
    chain postrouting {
        type filter hook postrouting priority mangle; policy accept;
        ip ttl set 65
    }
}

# IPv6
table ip6 mangle {
    chain postrouting {
        type filter hook postrouting priority mangle; policy accept;
        ip6 hoplimit set 65
    }
}
EOF

# Make sure main nftables.conf includes the drop-in directory
if ! grep -q "ttl-mangle" /etc/nftables.conf 2>/dev/null; then
    echo 'include "/etc/nftables.d/ttl-mangle.nft"' | sudo tee -a /etc/nftables.conf > /dev/null
fi

# Create drop-in dir if it doesn't exist
sudo mkdir -p /etc/nftables.d

# Enable and start nftables so it loads on every boot
sudo systemctl enable --now nftables

# Verify it's active
if sudo nft list ruleset | grep -q "ttl set 65"; then
    ok "TTL mangle active — outgoing TTL is now 65"
else
    warning "nftables loaded but couldn't verify TTL rule — check: sudo nft list ruleset"
fi

# =============================================================================
# DONE
# =============================================================================

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup complete! Reboot and log in.${NC}"
echo -e "${GREEN}  MangoWM will start automatically.${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Quick reference:"
echo "  Super+Enter    → foot terminal (set in MangoWM config)"
echo "  Super+d        → wofi app launcher"  
echo "  ss             → screenshot selection to ~/screenshots/"
echo "  bt             → bluetui bluetooth manager"
echo "  vol            → pavucontrol volume"
echo "  btop           → system monitor"
echo ""
warning "Check MangoWM's config file location after launch to bind keys for waybar/mako startup."
