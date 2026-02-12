#!/bin/bash
# post-install-gaming-complete.sh
# Setup COMPLETO para gaming en HP Victus (Intel UHD + RTX 3050)
# Incluye: Drivers, Wine, Steam, Lutris, Twintail, PipeWire, optimizaciones

set -e

echo "=========================================="
echo "🎮 HP VICTUS - SETUP GAMING COMPLETO"
echo "Intel UHD + RTX 3050"
echo "=========================================="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_step() { echo -e "${BLUE}[→]${NC} $1"; }

# Verificar Arch
if [ ! -f /etc/arch-release ]; then
    print_error "Este script requiere Arch Linux"
    exit 1
fi

# Detectar kernel
print_step "Detectando kernel..."
if pacman -Qq linux-zen &>/dev/null; then
    KERNEL_HEADERS="linux-zen-headers"
    print_info "Kernel Zen (óptimo para gaming)"
elif pacman -Qq linux-lts &>/dev/null; then
    KERNEL_HEADERS="linux-lts-headers"
    print_warn "Kernel LTS (recomiendo linux-zen)"
else
    KERNEL_HEADERS="linux-headers"
    print_warn "Kernel estándar (recomiendo linux-zen)"
fi

###########################################
# PAQUETES A INSTALAR
###########################################
print_step "Preparando lista de paquetes..."

PACKAGES=(
    # ========== DRIVERS GPU ==========
    "$KERNEL_HEADERS"
    
    # Intel UHD
    intel-media-driver
    libva-intel-driver
    vulkan-intel
    lib32-vulkan-intel
    mesa
    lib32-mesa
    
    # NVIDIA RTX 3050
    nvidia-open-dkms
    nvidia-utils
    lib32-nvidia-utils
    nvidia-prime
    libva-nvidia-driver
    
    # ========== VULKAN COMPLETO ==========
    vulkan-icd-loader
    lib32-vulkan-icd-loader
    vulkan-tools
    
    # ========== WINE & PROTON ==========
    wine-staging              # Wine con parches para gaming
    winetricks                # Configurador Wine
    
    # ========== DEPENDENCIAS 32-BIT ==========
    lib32-gnutls             # SSL para juegos online
    lib32-libpulse           # Audio
    lib32-alsa-plugins       # Audio
    lib32-openal             # Audio 3D
    lib32-pipewire           # Audio moderno
    lib32-libx11             # X11
    lib32-libxcb             # X11
    
    # ========== GAMING TOOLS ==========
    gamemode                 # Optimizador rendimiento
    lib32-gamemode
    mangohud                 # Overlay FPS
    lib32-mangohud
    goverlay                 # GUI para MangoHUD
    
    # ========== LAUNCHERS & STORES ==========
    steam                    # Steam
    
    # ========== UTILIDADES ==========
    mesa-utils               # glxinfo, glxgears
    nvtop                    # Monitor GPU
    htop                     # Monitor CPU
)

# Paquetes opcionales (preguntaremos)
OPTIONAL_PACKAGES=(
    lutris                   # Gestor juegos universal
    heroic-games-launcher-bin  # Epic Games (AUR)
    discord                  # Comunicación
)

echo ""
echo "📦 PAQUETES PRINCIPALES (${#PACKAGES[@]}):"
printf '%s\n' "${PACKAGES[@]}" | head -20 | sed 's/^/  • /'
echo "  ... y más"
echo ""
echo "📦 PAQUETES OPCIONALES:"
printf '%s\n' "${OPTIONAL_PACKAGES[@]}" | sed 's/^/  • /'
echo ""

read -p "¿Instalar paquetes principales? (s/N): " -n 1 -r
echo
[[ ! $REPLY =~ ^[Ss]$ ]] && exit 0

###########################################
# INSTALAR PAQUETES PRINCIPALES
###########################################
print_step "Instalando paquetes principales (~1-2GB, puede tardar 10-20 min)..."
echo ""

sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"

