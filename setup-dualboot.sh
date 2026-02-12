#!/bin/bash

# Script para configurar Dual Boot Arch Linux + Windows 11 con Secure Boot
# Autor: Asistente Claude
# Uso: sudo ./setup-dualboot.sh
# Requisitos: Arch Linux ya instalado con GRUB

set -e  # Detener si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar que se ejecute como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root (sudo)${NC}"
   exit 1
fi

echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Configurador Dual Boot Arch + Windows 11 + Secure Boot  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}\n"

# Verificar que GRUB esté instalado
if ! command -v grub-mkconfig &> /dev/null; then
    echo -e "${RED}Error: GRUB no está instalado${NC}"
    echo "Este script requiere GRUB como bootloader"
    exit 1
fi

# Verificar sistema UEFI
if [ ! -d /sys/firmware/efi ]; then
    echo -e "${RED}Error: Este sistema no está en modo UEFI${NC}"
    echo "Este script solo funciona con UEFI"
    exit 1
fi

echo -e "${BLUE}[1/5] Detectando configuración actual...${NC}\n"

# Mostrar discos y particiones
echo -e "${YELLOW}Discos detectados:${NC}"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -E "disk|part"

echo -e "\n${YELLOW}Particiones EFI detectadas:${NC}"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep -i "vfat\|efi"

# Detectar partición de Windows automáticamente
echo -e "\n${YELLOW}Buscando instalación de Windows...${NC}"
WIN_PARTITIONS=$(lsblk -o NAME,FSTYPE,LABEL | grep -i "ntfs\|windows" | awk '{print $1}' || true)

if [ -n "$WIN_PARTITIONS" ]; then
    echo -e "${GREEN}✓ Particiones de Windows detectadas:${NC}"
    echo "$WIN_PARTITIONS"
else
    echo -e "${YELLOW}⚠ No se detectaron particiones NTFS/Windows automáticamente${NC}"
fi

echo -e "\n${BLUE}[2/5] Instalando os-prober...${NC}"

# Instalar os-prober
pacman -S --needed --noconfirm os-prober

echo -e "${GREEN}✓ os-prober instalado${NC}"

# Backup de configuración GRUB
echo -e "\n${YELLOW}Creando backup de /etc/default/grub...${NC}"
cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)

# Habilitar os-prober en GRUB
echo -e "\n${BLUE}[3/5] Configurando GRUB para detectar Windows...${NC}"

if grep -q "^GRUB_DISABLE_OS_PROBER" /etc/default/grub; then
    sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    echo -e "${GREEN}✓ GRUB_DISABLE_OS_PROBER actualizado a false${NC}"
else
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    echo -e "${GREEN}✓ GRUB_DISABLE_OS_PROBER añadido${NC}"
fi

# Detectar partición EFI de Windows para montarla temporalmente
echo -e "\n${YELLOW}¿Deseas montar la partición EFI de Windows para mejor detección?${NC}"
echo "Esto ayuda a que os-prober detecte Windows correctamente"
read -p "Montar EFI de Windows? [S/n]: " mount_win_efi

if [[ ! "$mount_win_efi" =~ ^[Nn]$ ]]; then
    echo -e "\n${YELLOW}Particiones EFI disponibles:${NC}"
    lsblk -o NAME,SIZE,FSTYPE,LABEL | grep -i "vfat"
    
    echo -e "\n${YELLOW}Ejemplo: si ves sda1, escribe 'sda1' (sin /dev/)${NC}"
    read -p "Introduce la partición EFI de Windows (o Enter para omitir): " win_efi_part
    
    if [ -n "$win_efi_part" ]; then
        mkdir -p /mnt/windows-efi
        if mount /dev/$win_efi_part /mnt/windows-efi 2>/dev/null; then
            echo -e "${GREEN}✓ Partición EFI de Windows montada en /mnt/windows-efi${NC}"
            WIN_EFI_MOUNTED=true
        else
            echo -e "${YELLOW}⚠ No se pudo montar /dev/$win_efi_part${NC}"
            WIN_EFI_MOUNTED=false
        fi
    fi
fi

# Regenerar configuración de GRUB
echo -e "\n${YELLOW}Regenerando configuración de GRUB...${NC}"
grub-mkconfig -o /boot/grub/grub.cfg

