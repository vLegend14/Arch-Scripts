```
FASE 1: INSTALACIÓN BASE DE ARCH
├─ Particionar disco (solo marcar Btrfs en /, nada más)
├─ Instalar sistema base
└─ Configurar bootloader (GRUB)

FASE 2: POST-INSTALACIÓN
├─ install-aur-helper.sh (Yay) ✅
├─ setup-snapshots.sh ✅
├─ setup-dualboot.sh ✅
├─ post-install-gaming.sh ✅
└─ Reboot ✅

FASE 3: CONFIGURACIÓN BIOS
├─ Entrar al BIOS/UEFI
├─ Configurar SSD 930GB como primer boot
├─ Habilitar Secure Boot
└─ Guardar y reiniciar
```

# Darle permisos de ejecución
chmod +x install-aur-helper.sh
chmod +x setup-snapshots.sh
chmod +x setup-dualboot.sh
chmod +x post-install-gaming.sh

# Ejecutar cada uno en orden
./install-aur-helper.sh
sudo ./setup-snapshots.sh
sudo ./setup-dualboot.sh
sudo ./post-install-gaming.sh
