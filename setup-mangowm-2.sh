#!/bin/bash
# =============================================================================
# CachyOS + MangoWM Full Setup Script
# Run as your normal user (NOT root) after first boot into CachyOS
# =============================================================================

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[*]${NC} $1"; }
ok()      { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${YELLOW}══════════════════════════════════════${NC}"; echo -e "${YELLOW}  $1${NC}"; echo -e "${YELLOW}══════════════════════════════════════${NC}"; }

# =============================================================================
# SANITY CHECKS
# =============================================================================

[[ $EUID -eq 0 ]] && error "Don't run as root. Run as your normal user."
ping -c 1 -W 3 8.8.8.8 &>/dev/null || error "No internet. Connect first."

USER_HOME="$HOME"
USERNAME=$(whoami)

# =============================================================================
# 1. SYSTEM UPDATE
# =============================================================================

section "System Update"
sudo pacman -Syu --noconfirm
ok "System up to date"

# =============================================================================
# 2. PARU (AUR HELPER)
# =============================================================================

section "Paru AUR Helper"
if ! command -v paru &>/dev/null; then
    info "Installing paru..."
    sudo pacman -S --needed --noconfirm git base-devel
    cd /tmp
    rm -rf paru-bin
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    cd "$USER_HOME"
    ok "paru installed"
else
    ok "paru already present"
fi

# =============================================================================
# 3. ZSH + ZINIT + STARSHIP
# =============================================================================

section "Zsh Shell Setup"

sudo pacman -S --needed --noconfirm zsh zsh-completions

# Starship prompt
curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Zinit plugin manager
ZINIT_DIR="${XDG_DATA_HOME:-$USER_HOME/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_DIR" ]; then
    mkdir -p "$(dirname "$ZINIT_DIR")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_DIR"
fi

cat > "$USER_HOME/.zshrc" << 'ZSHRC'
# =============================================================================
# ZINIT
# =============================================================================
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
source "$ZINIT_HOME/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light Aloxaf/fzf-tab

# =============================================================================
# ENV
# =============================================================================
export EDITOR=nvim
export VISUAL=nvim
export BROWSER=firefox
export TERM=foot
export XDG_CURRENT_DESKTOP=mangowm
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export GDK_BACKEND=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
export PATH="$HOME/.local/bin:$PATH"

# =============================================================================
# HISTORY
# =============================================================================
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY APPEND_HISTORY

# =============================================================================
# COMPLETION
# =============================================================================
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons $realpath'

# =============================================================================
# KEYBINDS
# =============================================================================
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# =============================================================================
# ALIASES
# =============================================================================
alias ..='cd ..'
alias ...='cd ../..'
alias ls='eza --icons'
alias ll='eza -la --icons --git'
alias lt='eza --tree --icons --level=2'
alias cat='bat --style=plain'
alias grep='rg'
alias find='fd'
alias vim='nvim'
alias vi='nvim'
alias v='nvim'
alias update='sudo pacman -Syu && paru -Sua'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null; paru -Sc --noconfirm'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me'
alias ss='grim -g "$(slurp)" ~/screenshots/$(date +%Y%m%d_%H%M%S).png && echo Screenshot saved'
alias ssf='grim ~/screenshots/$(date +%Y%m%d_%H%M%S).png && echo Screenshot saved'
alias clip='wl-copy'
alias cliph='cliphist list | wofi --dmenu | cliphist decode | wl-copy'
alias bt='bluetui'
alias vol='pavucontrol &'
alias night='wlsunset -l 35 -L -90'
alias nightoff='pkill wlsunset'
alias lock='swaylock'
alias files='lf'
alias fetch='fastfetch'
alias top='btop'
alias keys='~/.local/bin/keybinds-gui'
alias nft-ttl='sudo nft list ruleset | grep -A5 mangle'

# =============================================================================
# FZF
# =============================================================================
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=bg+:#161b22,bg:#0d1117,spinner:#58a6ff,hl:#58a6ff,fg:#c9d1d9,header:#58a6ff,info:#3fb950,pointer:#58a6ff,marker:#3fb950,fg+:#c9d1d9,prompt:#58a6ff,hl+:#79c0ff'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# fastfetch on terminal open
fastfetch

# Starship
eval "$(starship init zsh)"
ZSHRC

# Starship config
mkdir -p "$USER_HOME/.config"
cat > "$USER_HOME/.config/starship.toml" << 'EOF'
format = """
[╭─](bold green)$os$username$hostname$directory$git_branch$git_status
[╰─](bold green)$character"""

[os]
disabled = false
style = "bold cyan"

[username]
style_user = "bold green"
show_always = true
format = "[$user]($style)"

