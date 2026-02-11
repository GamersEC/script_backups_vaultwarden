#!/bin/bash

# ==============================================================================
# INSTALADOR INTERACTIVO - SERVICIO DE BACKUPS VAULTWARDEN
# ==============================================================================

set -e

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║     INSTALADOR - SERVICIO DE BACKUPS VAULTWARDEN              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}${BOLD}[$1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Función para generar passphrase segura
generate_passphrase() {
    # Generar una passphrase de 32 caracteres alfanuméricos + símbolos
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Función para detectar el gestor de paquetes
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Función para instalar un paquete
install_package() {
    local package=$1
    local pkg_manager=$(detect_package_manager)
    
    case $pkg_manager in
        apt)
            sudo apt-get update > /dev/null 2>&1
            sudo apt-get install -y "$package"
            ;;
        dnf)
            sudo dnf install -y "$package"
            ;;
        yum)
            sudo yum install -y "$package"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$package"
            ;;
        zypper)
            sudo zypper install -y "$package"
            ;;
        *)
            print_error "Gestor de paquetes no soportado. Instala $package manualmente."
            return 1
            ;;
    esac
}

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup_vaultwarden.sh"

# URL del repositorio para auto-descarga (personalizar según tu repo)
REPO_RAW_URL="https://raw.githubusercontent.com/GamersEC/script_backups_vaultwarden/main/setup.sh"

clear
print_header
echo ""

# Verificar que existe el script de backup, o descargarlo
if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    print_warning "No se encuentra backup_vaultwarden.sh en el directorio actual"
    print_info "Intentando descarga automática desde el repositorio..."
    echo ""
    
    # Intentar descarga con curl primero, luego wget
    if command -v curl &> /dev/null; then
        if curl -fsSL "$REPO_RAW_URL/backup_vaultwarden.sh" -o "$BACKUP_SCRIPT"; then
            chmod 700 "$BACKUP_SCRIPT"
            print_success "Script descargado exitosamente"
        else
            print_error "Fallo la descarga con curl"
            print_info "Descarga manualmente desde: $REPO_RAW_URL/backup_vaultwarden.sh"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if wget -q "$REPO_RAW_URL/backup_vaultwarden.sh" -O "$BACKUP_SCRIPT"; then
            chmod 700 "$BACKUP_SCRIPT"
            print_success "Script descargado exitosamente"
        else
            print_error "Fallo la descarga con wget"
            print_info "Descarga manualmente desde: $REPO_RAW_URL/backup_vaultwarden.sh"
            exit 1
        fi
    else
        print_error "No se encontró curl ni wget para descargar el script"
        print_info "Instala curl o wget, o descarga manualmente:"
        print_info "  $REPO_RAW_URL/backup_vaultwarden.sh"
        exit 1
    fi
    echo ""
fi

# Verificar permisos de ejecución del script actual
if [[ ! -x "${BASH_SOURCE[0]}" ]]; then
    print_warning "El instalador no tiene permisos de ejecución"
    print_info "Ejecuta: chmod +x setup.sh"
    exit 1
fi

print_info "Este instalador configurará el servicio de backups de Vaultwarden"
echo ""
print_info "Algunos pasos pueden requerir permisos de administrador (sudo):"
print_info "  • Instalación de dependencias del sistema"
print_info "  • Instalación de rclone (si no está instalado)"
echo ""
read -p "Presiona ENTER para continuar..."
clear

# ==============================================================================
# PASO 0: Verificar permisos sudo (si serán necesarios)
# ==============================================================================
print_header
print_step "0/9" "Verificando permisos del sistema"
echo ""

# Verificar si el usuario está en el grupo sudo/wheel
if groups | grep -qE 'sudo|wheel|admin'; then
    print_success "Usuario tiene permisos para ejecutar sudo"
else
    print_warning "Usuario no parece estar en grupo sudo/wheel"
    print_info "Puede que necesites ejecutar el instalador con sudo si falta alguna dependencia"
fi

# Probar sudo sin solicitar contraseña (si está en cache)
if sudo -n true 2>/dev/null; then
    print_success "Permisos sudo disponibles"
else
    print_info "Es posible que se solicite contraseña de sudo durante la instalación"
fi

echo ""
read -p "Presiona ENTER para continuar..."
clear

# ==============================================================================
# PASO 1: Verificar e instalar dependencias
# ==============================================================================
print_header
print_step "1/9" "Verificación de dependencias"
echo ""
print_info "Verificando dependencias necesarias..."
echo ""