print_info "Paquetes principales instalados"

###########################################
# INSTALAR PAQUETES OPCIONALES
###########################################
echo ""
print_step "¿Instalar paquetes opcionales?"
echo ""

# Lutris
read -p "  ¿Instalar Lutris? (gestor de juegos) (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    sudo pacman -S --needed --noconfirm lutris
    print_info "Lutris instalado"
fi

# Discord
read -p "  ¿Instalar Discord? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    sudo pacman -S --needed --noconfirm discord
    print_info "Discord instalado"
fi

# Twintail (Hoyoverse)
echo ""
read -p "  ¿Instalar Twintail Launcher? (Genshin, HSR, ZZZ) (s/N): " -n 1 -r
echo
INSTALL_TWINTAIL=false
if [[ $REPLY =~ ^[Ss]$ ]]; then
    INSTALL_TWINTAIL=true
    print_info "Twintail se instalará desde AUR después"
fi

# Heroic (Epic Games)
read -p "  ¿Instalar Heroic Games Launcher? (Epic Games) (s/N): " -n 1 -r
echo
INSTALL_HEROIC=false
if [[ $REPLY =~ ^[Ss]$ ]]; then
    INSTALL_HEROIC=true
    print_info "Heroic se instalará desde AUR después"
fi

###########################################
# CONFIGURAR AUDIO (PIPEWIRE)
###########################################
echo ""
print_step "Configurando sistema de audio..."

# Verificar si PipeWire ya está instalado (por archinstall)
if pacman -Qq pipewire &>/dev/null; then
    print_info "PipeWire detectado (instalado por archinstall)"
    PIPEWIRE_INSTALLED=true
else
    print_info "PipeWire no detectado, instalando..."
    PIPEWIRE_INSTALLED=false
fi

# Verificar/eliminar PulseAudio si existe
if pacman -Qq pulseaudio &>/dev/null 2>/dev/null; then
    print_warn "PulseAudio detectado, eliminando..."
    sudo pacman -Rns --noconfirm pulseaudio pulseaudio-bluetooth 2>/dev/null || true
fi

# Instalar paquetes PipeWire completos
AUDIO_PACKAGES=(
    pipewire
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    lib32-pipewire           # Gaming 32-bit (archinstall NO instala)
    lib32-pipewire-jack      # Gaming 32-bit
    wireplumber
    pavucontrol              # GUI (archinstall NO instala)
)

if [ "$PIPEWIRE_INSTALLED" = true ]; then
    print_info "Completando instalación PipeWire con paquetes gaming..."
else
    print_info "Instalando PipeWire completo..."
fi

sudo pacman -S --needed --noconfirm "${AUDIO_PACKAGES[@]}"

# Habilitar servicios
systemctl --user enable pipewire.service 2>/dev/null || true
systemctl --user enable pipewire-pulse.service 2>/dev/null || true
systemctl --user enable wireplumber.service 2>/dev/null || true

# Configuración baja latencia para gaming
mkdir -p "$HOME/.config/pipewire/pipewire.conf.d"

cat > "$HOME/.config/pipewire/pipewire.conf.d/99-gaming.conf" <<'EOF'
# Configuración gaming - Baja latencia
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 256
    default.clock.min-quantum = 256
}
EOF

print_info "PipeWire configurado para gaming (baja latencia)"

###########################################
# CONFIGURAR NVIDIA
###########################################
echo ""
print_step "Configurando NVIDIA RTX 3050..."

sudo tee /etc/modprobe.d/nvidia.conf > /dev/null <<'EOF'
options nvidia_drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_DynamicPowerManagement=0x02
EOF

sudo tee /etc/mkinitcpio.conf.d/nvidia.conf > /dev/null <<'EOF'
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF

sudo tee /etc/modprobe.d/i915.conf > /dev/null <<'EOF'
options i915 enable_guc=3
EOF

print_step "Regenerando initramfs..."
sudo mkinitcpio -P