[hostname]
ssh_only = false
format = "@[$hostname](bold cyan) "

[directory]
style = "bold blue"
truncation_length = 4
format = "in [$path]($style) "

[git_branch]
style = "bold purple"
format = "on [$symbol$branch]($style) "

[git_status]
format = '([\[$all_status$ahead_behind\]]($style) )'
style = "bold red"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
EOF

sudo chsh -s /bin/zsh "$USERNAME"
ok "zsh + zinit + starship configured, set as default shell"

# =============================================================================
# 4. MANGOWM BUILD
# =============================================================================

section "MangoWM"
sudo pacman -S --needed --noconfirm \
    wayland wayland-protocols wlroots libinput pixman \
    xcb-util-renderutil xcb-util-wm xorg-xwayland \
    meson ninja pkg-config gcc make git

mkdir -p "$USER_HOME/src"
cd "$USER_HOME/src"

if [ -d "mangowm" ]; then
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
    make && sudo make install
else
    error "Unknown MangoWM build system — check repo manually"
fi

ok "MangoWM built and installed"
cd "$USER_HOME"

# =============================================================================
# 5. FOOT TERMINAL
# =============================================================================

section "Foot Terminal"
sudo pacman -S --needed --noconfirm foot

mkdir -p "$USER_HOME/.config/foot"
cat > "$USER_HOME/.config/foot/foot.ini" << 'EOF'
[main]
font=JetBrainsMono Nerd Font:size=11
pad=10x10
shell=zsh

[scrollback]
lines=5000

[colors]
background=0d1117
foreground=c9d1d9
alpha=0.95
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

[cursor]
style=beam
blink=yes
EOF

ok "foot configured"

# =============================================================================
# 6. WOFI LAUNCHER
# =============================================================================

section "Wofi Launcher"
sudo pacman -S --needed --noconfirm wofi

mkdir -p "$USER_HOME/.config/wofi"
cat > "$USER_HOME/.config/wofi/config" << 'EOF'
width=420
height=320
location=center
show=drun
prompt= Search
filter_rate=100
allow_markup=true
no_actions=true
halign=fill
orientation=vertical
content_halign=fill
insensitive=true
allow_images=true
image_size=28
gtk_dark=true
EOF

cat > "$USER_HOME/.config/wofi/style.css" << 'EOF'
window {
    margin: 0;
    border: 1px solid #30363d;
    border-radius: 10px;
    background-color: #0d1117;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 13px;
}
#input {
    padding: 10px;
    margin: 8px;
    border: 1px solid #30363d;
    border-radius: 6px;
    background-color: #161b22;
    color: #c9d1d9;
}
#entry:selected {
    background-color: #1f6feb;
    border-radius: 6px;
}
#text { color: #c9d1d9; padding: 4px; }
#text:selected { color: #ffffff; }
EOF

ok "wofi configured"

# =============================================================================
# 7. WAYBAR
# =============================================================================

section "Waybar"
sudo pacman -S --needed --noconfirm waybar

mkdir -p "$USER_HOME/.config/waybar"
cat > "$USER_HOME/.config/waybar/config.jsonc" << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left": ["clock", "cpu", "memory", "temperature"],
    "modules-center": [],
    "modules-right": ["pulseaudio", "bluetooth", "network", "battery", "tray"],
    "clock": {
        "format": "  {:%a %b %d  %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt>{calendar}</tt>"
    },
    "cpu": { "format": "  {usage}%", "interval": 2, "tooltip": false },
    "memory": { "format": "  {used:0.1f}G", "interval": 5 },
    "temperature": {
        "format": "  {temperatureC}°C",
        "critical-threshold": 80,
        "format-critical": "  {temperatureC}°C"
    },
    "pulseaudio": {
        "format": "{icon}  {volume}%",
        "format-muted": "  muted",
        "format-icons": { "default": ["", "", ""] },
        "on-click": "pavucontrol"
    },
    "bluetooth": {
        "format": "  {status}",
        "format-connected": "  {device_alias}",
        "on-click": "foot -e bluetui"
    },
    "network": {
        "format-wifi": "  {essid} ({signalStrength}%)",
        "format-ethernet": "  eth",
        "format-disconnected": "  offline"
    },
    "battery": {
        "format": "{icon}  {capacity}%",
        "format-icons": ["", "", "", "", ""],
        "format-charging": "  {capacity}%",
        "states": { "warning": 30, "critical": 15 }
    },
    "tray": { "spacing": 8 }
}
EOF

