#!/bin/bash

# ==============================================================================
# ACTUALIZADOR - SERVICIO DE BACKUPS VAULTWARDEN
# ==============================================================================
# Este script actualiza backup_vaultwarden.sh preservando toda la configuración

set -e

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║        ACTUALIZADOR - SERVICIO DE BACKUPS VAULTWARDEN         ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
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

# URL del repositorio
REPO_RAW_URL="https://raw.githubusercontent.com/GamersEC/script_backups_vaultwarden/main"

# Detectar directorio de instalación
if [[ "${BASH_SOURCE[0]}" =~ ^/dev/fd/ ]] || [[ -z "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

BACKUP_SCRIPT="$SCRIPT_DIR/backup_vaultwarden.sh"
TEMP_SCRIPT="/tmp/backup_vaultwarden_new.sh"

clear
print_header
echo ""

# Verificar que existe el script actual
if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    print_error "No se encuentra backup_vaultwarden.sh en: $SCRIPT_DIR"
    print_info "Ejecuta el instalador primero: setup.sh"
    exit 1
fi

print_info "Script actual: $BACKUP_SCRIPT"
echo ""

# Mostrar versión actual (fecha de modificación)
CURRENT_DATE=$(stat -c %y "$BACKUP_SCRIPT" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$BACKUP_SCRIPT" 2>/dev/null || echo "desconocida")
print_info "Última modificación local: $CURRENT_DATE"
echo ""

# Preguntar confirmación
read -p "¿Deseas actualizar el script preservando tu configuración? (s/n) [s]: " CONFIRM
CONFIRM="${CONFIRM:-s}"

if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
    print_info "Actualización cancelada"
    exit 0
fi

echo ""
print_info "Iniciando actualización..."
echo ""

# ============================================================================
# PASO 1: Extraer configuración actual
# ============================================================================
print_info "[1/6] Extrayendo configuración actual..."

TOKEN=$(grep '^TOKEN=' "$BACKUP_SCRIPT" | head -n1 | cut -d'=' -f2- | tr -d '"')
CHAT_ID=$(grep '^CHAT_ID=' "$BACKUP_SCRIPT" | head -n1 | cut -d'=' -f2- | tr -d '"')
HOTCOPY_HOURS=$(grep '^HOTCOPY_NOTIFICATION_HOURS=' "$BACKUP_SCRIPT" | head -n1 | cut -d'=' -f2)
BASE_DIR=$(grep '^BASE_DIR=' "$BACKUP_SCRIPT" | head -n1 | cut -d'=' -f2- | tr -d '"')
SOURCE_DIR=$(grep '^SOURCE_DIR=' "$BACKUP_SCRIPT" | head -n1 | cut -d'=' -f2- | tr -d '"')

# Extraer array de destinos (más complejo)
DESTINATIONS_TEMP="/tmp/backup_destinations_$$.tmp"
awk '/^BACKUP_DESTINATIONS=\(/,/^\)/' "$BACKUP_SCRIPT" > "$DESTINATIONS_TEMP"

print_success "Configuración extraída"
echo ""
print_info "  • TOKEN: ${TOKEN:+configurado}${TOKEN:-no configurado}"
print_info "  • CHAT_ID: ${CHAT_ID:+configurado}${CHAT_ID:-no configurado}"
print_info "  • Frecuencia notificaciones: ${HOTCOPY_HOURS}h"
print_info "  • Directorio base: $BASE_DIR"
print_info "  • Directorio origen: $SOURCE_DIR"
print_info "  • Destinos: $(grep -c '"' "$DESTINATIONS_TEMP" || echo 0) configurados"
echo ""

# ============================================================================
# PASO 2: Descargar nueva versión
# ============================================================================
print_info "[2/6] Descargando nueva versión desde GitHub..."

if command -v curl &> /dev/null; then
    if curl -fsSL "$REPO_RAW_URL/backup_vaultwarden.sh" -o "$TEMP_SCRIPT"; then
        print_success "Nueva versión descargada"
    else
        print_error "Fallo la descarga con curl"
        rm -f "$DESTINATIONS_TEMP"
        exit 1
    fi
elif command -v wget &> /dev/null; then
    if wget -q "$REPO_RAW_URL/backup_vaultwarden.sh" -O "$TEMP_SCRIPT"; then
        print_success "Nueva versión descargada"
    else
        print_error "Fallo la descarga con wget"
        rm -f "$DESTINATIONS_TEMP"
        exit 1
    fi
else
    print_error "No se encontró curl ni wget"
    rm -f "$DESTINATIONS_TEMP"
    exit 1
fi

echo ""

# ============================================================================
# PASO 3: Crear backup de versión actual
# ============================================================================
print_info "[3/6] Creando respaldo de la versión actual..."

BACKUP_FILE="$SCRIPT_DIR/backup_vaultwarden.sh.backup.$(date +%Y%m%d_%H%M%S)"
cp "$BACKUP_SCRIPT" "$BACKUP_FILE"
print_success "Backup guardado: $(basename "$BACKUP_FILE")"
echo ""

# ============================================================================
# PASO 4: Aplicar configuración a nueva versión
# ============================================================================
print_info "[4/6] Aplicando tu configuración a la nueva versión..."

# Reemplazar TOKEN
if [[ -n "$TOKEN" ]]; then
    sed -i "s|^TOKEN=.*|TOKEN=\"$TOKEN\"|" "$TEMP_SCRIPT"
    print_success "TOKEN aplicado"
fi

# Reemplazar CHAT_ID
if [[ -n "$CHAT_ID" ]]; then
    sed -i "s|^CHAT_ID=.*|CHAT_ID=\"$CHAT_ID\"|" "$TEMP_SCRIPT"
    print_success "CHAT_ID aplicado"
fi

# Reemplazar HOTCOPY_NOTIFICATION_HOURS
sed -i "s|^HOTCOPY_NOTIFICATION_HOURS=.*|HOTCOPY_NOTIFICATION_HOURS=$HOTCOPY_HOURS|" "$TEMP_SCRIPT"
print_success "Frecuencia de notificaciones aplicada"

# Reemplazar BASE_DIR
sed -i "s|^BASE_DIR=.*|BASE_DIR=\"$BASE_DIR\"|" "$TEMP_SCRIPT"
print_success "Directorio base aplicado"

# Reemplazar SOURCE_DIR
sed -i "s|^SOURCE_DIR=.*|SOURCE_DIR=\"$SOURCE_DIR\"|" "$TEMP_SCRIPT"
print_success "Directorio origen aplicado"

# Reemplazar array de BACKUP_DESTINATIONS
awk -v destinations="$(cat "$DESTINATIONS_TEMP")" '
BEGIN { in_array=0 }
/^BACKUP_DESTINATIONS=\(/ {
    print destinations
    in_array=1
    next
}
in_array && /^\)/ {
    in_array=0
    next
}
in_array {
    next
}
!in_array {
    print
}
' "$TEMP_SCRIPT" > "$TEMP_SCRIPT.tmp"

mv "$TEMP_SCRIPT.tmp" "$TEMP_SCRIPT"
print_success "Destinos de backup aplicados"

rm -f "$DESTINATIONS_TEMP"
echo ""

# ============================================================================
# PASO 5: Validar nueva versión
# ============================================================================
print_info "[5/6] Validando nueva versión..."

if bash -n "$TEMP_SCRIPT" 2>/dev/null; then
    print_success "Sintaxis del script validada correctamente"
else
    print_error "La nueva versión tiene errores de sintaxis"
    print_warning "No se aplicará la actualización"
    print_info "Tu versión actual permanece intacta"
    rm -f "$TEMP_SCRIPT"
    exit 1
fi

echo ""

# ============================================================================
# PASO 6: Reemplazar script con nueva versión
# ============================================================================
print_info "[6/6] Instalando nueva versión..."

cp "$TEMP_SCRIPT" "$BACKUP_SCRIPT"
chmod 700 "$BACKUP_SCRIPT"
rm -f "$TEMP_SCRIPT"

print_success "Script actualizado correctamente"
echo ""

# Resumen final
echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║              ✓ ACTUALIZACIÓN COMPLETADA                       ║${NC}"
echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_info "📦 Nueva versión instalada en: $BACKUP_SCRIPT"
print_info "💾 Backup de versión anterior: $(basename "$BACKUP_FILE")"
echo ""
print_info "✨ Toda tu configuración se ha preservado:"
echo "   • Credenciales de Telegram"
echo "   • Directorios de origen y destino"
echo "   • Destinos de backup configurados"
echo "   • Frecuencia de notificaciones"
echo ""
print_info "🚀 El servicio está listo para usar sin cambios adicionales"
echo ""
print_warning "Nota: Si hay cambios importantes en la nueva versión, revisa el README.md"
echo ""