###########################################
# CONFIGURAR HYPRLAND
###########################################
print_step "Configurando Hyprland..."
mkdir -p "$HOME/.config/hypr"

cat > "$HOME/.config/hypr/env.conf" <<'EOF'
# HP Victus - Gaming Configuration
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = WLR_NO_HARDWARE_CURSORS,1
env = __NV_PRIME_RENDER_OFFLOAD,1
env = __VK_LAYER_NV_optimus,NVIDIA_only

# Gaming optimizations
env = MANGOHUD,1
env = ENABLE_VKBASALT,1
EOF

if [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
    if ! grep -q "source.*env.conf" "$HOME/.config/hypr/hyprland.conf"; then
        echo "source = ~/.config/hypr/env.conf" >> "$HOME/.config/hypr/hyprland.conf"
    fi
fi

###########################################
# CONFIGURAR GAMEMODE
###########################################
print_step "Configurando GameMode..."

# Añadir usuario al grupo gamemode
sudo usermod -aG gamemode "$USER"

# Configuración GameMode
sudo tee /etc/security/limits.d/gamemode.conf > /dev/null <<'EOF'
@gamemode - nice -10
EOF

###########################################
# CONFIGURAR STEAM
###########################################
print_step "Configurando Steam..."

mkdir -p "$HOME/.local/share/Steam"

# Habilitar Proton para todos los juegos
# (se hace desde Steam GUI: Settings > Compatibility > Enable Steam Play)

print_info "Recuerda: En Steam, habilita 'Steam Play' para juegos Windows"

###########################################
# CREAR SCRIPTS Y ALIASES
###########################################
print_step "Creando scripts útiles..."
mkdir -p "$HOME/.local/bin"

# Script gpu-check
cat > "$HOME/.local/bin/gpu-check" <<'EOF'
#!/bin/bash
echo "=========================================="
echo "🔍 Estado GPUs"
echo "=========================================="
echo ""
echo "📊 GPU renderizando:"
glxinfo | grep "OpenGL renderer"
echo ""
echo "⚡ Procesos NVIDIA:"
if nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv,noheader 2>/dev/null | grep -q .; then
    nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv,noheader
else
    echo "  (ninguno - usando Intel UHD)"
fi
echo ""
echo "🔋 Consumo GPU:"
nvidia-smi --query-gpu=power.draw,temperature.gpu,utilization.gpu --format=csv,noheader 2>/dev/null || echo "  NVIDIA apagada"
EOF
chmod +x "$HOME/.local/bin/gpu-check"

# Configurar aliases
print_step "Configurando aliases de gaming..."

cat >> "$HOME/.bashrc" <<'EOF'

# ==========================================
# HP VICTUS GAMING ALIASES
# ==========================================

# GPU Management
alias gpu='gpu-check'
alias gputop='nvtop'
alias nv='nvidia-smi'

# Gaming Launchers
alias steam='prime-run steam'
alias lutris='prime-run lutris'

# Python con GPU
pygpu() { prime-run python "$@"; }

# Minecraft
alias mc='prime-run minecraft-launcher'

EOF

# Añadir aliases específicos según lo instalado
if [ "$INSTALL_TWINTAIL" = true ]; then
    cat >> "$HOME/.bashrc" <<'EOF'
# Hoyoverse (Twintail)
alias twintail='prime-run twintail-launcher'
alias genshin='prime-run twintail-launcher'
alias hsr='prime-run twintail-launcher'
alias zzz='prime-run twintail-launcher'

EOF
fi

if [ "$INSTALL_HEROIC" = true ]; then
    cat >> "$HOME/.bashrc" <<'EOF'
# Epic Games (Heroic)
alias heroic='prime-run heroic'

EOF
fi

print_info "Aliases configurados en ~/.bashrc"

###########################################
# INSTALAR DESDE AUR
###########################################
if [ "$INSTALL_TWINTAIL" = true ] || [ "$INSTALL_HEROIC" = true ]; then
    echo ""
    print_step "Instalando paquetes desde AUR..."
    
    # Verificar AUR helper
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        print_warn "No se encontró yay/paru"
        print_warn "Instala manualmente:"
        [ "$INSTALL_TWINTAIL" = true ] && echo "  yay -S twintail-launcher"
        [ "$INSTALL_HEROIC" = true ] && echo "  yay -S heroic-games-launcher-bin"
        AUR_HELPER=""
    fi
    
    if [ -n "$AUR_HELPER" ]; then
        [ "$INSTALL_TWINTAIL" = true ] && $AUR_HELPER -S --needed --noconfirm twintail-launcher
        [ "$INSTALL_HEROIC" = true ] && $AUR_HELPER -S --needed --noconfirm heroic-games-launcher-bin
        print_info "Paquetes AUR instalados"
    fi
fi

###########################################
# SERVICIOS
###########################################
print_step "Habilitando servicios..."
sudo systemctl enable nvidia-suspend.service 2>/dev/null || true
sudo systemctl enable nvidia-hibernate.service 2>/dev/null || true
sudo systemctl enable nvidia-resume.service 2>/dev/null || true

###########################################
# INFORMACIÓN FINAL
###########################################
echo ""
echo "=========================================="
print_info "✅ INSTALACIÓN COMPLETA"
echo "=========================================="
echo ""
echo "🎮 SISTEMA GAMING LISTO:"
echo ""
echo "📦 Instalado:"
echo "  ✓ Drivers GPU (Intel + NVIDIA)"
echo "  ✓ PipeWire (audio optimizado para gaming)"
echo "  ✓ Wine + Proton (juegos Windows)"
echo "  ✓ Steam"
[ "$INSTALL_TWINTAIL" = true ] && echo "  ✓ Twintail Launcher (Hoyoverse)"
[ "$INSTALL_HEROIC" = true ] && echo "  ✓ Heroic (Epic Games)"
echo "  ✓ GameMode + MangoHUD"
echo "  ✓ Vulkan completo"
echo ""
echo "🎯 COMANDOS DISPONIBLES:"
echo "  steam       - Lanzar Steam con RTX 3050"
[ "$INSTALL_TWINTAIL" = true ] && echo "  genshin     - Lanzar Genshin Impact"
[ "$INSTALL_TWINTAIL" = true ] && echo "  hsr         - Lanzar Honkai: Star Rail"
[ "$INSTALL_TWINTAIL" = true ] && echo "  zzz         - Lanzar Zenless Zone Zero"
echo "  mc          - Lanzar Minecraft"
echo "  gpu         - Ver estado GPU"
echo "  gputop      - Monitor GPU interactivo"
echo "  pavucontrol - Control de audio GUI"
echo ""
echo "📚 PRIMEROS PASOS:"
echo ""
echo "  1. Reinicia el sistema:"
echo "     sudo reboot"
echo ""
echo "  2. Verifica drivers:"
echo "     gpu-check"
echo ""
echo "  3. Verifica audio:"
echo "     pactl info"
echo "     pavucontrol"
echo ""
echo "  4. Configura Steam:"
echo "     - Abre Steam"
echo "     - Settings > Compatibility"
echo "     - ✓ Enable Steam Play for all titles"
echo "     - Selecciona: Proton Experimental"
echo ""
echo "  5. Instala tus juegos y disfruta!"
echo ""
echo "💡 TIPS:"
echo "  • Usa 'prime-run <app>' para forzar NVIDIA"
echo "  • Steam ya está configurado para usar GPU"
echo "  • Juega conectado a corriente para mejor rendimiento"
echo "  • MangoHUD muestra FPS (Shift+F12 para toggle)"
echo "  • PipeWire configurado con baja latencia (256 quantum)"
echo ""

print_warn "⚠️  REINICIA AHORA: sudo reboot"
echo ""

read -p "¿Reiniciar ahora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_info "Reiniciando en 5 segundos..."
    sleep 5
    sudo reboot
fi

exit 0