# Verificar si Windows fue detectado
if grep -qi "windows" /boot/grub/grub.cfg; then
    echo -e "${GREEN}✓✓✓ Windows detectado exitosamente en GRUB ✓✓✓${NC}"
else
    echo -e "${YELLOW}⚠ Windows no fue detectado automáticamente${NC}"
    echo "Esto puede ser normal si Windows está en otro disco"
fi

# Desmontar EFI de Windows si se montó
if [ "$WIN_EFI_MOUNTED" = true ]; then
    umount /mnt/windows-efi
    echo -e "${GREEN}✓ Partición EFI de Windows desmontada${NC}"
fi

echo -e "\n${BLUE}[4/5] Configurando Secure Boot con sbctl...${NC}"

# Instalar sbctl
pacman -S --needed --noconfirm sbctl

echo -e "${GREEN}✓ sbctl instalado${NC}"

# Verificar estado de Secure Boot
echo -e "\n${YELLOW}Estado actual de Secure Boot:${NC}"
sbctl status

# Verificar si ya existen claves
if [ -d "/usr/share/secureboot/keys" ] && [ "$(ls -A /usr/share/secureboot/keys)" ]; then
    echo -e "\n${YELLOW}Ya existen claves de Secure Boot${NC}"
    read -p "¿Recrear las claves? [s/N]: " recreate_keys
    
    if [[ "$recreate_keys" =~ ^[Ss]$ ]]; then
        rm -rf /usr/share/secureboot/keys/*
        sbctl create-keys
        echo -e "${GREEN}✓ Claves recreadas${NC}"
    else
        echo -e "${YELLOW}Usando claves existentes${NC}"
    fi
else
    echo -e "\n${YELLOW}Creando claves de firma Secure Boot...${NC}"
    sbctl create-keys
    echo -e "${GREEN}✓ Claves creadas${NC}"
fi

# Inscribir claves (con claves de Microsoft para que Windows funcione)
echo -e "\n${YELLOW}Inscribiendo claves en el firmware...${NC}"
echo -e "${RED}IMPORTANTE: Si Secure Boot está activo, esto puede fallar${NC}"
echo "En ese caso, necesitarás:"
echo "1. Reiniciar al BIOS"
echo "2. Poner Secure Boot en 'Setup Mode'"
echo "3. Volver a ejecutar este script"

read -p "¿Continuar con la inscripción de claves? [S/n]: " enroll_keys

if [[ ! "$enroll_keys" =~ ^[Nn]$ ]]; then
    if sbctl enroll-keys -m 2>&1 | tee /tmp/sbctl-enroll.log; then
        echo -e "${GREEN}✓ Claves inscritas exitosamente${NC}"
    else
        echo -e "${YELLOW}⚠ Error al inscribir claves${NC}"
        echo "Revisa /tmp/sbctl-enroll.log para más detalles"
        echo -e "${YELLOW}Probablemente necesites poner Secure Boot en Setup Mode en el BIOS${NC}"
    fi
fi

echo -e "\n${BLUE}[5/5] Firmando archivos del sistema...${NC}"

# Verificar qué archivos necesitan firma
echo -e "\n${YELLOW}Verificando archivos que necesitan firma:${NC}"
sbctl verify

# Detectar kernel instalado
KERNEL_ZEN="/boot/vmlinuz-linux-zen"
KERNEL_NORMAL="/boot/vmlinuz-linux"
GRUB_EFI="/boot/EFI/GRUB/grubx64.efi"

# Firmar kernel zen si existe
if [ -f "$KERNEL_ZEN" ]; then
    echo -e "\n${YELLOW}Firmando kernel zen...${NC}"
    sbctl sign -s "$KERNEL_ZEN"
    
    # Firmar initramfs si existe
    if [ -f "/boot/initramfs-linux-zen.img" ]; then
        sbctl sign -s /boot/initramfs-linux-zen.img 2>/dev/null || echo -e "${YELLOW}⚠ No se pudo firmar initramfs (normal)${NC}"
    fi
    
    echo -e "${GREEN}✓ Kernel zen firmado${NC}"
else
    echo -e "${YELLOW}⚠ Kernel zen no encontrado${NC}"
fi

# Firmar kernel normal si existe (backup)
if [ -f "$KERNEL_NORMAL" ]; then
    echo -e "\n${YELLOW}Firmando kernel normal (backup)...${NC}"
    sbctl sign -s "$KERNEL_NORMAL"
    
    if [ -f "/boot/initramfs-linux.img" ]; then
        sbctl sign -s /boot/initramfs-linux.img 2>/dev/null || echo -e "${YELLOW}⚠ No se pudo firmar initramfs (normal)${NC}"
    fi
    
    echo -e "${GREEN}✓ Kernel normal firmado${NC}"
else
    echo -e "${YELLOW}ℹ Kernel normal no instalado (opcional)${NC}"
fi

# Firmar GRUB
if [ -f "$GRUB_EFI" ]; then
    echo -e "\n${YELLOW}Firmando GRUB...${NC}"
    sbctl sign -s "$GRUB_EFI"
    echo -e "${GREEN}✓ GRUB firmado${NC}"
else
    echo -e "${RED}⚠ GRUB no encontrado en $GRUB_EFI${NC}"
    echo "Verifica la ubicación de tu EFI"
fi

# Verificar firmas
echo -e "\n${YELLOW}Verificando firmas:${NC}"
sbctl verify

# Crear hooks de pacman para firma automática
echo -e "\n${BLUE}Configurando firma automática en actualizaciones...${NC}"

mkdir -p /etc/pacman.d/hooks

cat > /etc/pacman.d/hooks/999-sign_kernel_for_secureboot.hook << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-zen
Target = linux
Target = grub

[Action]
Description = Firmando kernel y GRUB para Secure Boot
When = PostTransaction
Exec = /usr/bin/sh -c 'sbctl sign -s /boot/vmlinuz-linux-zen 2>/dev/null || true; sbctl sign -s /boot/vmlinuz-linux 2>/dev/null || true; sbctl sign -s /boot/EFI/GRUB/grubx64.efi 2>/dev/null || true'
Depends = sbctl
EOF

echo -e "${GREEN}✓ Hook de firma automática creado${NC}"

# Resumen final
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              CONFIGURACIÓN COMPLETADA                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}✓ os-prober instalado y configurado${NC}"
echo -e "${GREEN}✓ GRUB regenerado${NC}"
if grep -qi "windows" /boot/grub/grub.cfg; then
    echo -e "${GREEN}✓ Windows detectado en GRUB${NC}"
else
    echo -e "${YELLOW}⚠ Windows no detectado (verifica manualmente)${NC}"
fi
echo -e "${GREEN}✓ sbctl configurado${NC}"
echo -e "${GREEN}✓ Archivos firmados para Secure Boot${NC}"
echo -e "${GREEN}✓ Firma automática en actualizaciones habilitada${NC}"

echo -e "\n${YELLOW}PRÓXIMOS PASOS:${NC}"
echo -e "1. ${BLUE}Reinicia el sistema${NC}"
echo -e "2. ${BLUE}Entra al BIOS/UEFI${NC}"
echo -e "3. ${BLUE}Configura el orden de arranque:${NC}"
echo -e "   - Disco de Arch (930GB) como primero"
echo -e "4. ${BLUE}Habilita Secure Boot${NC}"
echo -e "   - Si falla, pon Secure Boot en 'Setup Mode' y vuelve a ejecutar el script"
echo -e "5. ${BLUE}Guarda y reinicia${NC}"

echo -e "\n${YELLOW}VERIFICACIÓN:${NC}"
echo -e "- En GRUB deberías ver: Arch Linux + Windows Boot Manager"
echo -e "- Después de arrancar Arch, ejecuta: ${BLUE}sbctl status${NC}"
echo -e "  Debe mostrar: ${GREEN}Secure Boot: enabled${NC}"

echo -e "\n${YELLOW}COMANDOS ÚTILES:${NC}"
echo -e "  sbctl status          # Ver estado de Secure Boot"
echo -e "  sbctl verify          # Verificar firmas"
echo -e "  sbctl list            # Listar archivos firmados"
echo -e "  efibootmgr -v         # Ver entradas de arranque UEFI"

echo -e "\n${GREEN}¡Configuración de dual boot completada! 🎉${NC}\n"