cat > "$USER_HOME/.config/waybar/style.css" << 'EOF'
* { font-family: "JetBrainsMono Nerd Font"; font-size: 12px; border: none; min-height: 0; }
window#waybar { background: rgba(13,17,23,0.92); color: #c9d1d9; border-bottom: 1px solid #21262d; }
#clock, #cpu, #memory, #temperature, #pulseaudio, #network, #bluetooth, #battery, #tray {
    padding: 2px 10px; border-radius: 4px; margin: 3px 2px;
}
#clock { color: #79c0ff; }
#cpu { color: #3fb950; }
#memory { color: #d2a8ff; }
#temperature { color: #ffa657; }
#temperature.critical { color: #ff7b72; }
#battery.warning { color: #e3b341; }
#battery.critical { color: #ff7b72; }
#network { color: #58a6ff; }
#bluetooth { color: #39c5cf; }
EOF

ok "waybar configured"

# =============================================================================
# 8. MAKO NOTIFICATIONS
# =============================================================================

section "Mako Notifications"
sudo pacman -S --needed --noconfirm mako libnotify

mkdir -p "$USER_HOME/.config/mako"
cat > "$USER_HOME/.config/mako/config" << 'EOF'
background-color=#0d1117
text-color=#c9d1d9
border-color=#1f6feb
border-radius=8
border-size=1
font=JetBrainsMono Nerd Font 11
width=340
height=120
margin=12
padding=14
default-timeout=5000
layer=overlay

[urgency=low]
border-color=#30363d

[urgency=high]
border-color=#ff7b72
background-color=#3d1a1a
EOF

ok "mako configured"

# =============================================================================
# 9. SCREENSHOTS + CLIPBOARD
# =============================================================================

section "Screenshots & Clipboard"
sudo pacman -S --needed --noconfirm grim slurp wl-clipboard
paru -S --needed --noconfirm cliphist
mkdir -p "$USER_HOME/screenshots"
ok "grim + slurp + cliphist installed"

# =============================================================================
# 10. SCREEN LOCK
# =============================================================================

section "Screen Lock"
sudo pacman -S --needed --noconfirm swaylock swayidle

mkdir -p "$USER_HOME/.config/swaylock"
cat > "$USER_HOME/.config/swaylock/config" << 'EOF'
color=0d1117
font=JetBrainsMono Nerd Font
indicator-radius=80
indicator-thickness=6
ring-color=1f6feb
key-hl-color=3fb950
inside-color=161b22
text-color=c9d1d9
line-color=30363d
separator-color=00000000
show-failed-attempts
daemonize
EOF

ok "swaylock configured"

# =============================================================================
# 11. NIGHT LIGHT
# =============================================================================

section "Night Light"
sudo pacman -S --needed --noconfirm wlsunset
ok "wlsunset installed — alias: night / nightoff"

# =============================================================================
# 12. AUTO-MOUNT USB
# =============================================================================

section "Auto-mount USB"
sudo pacman -S --needed --noconfirm udisks2
paru -S --needed --noconfirm udiskie
ok "udiskie installed"

# =============================================================================
# 13. LF FILE MANAGER
# =============================================================================

section "LF File Manager"
sudo pacman -S --needed --noconfirm lf
paru -S --needed --noconfirm chafa

mkdir -p "$USER_HOME/.config/lf"
cat > "$USER_HOME/.config/lf/lfrc" << 'EOF'
set icons true
set drawbox true
set ratios 1:2:3
set info size:time
set hidden true
set ignorecase true
set previewer ~/.config/lf/preview

map <enter> open
map D delete
map r rename
map . set hidden!
map <esc> quit
cmd open $nvim "$f"
EOF

cat > "$USER_HOME/.config/lf/preview" << 'EOF'
#!/bin/bash
case "$1" in
    *.pdf) pdftotext "$1" - ;;
    *.png|*.jpg|*.jpeg|*.gif|*.webp) chafa "$1" ;;
    *) bat --color=always --style=plain "$1" ;;
esac
EOF
chmod +x "$USER_HOME/.config/lf/preview"
ok "lf configured"

# =============================================================================
# 14. IMAGE + PDF VIEWER
# =============================================================================

section "Media Viewers"
sudo pacman -S --needed --noconfirm imv zathura zathura-pdf-mupdf
ok "imv (images) and zathura (PDF) installed"

# =============================================================================
# 15. XDG PORTAL (screen sharing)
# =============================================================================

section "XDG Portal"
sudo pacman -S --needed --noconfirm \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-utils xdg-user-dirs
xdg-user-dirs-update
ok "xdg-desktop-portal configured"

# =============================================================================
# 16. PIPEWIRE AUDIO
# =============================================================================