DEPENDENCIES=("sqlite3" "gpg" "curl" "tar" "find")
MISSING=()

for dep in "${DEPENDENCIES[@]}"; do
    if command -v "$dep" &> /dev/null; then
        print_success "$dep instalado"
    else
        print_warning "$dep no encontrado"
        MISSING+=("$dep")
    fi
done

# Verificar rclone por separado
RCLONE_INSTALLED=false
if command -v rclone &> /dev/null; then
    print_success "rclone instalado"
    RCLONE_INSTALLED=true
else
    print_warning "rclone no encontrado (recomendado para backups en la nube)"
fi

echo ""

if [[ ${#MISSING[@]} -gt 0 ]]; then
    print_warning "Faltan dependencias: ${MISSING[*]}"
    echo ""
    read -p "¿Deseas instalar las dependencias faltantes? (s/n) [s]: " INSTALL_DEPS
    INSTALL_DEPS="${INSTALL_DEPS:-s}"
    
    if [[ "$INSTALL_DEPS" == "s" || "$INSTALL_DEPS" == "S" ]]; then
        print_info "Instalando dependencias..."
        echo ""
        
        PKG_MANAGER=$(detect_package_manager)
        if [[ "$PKG_MANAGER" == "unknown" ]]; then
            print_error "No se pudo detectar el gestor de paquetes"
            print_info "Por favor, instala manualmente: ${MISSING[*]}"
            exit 1
        fi
        
        for dep in "${MISSING[@]}"; do
            print_info "Instalando $dep..."
            if install_package "$dep"; then
                print_success "$dep instalado correctamente"
            else
                print_error "Fallo al instalar $dep"
                exit 1
            fi
        done
    else
        print_error "No se puede continuar sin las dependencias necesarias"
        exit 1
    fi
fi

# Preguntar sobre rclone
if [[ "$RCLONE_INSTALLED" == false ]]; then
    echo ""
    print_info "rclone permite hacer backups directos a servicios en la nube:"
    print_info "  • Google Drive, OneDrive, Dropbox, S3, etc."
    print_info "  • Sin necesidad de montar unidades"
    echo ""
    read -p "¿Deseas instalar rclone? (s/n) [s]: " INSTALL_RCLONE
    INSTALL_RCLONE="${INSTALL_RCLONE:-s}"
    
    if [[ "$INSTALL_RCLONE" == "s" || "$INSTALL_RCLONE" == "S" ]]; then
        print_info "Instalando rclone (requiere sudo)..."
        if curl -fsSL https://rclone.org/install.sh | sudo bash; then
            print_success "rclone instalado correctamente"
            RCLONE_INSTALLED=true
        else
            print_warning "Fallo al instalar rclone, continuando sin él"
            print_info "Puedes instalarlo manualmente después: curl https://rclone.org/install.sh | sudo bash"
        fi
    fi
fi

echo ""
print_success "Verificación de dependencias completada"
echo ""
read -p "Presiona ENTER para continuar..."
clear

# ==============================================================================
# PASO 2: Configurar directorio base
# ==============================================================================
print_header
print_step "2/9" "Configuración del directorio base"
echo ""
print_info "Todos los archivos del servicio se guardarán aquí:"
print_info "  • Script de backup"
print_info "  • Clave de cifrado"
print_info "  • Archivo de logs"
echo ""
read -p "Directorio base [/home/$USER/servicio_backups]: " BASE_DIR
BASE_DIR="${BASE_DIR:-/home/$USER/servicio_backups}"

# Verificar permisos de escritura en el directorio padre
PARENT_DIR="$(dirname "$BASE_DIR")"
if [[ ! -d "$PARENT_DIR" ]]; then
    print_error "El directorio padre $PARENT_DIR no existe"
    exit 1
fi

if [[ ! -w "$PARENT_DIR" ]]; then
    print_error "No tienes permisos de escritura en $PARENT_DIR"
    print_info "Considera usar un directorio en tu home: /home/$USER/servicio_backups"
    exit 1
fi

if mkdir -p "$BASE_DIR" 2>/dev/null; then
    print_success "Directorio creado: $BASE_DIR"
else
    print_error "No se pudo crear el directorio $BASE_DIR"
    print_info "Verifica los permisos o elige otra ubicación"
    exit 1
fi
echo ""
read -p "Presiona ENTER para continuar..."
clear

# ==============================================================================
# PASO 3: Configurar directorio de origen
# ==============================================================================
print_header
print_step "3/9" "Configuración del directorio de origen"
echo ""
print_info "¿Dónde está instalado Vaultwarden?"
echo ""
read -p "Directorio de datos de Vaultwarden [/opt/vaultwarden/data]: " SOURCE_DIR
SOURCE_DIR="${SOURCE_DIR:-/opt/vaultwarden/data}"

if [[ ! -d "$SOURCE_DIR" ]]; then
    print_warning "El directorio $SOURCE_DIR no existe actualmente"
    print_warning "Asegúrate de que sea la ruta correcta"
fi

print_success "Origen configurado: $SOURCE_DIR"
echo ""
read -p "Presiona ENTER para continuar..."
clear

# ==============================================================================
# PASO 4: Configurar rclone (si está disponible)
# ==============================================================================
RCLONE_REMOTES=()
if [[ "$RCLONE_INSTALLED" == true ]]; then
    print_header
    print_step "4/9" "Configuración de rclone (Opcional)"
    echo ""
    print_info "rclone puede sincronizar backups directamente a la nube"
    print_info "Servicios soportados: Google Drive, OneDrive, Dropbox, S3, etc."
    echo ""
    
    read -p "¿Deseas configurar backups en la nube con rclone? (s/n) [n]: " USE_RCLONE
    USE_RCLONE="${USE_RCLONE:-n}"
    
    if [[ "$USE_RCLONE" == "s" || "$USE_RCLONE" == "S" ]]; then
        echo ""
        print_info "Configurando rclone..."
        print_info "Se abrirá el asistente de configuración de rclone"
        echo ""
        print_warning "IMPORTANTE:"
        print_warning "  1. Cuando te pregunte por el nombre, usa algo descriptivo (ej: gdrive_backup)"
        print_warning "  2. Completa la autenticación con tu cuenta de nube"
        print_warning "  3. Puedes configurar múltiples remotos (uno por servicio)"
        echo ""
        read -p "Presiona ENTER para abrir el asistente de rclone..."
        
        # Ejecutar configuración de rclone
        rclone config
        
        echo ""
        print_success "Configuración de rclone completada"
        echo ""
        
        # Listar remotos configurados
        print_info "Remotos de rclone configurados:"
        mapfile -t RCLONE_REMOTES < <(rclone listremotes)
        
        if [[ ${#RCLONE_REMOTES[@]} -gt 0 ]]; then
            for remote in "${RCLONE_REMOTES[@]}"; do
                echo "  • ${remote%:}"
            done
        else
            print_warning "No se configuraron remotos de rclone"
        fi
    fi
    
    echo ""
    read -p "Presiona ENTER para continuar..."
    clear
fi

# ==============================================================================
# PASO 5: Configurar destinos de backup
# ==============================================================================
print_header
print_step "5/9" "Configuración de destinos de backup"
echo ""
print_info "Ahora configura dónde se guardarán los backups"
print_info "Tipos de destinos:"
print_info "  1. Local/Montado: Rutas locales, NAS montados, unidades de red"
if [[ "$RCLONE_INSTALLED" == true && ${#RCLONE_REMOTES[@]} -gt 0 ]]; then
    print_info "  2. Rclone: Backups directos a la nube sin montar"
fi
echo ""

DESTINATIONS=()
dest_count=1

while true; do
    echo -e "${BOLD}Destino #$dest_count${NC}"
    echo ""
    
    # Tipo de destino
    DEST_TYPE="local"
    if [[ "$RCLONE_INSTALLED" == true && ${#RCLONE_REMOTES[@]} -gt 0 ]]; then
        echo "Tipo de destino:"
        echo "  1) Local/Montado"
        echo "  2) Rclone (nube)"
        read -p "Selecciona [1]: " TYPE_CHOICE
        TYPE_CHOICE="${TYPE_CHOICE:-1}"
        
        if [[ "$TYPE_CHOICE" == "2" ]]; then
            DEST_TYPE="rclone"
        fi
        echo ""
    fi
    
    if [[ "$DEST_TYPE" == "rclone" ]]; then
        # Configuración de destino rclone
        echo "Remotos disponibles:"
        for i in "${!RCLONE_REMOTES[@]}"; do
            echo "  $((i+1))) ${RCLONE_REMOTES[$i]%:}"
        done
        echo ""
        read -p "Selecciona el remoto [1]: " REMOTE_CHOICE
        REMOTE_CHOICE="${REMOTE_CHOICE:-1}"
        REMOTE_CHOICE=$((REMOTE_CHOICE - 1))
        
        if [[ $REMOTE_CHOICE -ge 0 && $REMOTE_CHOICE -lt ${#RCLONE_REMOTES[@]} ]]; then
            SELECTED_REMOTE="${RCLONE_REMOTES[$REMOTE_CHOICE]%:}"
            
            read -p "Nombre descriptivo [$SELECTED_REMOTE]: " DEST_NAME
            DEST_NAME="${DEST_NAME:-$SELECTED_REMOTE}"
            
            read -p "Ruta dentro del remoto (ej: backups/vaultwarden) [vaultwarden_backups]: " REMOTE_PATH
            REMOTE_PATH="${REMOTE_PATH:-vaultwarden_backups}"
            
            DESTINATIONS+=("$DEST_NAME|rclone:$SELECTED_REMOTE:$REMOTE_PATH|rclone|")
            print_success "Destino rclone agregado: $DEST_NAME -> $SELECTED_REMOTE:$REMOTE_PATH"
        else
            print_error "Selección inválida"
            continue
        fi
    else
        # Configuración de destino local/montado
        read -p "Nombre descriptivo (ej: Local, NAS): " DEST_NAME
        [[ -z "$DEST_NAME" ]] && break
        
        read -p "Ruta completa del destino: " DEST_PATH
        [[ -z "$DEST_PATH" ]] && break
        
        read -p "¿Requiere verificar montaje? (s/n) [n]: " REQUIRES_MOUNT
        REQUIRES_MOUNT="${REQUIRES_MOUNT:-n}"
        
        MOUNT_POINT=""
        if [[ "$REQUIRES_MOUNT" == "s" || "$REQUIRES_MOUNT" == "S" ]]; then
            read -p "Ruta del punto de montaje: " MOUNT_POINT
            DESTINATIONS+=("$DEST_NAME|$DEST_PATH|si|$MOUNT_POINT")
        else
            DESTINATIONS+=("$DEST_NAME|$DEST_PATH|no|")
        fi
        
        # Crear el directorio si no existe
        if mkdir -p "$DEST_PATH" 2>/dev/null; then
            print_success "Destino agregado: $DEST_NAME -> $DEST_PATH"
        else
            print_warning "No se pudo crear el directorio $DEST_PATH"
            print_warning "Asegúrate de tener permisos de escritura"
            print_info "El directorio se creará automáticamente en el primer backup si tienes permisos"
        fi
    fi
    
    echo ""
    read -p "¿Agregar otro destino? (s/n) [n]: " ADD_MORE
    [[ "$ADD_MORE" != "s" && "$ADD_MORE" != "S" ]] && break
    
    dest_count=$((dest_count + 1))
    echo ""
done

if [[ ${#DESTINATIONS[@]} -eq 0 ]]; then
    print_error "Debes configurar al menos un destino de backup"
    exit 1
fi

echo ""
print_success "Total de destinos configurados: ${#DESTINATIONS[@]}"
echo ""
read -p "Presiona ENTER para continuar..."
clear

# ==============================================================================
# PASO 6: Generar clave de cifrado
# ==============================================================================
print_header
print_step "6/9" "Generación de clave de cifrado"
echo ""
print_info "Se generará una clave segura para cifrar los backups"
echo ""

PASSPHRASE=$(generate_passphrase)

echo -e "${YELLOW}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ⚠️  IMPORTANTE ⚠️                           ║"
echo "║                                                               ║"
echo "║  GUARDA ESTA CLAVE EN UN LUGAR SEGURO                         ║"
echo "║  La necesitarás para restaurar los backups                    ║"
echo "║                                                               ║"
echo "║  Clave de cifrado:                                            ║"
echo "║                                                               ║"
printf "║  ${GREEN}%-59s${YELLOW}║\n" "$PASSPHRASE"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
print_info "Esta clave se guardará automáticamente en:"
print_info "  $BASE_DIR/.vaultwarden_backup_pass"
echo ""
read -p "¿Has guardado la clave? (s/n): " CONFIRM
if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
    print_warning "Por favor, guarda la clave antes de continuar"
    exit 1
fi

# Guardar passphrase
echo "$PASSPHRASE" > "$BASE_DIR/.vaultwarden_backup_pass"
chmod 600 "$BASE_DIR/.vaultwarden_backup_pass"
print_success "Clave guardada y protegida (chmod 600)"
echo ""
read -p "Presiona ENTER para continuar..."
clear

# ==============================================================================
# PASO 7: Configurar credenciales de Telegram (opcional)
# ==============================================================================
print_header
print_step "7/9" "Configuración de notificaciones Telegram (Opcional)"
echo ""
print_info "Puedes recibir notificaciones de los backups por Telegram"
print_info "Si no deseas configurarlo ahora, déjalo en blanco"
echo ""

read -p "Token del Bot de Telegram (Enter para omitir): " TELEGRAM_TOKEN
TELEGRAM_CHAT_ID=""
HOTCOPY_NOTIF_HOURS=0

if [[ -n "$TELEGRAM_TOKEN" ]]; then
    read -p "Chat ID de Telegram: " TELEGRAM_CHAT_ID
    print_success "Credenciales de Telegram configuradas"
    
    echo ""
    print_info "Configuración de frecuencia de notificaciones hotcopy:"
    print_info "  0 = Solo errores (sin notificaciones de éxito)"
    print_info "  1 = Cada hotcopy (cada hora)"
    print_info "  3 = Cada 3 horas"
    print_info "  6 = Cada 6 horas"
    echo ""
    print_warning "NOTA: Las notificaciones de Full Backup (diarias) siempre se envían"
    print_warning "      Los errores de hotcopy SIEMPRE se notifican"
    echo ""
    read -p "Frecuencia de notificaciones hotcopy [0]: " HOTCOPY_NOTIF_HOURS
    HOTCOPY_NOTIF_HOURS="${HOTCOPY_NOTIF_HOURS:-0}"
    
    if [[ $HOTCOPY_NOTIF_HOURS -eq 0 ]]; then
        print_success "Notificaciones hotcopy: solo errores"
    else
        print_success "Notificaciones hotcopy: cada ${HOTCOPY_NOTIF_HOURS}h"
    fi
else
    print_info "Telegram no configurado (puedes hacerlo después)"
fi

echo ""
read -p "Presiona ENTER para continuar..."
clear

# ==============================================================================
# PASO 8: Escribir configuración en el script
# ==============================================================================
print_header
print_step "8/9" "Generando script de backup configurado"
echo ""

# Copiar script al destino
if ! cp "$BACKUP_SCRIPT" "$BASE_DIR/backup_vaultwarden.sh" 2>/dev/null; then
    print_error "No se pudo copiar el script a $BASE_DIR"
    print_info "Verifica los permisos del directorio"
    exit 1
fi

chmod 700 "$BASE_DIR/backup_vaultwarden.sh"
if [[ $? -eq 0 ]]; then
    print_success "Script copiado y protegido (chmod 700)"
else
    print_warning "Script copiado pero no se pudieron establecer permisos 700"
fi

# Construir el array de destinos para el script (con formato correcto)
# No usamos variable con \n literales - los generaremos directamente en el archivo

# Usar sed para reemplazar configuraciones
cd "$BASE_DIR"

# Reemplazar TOKEN (permisivo: funciona con cualquier valor previo)
if [[ -n "$TELEGRAM_TOKEN" ]]; then
    sed -i "s|^TOKEN=.*|TOKEN=\"$TELEGRAM_TOKEN\"|" backup_vaultwarden.sh
fi

# Reemplazar CHAT_ID (permisivo: funciona con cualquier valor previo)
if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
    sed -i "s|^CHAT_ID=.*|CHAT_ID=\"$TELEGRAM_CHAT_ID\"|" backup_vaultwarden.sh
fi

# Reemplazar HOTCOPY_NOTIFICATION_HOURS
sed -i "s|^HOTCOPY_NOTIFICATION_HOURS=.*|HOTCOPY_NOTIFICATION_HOURS=$HOTCOPY_NOTIF_HOURS|" backup_vaultwarden.sh

# Reemplazar BASE_DIR
sed -i "s|^BASE_DIR=.*|BASE_DIR=\"$BASE_DIR\"|" backup_vaultwarden.sh

# Reemplazar SOURCE_DIR
sed -i "s|^SOURCE_DIR=.*|SOURCE_DIR=\"$SOURCE_DIR\"|" backup_vaultwarden.sh

# Reemplazar el array de BACKUP_DESTINATIONS
# Método robusto: copiar archivo en 3 partes (antes, nuevo array, después)

# Paso 1: Todo ANTES de BACKUP_DESTINATIONS
awk '
/^BACKUP_DESTINATIONS=\(/ { found=1; exit }
{ print }
' backup_vaultwarden.sh > backup_vaultwarden.sh.tmp

# Paso 2: Insertar el nuevo array (echo genera saltos de línea REALES)
echo "BACKUP_DESTINATIONS=(" >> backup_vaultwarden.sh.tmp
for dest in "${DESTINATIONS[@]}"; do
    echo "    \"$dest\"" >> backup_vaultwarden.sh.tmp
done
echo ")" >> backup_vaultwarden.sh.tmp

# Paso 3: Todo DESPUÉS del array antiguo (después del ) de cierre)
awk '
BEGIN { in_array=0; after_array=0 }

/^BACKUP_DESTINATIONS=\(/ {
    in_array=1
}

in_array && /^\)/ {
    in_array=0
    after_array=1
    next  # Saltar el ) de cierre
}

in_array {
    next  # Saltar contenido del array
}

after_array {
    print  # Imprimir todo después del array
}
' backup_vaultwarden.sh >> backup_vaultwarden.sh.tmp

# Verificar que el archivo se generó correctamente
if [[ ! -s backup_vaultwarden.sh.tmp ]]; then
    print_error "Fallo al generar configuración del script"
    rm -f backup_vaultwarden.sh.tmp
    exit 1
fi

# Reemplazar archivo original
mv backup_vaultwarden.sh.tmp backup_vaultwarden.sh
chmod 700 backup_vaultwarden.sh

print_success "Script configurado correctamente"
echo ""

# Crear archivo de log
if touch "$BASE_DIR/vaultwarden_backup.log" 2>/dev/null; then
    chmod 644 "$BASE_DIR/vaultwarden_backup.log"
    print_success "Archivo de log creado"
else
    print_warning "No se pudo crear el archivo de log"
    print_info "Se creará automáticamente en la primera ejecución del backup"
fi
echo ""
read -p "Presiona ENTER para continuar..."
clear

# ==============================================================================
# PASO 9: Resumen final
# ==============================================================================
print_header
print_step "9/9" "Instalación completada"
echo ""

echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║              ✓ INSTALACIÓN EXITOSA                            ║${NC}"
echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}📁 Ubicación del servicio:${NC}"
echo "   $BASE_DIR"
echo ""

echo -e "${BOLD}📋 Archivos creados:${NC}"
echo "   ├── backup_vaultwarden.sh    (chmod 700)"
echo "   ├── .vaultwarden_backup_pass (chmod 600)"
echo "   └── vaultwarden_backup.log   (chmod 644)"
echo ""

echo -e "${BOLD}⚙️  Configuración:${NC}"
echo "   • Origen: $SOURCE_DIR"
echo "   • Destinos: ${#DESTINATIONS[@]}"
for i in "${!DESTINATIONS[@]}"; do
    IFS='|' read -r name path req mount <<< "${DESTINATIONS[$i]}"
    echo "     $((i+1)). $name -> $path"
done
echo ""

echo -e "${BOLD}🔐 Clave de cifrado (GUÁRDALA):${NC}"
echo -e "   ${GREEN}$PASSPHRASE${NC}"
echo ""

echo -e "${BOLD}🚀 Próximos pasos:${NC}"
echo ""
echo "1. Probar el script manualmente:"
echo -e "   ${CYAN}cd $BASE_DIR${NC}"
echo -e "   ${CYAN}./backup_vaultwarden.sh hotcopy${NC}"
echo ""
echo "2. Programar en crontab:"
echo -e "   ${CYAN}crontab -e${NC}"
echo "   # Agregar estas líneas:"
echo -e "   ${YELLOW}# Hotcopy cada hora${NC}"
echo -e "   ${YELLOW}0 * * * * $BASE_DIR/backup_vaultwarden.sh hotcopy${NC}"
echo -e "   ${YELLOW}# Backup completo diario a las 3 AM${NC}"
echo -e "   ${YELLOW}0 3 * * * $BASE_DIR/backup_vaultwarden.sh${NC}"
echo ""
echo "3. Ver logs en tiempo real:"
echo -e "   ${CYAN}tail -f $BASE_DIR/vaultwarden_backup.log${NC}"
echo ""

echo -e "${BOLD}📚 Documentación:${NC}"
echo "   Ver README.md para más información"
echo ""
