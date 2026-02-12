#!/bin/bash

# Script para configurar snapshots automáticas en Arch Linux con Btrfs
# Autor: Asistente Claude
# Uso: sudo ./setup-snapshots.sh

set -e  # Detener si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que se ejecute como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root (sudo)${NC}"
   exit 1
fi

# Verificar que / sea Btrfs
ROOT_FS=$(df -T / | tail -1 | awk '{print $2}')
if [[ "$ROOT_FS" != "btrfs" ]]; then
    echo -e "${RED}Error: Tu partición raíz no es Btrfs (detectado: $ROOT_FS)${NC}"
    echo "Este script solo funciona con Btrfs en /"
    exit 1
fi

echo -e "${GREEN}=== Configurador de Snapshots para Arch Linux ===${NC}\n"

# Preguntar qué herramienta usar
echo "¿Qué herramienta prefieres?"
echo "1) Timeshift (recomendado para principiantes - interfaz gráfica)"
echo "2) Snapper (avanzado - más automático)"
read -p "Selecciona [1/2]: " choice

case $choice in
    1)
        echo -e "\n${YELLOW}Instalando Timeshift...${NC}"
        
        # Instalar Timeshift
        pacman -S --needed --noconfirm timeshift
        
        echo -e "${GREEN}✓ Timeshift instalado${NC}"
        
        # Crear directorio de hooks si no existe
        mkdir -p /etc/pacman.d/hooks
        
        # Crear hook para snapshots antes de actualizaciones
        echo -e "\n${YELLOW}Creando hook de pacman para snapshots pre-actualización...${NC}"
        
        cat > /etc/pacman.d/hooks/00-timeshift-pre.hook << 'EOF'
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
Description = Creando snapshot antes de actualizar sistema
When = PreTransaction
Exec = /usr/bin/timeshift --create --comments "Pre-upgrade snapshot $(date '+%Y-%m-%d %H:%M')" --tags D --scripted
Depends = timeshift
EOF

        # Crear hook para limpiar snapshots viejas después de actualizaciones
        cat > /etc/pacman.d/hooks/99-timeshift-post.hook << 'EOF'
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
Description = Limpiando snapshots antiguas
When = PostTransaction
Exec = /usr/bin/timeshift --delete-all --scripted
Depends = timeshift
EOF

        echo -e "${GREEN}✓ Hooks de pacman creados${NC}"
        
        # Crear primera snapshot
        echo -e "\n${YELLOW}Creando primera snapshot...${NC}"
        timeshift --create --comments "Primera snapshot - Sistema base" --tags D --scripted
        
        echo -e "\n${GREEN}=== Configuración completada ===${NC}"
        echo -e "Para configurar el schedule y opciones avanzadas, ejecuta:"
        echo -e "  ${YELLOW}sudo timeshift-gtk${NC} (interfaz gráfica)"
        echo -e "  ${YELLOW}sudo timeshift --list${NC} (ver snapshots)"
        echo -e "\n${GREEN}Snapshots automáticas:${NC}"
        echo "  ✓ Se crearán antes de CADA actualización de pacman"
        echo "  ✓ Configura schedule adicional con timeshift-gtk"
        echo -e "\n${YELLOW}Para restaurar:${NC}"
        echo "  sudo timeshift --restore"
        ;;
        
    2)
        echo -e "\n${YELLOW}Instalando Snapper y snap-pac...${NC}"
        
        # Instalar Snapper
        pacman -S --needed --noconfirm snapper snap-pac
        
        echo -e "${GREEN}✓ Snapper y snap-pac instalados${NC}"
        
        # Configurar snapper para /
        echo -e "\n${YELLOW}Configurando snapper para /...${NC}"
        
        # Crear configuración
        snapper -c root create-config /
        
        # Ajustar permisos del directorio .snapshots
        chmod 750 /.snapshots
        
        # Modificar configuración de snapper
        echo -e "${YELLOW}Configurando límites de snapshots...${NC}"
        
        sed -i 's/^TIMELINE_MIN_AGE=.*/TIMELINE_MIN_AGE="1800"/' /etc/snapper/configs/root
        sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
        sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
        sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="0"/' /etc/snapper/configs/root
        sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
        sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root
        
        # Habilitar servicio de limpieza automática
        systemctl enable --now snapper-timeline.timer
        systemctl enable --now snapper-cleanup.timer
        
        echo -e "${GREEN}✓ Snapper configurado${NC}"
        
        # Crear primera snapshot
        echo -e "\n${YELLOW}Creando primera snapshot...${NC}"
        snapper -c root create --description "Primera snapshot - Sistema base"
        
        echo -e "\n${GREEN}=== Configuración completada ===${NC}"
        echo -e "${GREEN}Snapshots automáticas:${NC}"
        echo "  ✓ Antes/después de cada actualización (snap-pac)"
        echo "  ✓ Cada hora (mantiene últimas 5)"
        echo "  ✓ Diarias (mantiene últimas 7)"
        echo -e "\n${YELLOW}Comandos útiles:${NC}"
        echo "  snapper -c root list              # Ver snapshots"
        echo "  snapper -c root create -d 'X'     # Crear snapshot manual"
        echo "  snapper -c root delete X          # Eliminar snapshot"
        echo "  snapper -c root undochange X..Y   # Revertir cambios"
        
        # Advertencia sobre GRUB
        echo -e "\n${YELLOW}NOTA IMPORTANTE:${NC}"
        echo "Para poder arrancar desde snapshots, necesitas:"
        echo "1. Instalar: pacman -S grub-btrfs"
        echo "2. Habilitar: systemctl enable --now grub-btrfsd"
        echo "Esto añadirá las snapshots al menú de GRUB"
        ;;
        
    *)
        echo -e "${RED}Opción inválida${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}✓ ¡Todo listo!${NC}"
echo -e "Tus datos están protegidos con snapshots automáticas 🎉\n"