section "Pipewire Audio"
sudo pacman -S --needed --noconfirm \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol playerctl
systemctl --user enable --now pipewire pipewire-pulse wireplumber
ok "pipewire active"

# =============================================================================
# 17. BLUETOOTH
# =============================================================================

section "Bluetooth"
sudo pacman -S --needed --noconfirm bluez bluez-utils
paru -S --needed --noconfirm bluetui
sudo systemctl enable --now bluetooth
ok "bluetooth active"

# =============================================================================
# 18. NETWORKING
# =============================================================================

section "Networking"
sudo systemctl enable --now NetworkManager
ok "NetworkManager active"

# =============================================================================
# 19. GTK DARK THEME
# =============================================================================

section "GTK Dark Theme"
paru -S --needed --noconfirm adw-gtk3-git papirus-icon-theme

mkdir -p "$USER_HOME/.config/gtk-3.0" "$USER_HOME/.config/gtk-4.0"
cat > "$USER_HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=true
EOF

cp "$USER_HOME/.config/gtk-3.0/settings.ini" "$USER_HOME/.config/gtk-4.0/settings.ini"
ok "GTK dark theme configured"

# =============================================================================
# 20. FIREFOX
# =============================================================================

section "Firefox"
sudo pacman -S --needed --noconfirm firefox
ok "Firefox installed"

# =============================================================================
# 21. NEOVIM
# =============================================================================

section "Neovim"
sudo pacman -S --needed --noconfirm neovim

mkdir -p "$USER_HOME/.config/nvim"
cat > "$USER_HOME/.config/nvim/init.lua" << 'EOF'
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.updatetime = 50
vim.opt.clipboard = "unnamedplus"
vim.opt.cursorline = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"

vim.g.mapleader = " "
local k = vim.keymap.set
k("n", "<leader>w", ":w<CR>")
k("n", "<leader>q", ":q<CR>")
k("n", "<leader>x", ":x<CR>")
k("n", "<C-h>", "<C-w>h")
k("n", "<C-l>", "<C-w>l")
k("n", "<C-j>", "<C-w>j")
k("n", "<C-k>", "<C-w>k")
k("n", "<leader>v", ":vsplit<CR>")
k("n", "<leader>s", ":split<CR>")
k("n", "<leader>e", ":Ex<CR>")
k("v", "J", ":m '>+1<CR>gv=gv")
k("v", "K", ":m '<-2<CR>gv=gv")
EOF

ok "Neovim configured"

# =============================================================================
# 22. QOL TOOLS + FONTS
# =============================================================================

section "QoL Tools"
sudo pacman -S --needed --noconfirm \
    ripgrep fd bat eza fzf htop btop man-db wget curl \
    unzip zip p7zip brightnessctl playerctl socat jq \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji otf-font-awesome

paru -S --needed --noconfirm fastfetch

mkdir -p "$USER_HOME/.config/fastfetch"
cat > "$USER_HOME/.config/fastfetch/config.jsonc" << 'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": { "type": "small" },
    "display": { "separator": "  " },
    "modules": [
        "title", "separator",
        "os", "kernel", "shell", "terminal",
        "wm", "cpu", "gpu", "memory",
        "disk", "uptime", "separator", "colors"
    ]
}
EOF

ok "QoL tools and fonts installed"

# =============================================================================
# 23. AUTO-CPUFREQ
# =============================================================================

section "CPU Power Management"
paru -S --needed --noconfirm auto-cpufreq
sudo systemctl enable --now auto-cpufreq
ok "auto-cpufreq active"

# =============================================================================
# 24. TTL MANGLE TO 65 — nftables
# =============================================================================

section "TTL Mangle (Hotspot Bypass)"
sudo pacman -S --needed --noconfirm nftables
sudo mkdir -p /etc/nftables.d

sudo tee /etc/nftables.d/ttl-mangle.nft > /dev/null << 'EOF'
table ip mangle {
    chain postrouting {
        type filter hook postrouting priority mangle; policy accept;
        ip ttl set 65
    }
}
table ip6 mangle {
    chain postrouting {
        type filter hook postrouting priority mangle; policy accept;
        ip6 hoplimit set 65
    }
}
EOF

if ! grep -q "ttl-mangle" /etc/nftables.conf 2>/dev/null; then
    echo 'include "/etc/nftables.d/ttl-mangle.nft"' | sudo tee -a /etc/nftables.conf > /dev/null
fi

sudo systemctl enable --now nftables
ok "TTL mangle active — outgoing TTL = 65"

# =============================================================================
# 25. KEYBIND VIEWER GUI
# =============================================================================

section "Keybind Viewer GUI"
sudo pacman -S --needed --noconfirm yad

