#!/bin/bash
# install-aur-helper.sh
# Instalador interactivo de AUR helper (Yay o Paru)

set -e

echo "=========================================="
echo "📦 Instalador AUR Helper"
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

# Verificar Arch Linux
if [ ! -f /etc/arch-release ]; then
    print_error "Este script requiere Arch Linux"
    exit 1
fi

# Verificar si ya hay un AUR helper instalado
EXISTING_HELPER=""
if command -v yay &>/dev/null; then
    EXISTING_HELPER="yay"
elif command -v paru &>/dev/null; then
    EXISTING_HELPER="paru"
fi

if [ -n "$EXISTING_HELPER" ]; then
    print_warn "Ya tienes '$EXISTING_HELPER' instalado"
    echo ""
    read -p "¿Desinstalar '$EXISTING_HELPER' e instalar otro? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_step "Desinstalando $EXISTING_HELPER..."
        sudo pacman -Rns --noconfirm "$EXISTING_HELPER"
        print_info "$EXISTING_HELPER desinstalado"
    else
        print_info "Manteniendo $EXISTING_HELPER. Saliendo..."
        exit 0
    fi
fi

# Verificar dependencias
print_step "Verificando dependencias..."

DEPENDENCIES=(base-devel git)
MISSING_DEPS=()

for dep in "${DEPENDENCIES[@]}"; do
    if ! pacman -Qq "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    print_warn "Dependencias faltantes: ${MISSING_DEPS[*]}"
    print_step "Instalando dependencias..."
    sudo pacman -S --needed --noconfirm "${MISSING_DEPS[@]}"
    print_info "Dependencias instaladas"
else
    print_info "Todas las dependencias están instaladas"
fi

# Menú de selección
echo ""
echo "=========================================="
echo "Elige tu AUR helper:"
echo "=========================================="
echo ""
echo "1) Yay (recomendado para principiantes)"
echo "   • Más popular y estable"
echo "   • Sintaxis simple"
echo "   • Muy documentado"
echo ""
echo "2) Paru (moderno y rápido)"
echo "   • Escrito en Rust"
echo "   • Más features avanzadas"
echo "   • Ligeramente más rápido"
echo ""
echo "3) Instalar ambos (no recomendado)"
echo ""
echo "4) Cancelar"
echo ""

while true; do
    read -p "Selecciona una opción [1-4]: " choice
    case $choice in
        1)
            HELPER="yay"
            break
            ;;
        2)
            HELPER="paru"
            break
            ;;
        3)
            HELPER="both"
            print_warn "Instalar ambos no es recomendado, pero continuaremos..."
            break
            ;;
        4)
            print_info "Instalación cancelada"
            exit 0
            ;;
        *)
            print_error "Opción inválida. Intenta de nuevo."
            ;;
    esac
done

# Función para instalar un helper
install_helper() {
    local helper=$1
    local repo_url=""
    
    case $helper in
        yay)
            repo_url="https://aur.archlinux.org/yay.git"
            ;;
        paru)
            repo_url="https://aur.archlinux.org/paru.git"
            ;;
    esac
    
    print_step "Instalando $helper..."
    
    # Crear directorio temporal
    TEMP_DIR="/tmp/aur-helper-install"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Limpiar instalación previa si existe
    rm -rf "$helper"
    
    # Clonar repositorio
    print_step "Clonando repositorio de $helper..."
    git clone "$repo_url" "$helper"
    cd "$helper"
    
    # Compilar e instalar
    print_step "Compilando $helper (esto puede tardar 1-2 minutos)..."
    makepkg -si --noconfirm
    
    # Limpiar
    cd ~
    rm -rf "$TEMP_DIR"
    
    print_info "$helper instalado correctamente"
}

# Instalar según elección
echo ""
if [ "$HELPER" = "both" ]; then
    install_helper "yay"
    echo ""
    install_helper "paru"
else
    install_helper "$HELPER"
fi

# Verificar instalación
echo ""
print_step "Verificando instalación..."

if [ "$HELPER" = "both" ]; then
    if command -v yay &>/dev/null && command -v paru &>/dev/null; then
        print_info "Ambos helpers instalados correctamente"
        YAY_VERSION=$(yay --version | head -1)
        PARU_VERSION=$(paru --version | head -1)
        echo "  • $YAY_VERSION"
        echo "  • $PARU_VERSION"
    else
        print_error "Error en la instalación"
        exit 1
    fi
else
    if command -v "$HELPER" &>/dev/null; then
        VERSION=$($HELPER --version | head -1)
        print_info "$VERSION"
    else
        print_error "Error: $HELPER no se instaló correctamente"
        exit 1
    fi
fi

# Actualizar base de datos AUR
echo ""
print_step "Actualizando base de datos..."

if [ "$HELPER" = "both" ]; then
    yay -Sy
else
    $HELPER -Sy
fi

# Información final
echo ""
echo "=========================================="
print_info "✅ INSTALACIÓN COMPLETADA"
echo "=========================================="
echo ""

if [ "$HELPER" = "both" ]; then
    echo "Comandos disponibles:"
    echo "  yay -S <paquete>    - Instalar desde AUR con yay"
    echo "  paru -S <paquete>   - Instalar desde AUR con paru"
    echo ""
    print_warn "Recomendación: Usa solo UNO para evitar confusión"
else
    echo "Comandos básicos de $HELPER:"
    echo ""
    echo "  $HELPER -S <paquete>        # Instalar paquete"
    echo "  $HELPER -Syu                # Actualizar sistema + AUR"
    echo "  $HELPER -R <paquete>        # Desinstalar paquete"
    echo "  $HELPER -Ss <buscar>        # Buscar paquete"
    echo "  $HELPER -Qi <paquete>       # Info de paquete instalado"
    echo ""
fi

echo "📚 Ejemplos de uso:"
echo ""
if [ "$HELPER" = "yay" ] || [ "$HELPER" = "both" ]; then
    echo "  yay -S google-chrome        # Chrome desde AUR"
    echo "  yay -S visual-studio-code-bin"
    echo "  yay -S spotify"
fi
if [ "$HELPER" = "paru" ] || [ "$HELPER" = "both" ]; then
    echo "  paru -S google-chrome       # Chrome desde AUR"
    echo "  paru -S visual-studio-code-bin"
    echo "  paru -S spotify"
fi
echo ""

print_info "¡Listo! Ya puedes instalar paquetes desde AUR"
echo ""

exit 0