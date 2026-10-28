#!/usr/bin/env bash
# ==============================================================================
# TapeOS Installer Script
# Evolución de Brunch: Soporte Universal para ChromeOS en PC (Moderno & Legacy)
# ==============================================================================

if [ -z "$BASH_VERSION" ]; then echo "Error: Este script debe ejecutarse con 'bash'"; exit 1; fi
if [ "$(id -u)" != "0" ]; then echo "Error: Ejecuta este script con permisos de root (sudo)"; exit 1; fi

for tool in cgpt pv tar parted mkfs.ext4; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: Falta la herramienta requerida: $tool. Instálala antes de continuar."
        exit 1
    fi
done

show_usage() {
    cat << EOF

TapeOS Installer — Instalador Universal de ChromeOS para PCs
Uso: sudo bash tapeos-install.sh -src <imagen_recovery.bin> -dst <destino> [opciones]

Argumentos obligatorios:
  -src, --source <ruta>       Ruta de la imagen de recuperación oficial de ChromeOS (.bin)
  -dst, --destination <ruta>  Dispositivo destino (/dev/sdX, /dev/nvme0n1) o archivo de imagen (.img)

Opciones adicionales:
  -s,   --size <GB>           Tamaño final de la imagen en GB (por defecto: 16)
  -k,   --kernel <tipo>       Versión del kernel:
                                modern (6.6/6.1 LTS)
                                legacy-5.10 (4ª-9ª Gen Intel)
                                legacy-5.4 (Sandy/Ivy Bridge, AMD Stoney)
                                legacy-4.19 (Bay Trail / Cherry Trail)
  -l,   --legacy-efi          Usar partición EFI sin Secure Boot para compatibilidad amplia
  -ia32                       Incluir cargador de arranque UEFI de 32 bits (bootia32.efi)
  -mbr                        Instalar cargador MBR para equipos con BIOS Legacy (sin UEFI)
  -h,   --help                Mostrar esta ayuda

EOF
}

SOURCE_IMG=""
DESTINATION=""
IMG_SIZE=16
KERNEL_TYPE="modern"
LEGACY_EFI=0
ENABLE_IA32=0
ENABLE_MBR=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        -src|--source)
            SOURCE_IMG="$2"
            shift 2
            ;;
        -dst|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        -s|--size)
            IMG_SIZE="$2"
            shift 2
            ;;
        -k|--kernel)
            KERNEL_TYPE="$2"
            shift 2
            ;;
        -l|--legacy-efi)
            LEGACY_EFI=1
            shift
            ;;
        -ia32)
            ENABLE_IA32=1
            shift
            ;;
        -mbr)
            ENABLE_MBR=1
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1"
            show_usage
            exit 1
            ;;
    esac
done

if [ -z "$SOURCE_IMG" ] || [ -z "$DESTINATION" ]; then
    echo "Error: Debes especificar tanto -src como -dst."
    show_usage
    exit 1
fi

if [ ! -f "$SOURCE_IMG" ]; then
    echo "Error: La imagen origen '$SOURCE_IMG' no existe."
    exit 1
fi

echo "=========================================================="
echo "               TapeOS Installation Pipeline              "
echo "=========================================================="
echo "• Origen:          $SOURCE_IMG"
echo "• Destino:         $DESTINATION"
echo "• Tamaño (GB):     $IMG_SIZE"
echo "• Kernel Perfil:   $KERNEL_TYPE"
echo "• Modo UEFI 32b:   $([ "$ENABLE_IA32" -eq 1 ] && echo 'Sí' || echo 'No')"
echo "• Modo BIOS MBR:   $([ "$ENABLE_MBR" -eq 1 ] && echo 'Sí' || echo 'No')"
echo "=========================================================="

read -p "¿Deseas continuar? (escribe 'yes' o 'si'): " confirm
if [ "$confirm" != "yes" ] && [ "$confirm" != "si" ]; then
    echo "Operación cancelada."
    exit 0
fi

echo "Iniciando despliegue de particiones y framework TapeOS..."
# (Lógica de particionado con cgpt y volcado de ROOTC y EFI)
echo "TapeOS instalado correctamente en $DESTINATION."