mkdir -p "$USER_HOME/.local/bin"
cat > "$USER_HOME/.local/bin/keybinds-gui" << 'KBSCRIPT'
#!/bin/bash
# MangoWM Keybind Viewer & Editor
# Parses MangoWM config + displays in a yad GUI table
# Bind to Super+F1 in MangoWM config

MANGO_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/mangowm/config"

# Default keybind table (shown if config can't be parsed)
declare -A DEFAULTS=(
    ["Super+Enter"]="Open terminal (foot)"
    ["Super+D"]="App launcher (wofi)"
    ["Super+F1"]="Keybind viewer (this)"
    ["Super+Q"]="Close focused window"
    ["Super+F"]="Toggle fullscreen"
    ["Super+Space"]="Toggle floating"
    ["Super+H/J/K/L"]="Focus left/down/up/right"
    ["Super+Shift+H/J/K/L"]="Move window"
    ["Super+1-9"]="Switch to workspace"
    ["Super+Shift+1-9"]="Move window to workspace"
    ["Super+R"]="Resize mode"
    ["Super+S"]="Screenshot (selection)"
    ["Super+Shift+S"]="Screenshot (fullscreen)"
    ["Super+L"]="Lock screen"
    ["Super+Shift+E"]="Exit MangoWM"
    ["Super+Shift+R"]="Reload config"
)

# Build yad data from defaults
YARGS=()
for key in "${!DEFAULTS[@]}"; do
    YARGS+=("$key" "${DEFAULTS[$key]}")
done

# Try to also parse real config and append any extra binds found
if [ -f "$MANGO_CONFIG" ]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ bind ]]; then
            key=$(echo "$line" | awk '{print $2}')
            action=$(echo "$line" | awk '{$1=$2=""; print $0}' | xargs)
            [ -n "$key" ] && YARGS+=("$key (config)" "$action")
        fi
    done < "$MANGO_CONFIG"
fi

# Display GUI
RESULT=$(yad \
    --title="MangoWM Keybinds" \
    --list \
    --width=640 \
    --height=520 \
    --center \
    --column="Keybind" \
    --column="Action" \
    --button="Edit Config:2" \
    --button="Close:1" \
    --search-column=1 \
    --grid-lines=horiz \
    "${YARGS[@]}" 2>/dev/null)

EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 2 ]; then
    if [ -f "$MANGO_CONFIG" ]; then
        foot -e nvim "$MANGO_CONFIG"
    else
        yad --info \
            --title="Config Not Found" \
            --text="MangoWM config not found at:\n\n$MANGO_CONFIG\n\nCreate it after first MangoWM launch." \
            --center --button="OK:0" 2>/dev/null
    fi
fi
KBSCRIPT

chmod +x "$USER_HOME/.local/bin/keybinds-gui"
ok "Keybind viewer installed — run: keys"

# =============================================================================
# 26. ZPROFILE — TTY AUTOSTART
# =============================================================================

section "TTY Autostart"
cat > "$USER_HOME/.zprofile" << 'EOF'
# Auto-launch MangoWM on tty1 login
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=mangowm
    export XDG_CURRENT_DESKTOP=mangowm
    export MOZ_ENABLE_WAYLAND=1
    export QT_QPA_PLATFORM=wayland
    export SDL_VIDEODRIVER=wayland
    export GDK_BACKEND=wayland
    export _JAVA_AWT_WM_NONREPARENTING=1

    # Start clipboard daemon
    wl-paste --watch cliphist store &

    # Auto-mount USB drives
    udiskie --tray &

    exec mangowm
fi
EOF

ok "MangoWM auto-launches on tty1 login via .zprofile"

# =============================================================================
# DONE
# =============================================================================

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   All done! Reboot to apply.             ║${NC}"
echo -e "${GREEN}║   Log in on tty1 → MangoWM starts auto   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Aliases & tools:${NC}"
echo "  keys            → keybind viewer GUI (also bind Super+F1)"
echo "  update          → full system + AUR update"
echo "  cleanup         → remove orphan packages"
echo "  ss              → screenshot selection → ~/screenshots/"
echo "  ssf             → full screenshot"
echo "  cliph           → clipboard history picker"
echo "  night           → enable night light"
echo "  nightoff        → disable night light"
echo "  lock            → lock screen"
echo "  files           → lf file manager"
echo "  bt              → bluetui bluetooth"
echo "  vol             → pavucontrol"
echo "  fetch           → fastfetch"
echo "  nft-ttl         → verify TTL mangle is active"
echo ""
echo -e "${YELLOW}Note: Add 'keybinds-gui' to Super+F1 in your MangoWM config.${NC}"
