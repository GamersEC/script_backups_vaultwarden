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
# FUNCIONES AUXILIARES SEGURAS
# ============================================================================

# Función para escapar caracteres especiales en sed
# Maneja correctamente: & \ / | [ ] * $ ^ .
escape_sed() {
    local input="$1"
    # Escapar \ primero para evitar doble escape
    input="${input//\\/\\\\}"
    # Escapar & (usado en el replacement de sed)
    input="${input//&/\\&}"
    # Escapar / (delimitador común de sed)
    input="${input//\//\\/}"
    # Escapar | (delimitador alternativo de sed)
    input="${input//|/\\|}"
    # Caracteres especiales de regex
    input="${input//\[/\\[}"
    input="${input//\]/\\]}"
    input="${input//\*/\\*}"
    input="${input//\./\\.}"
    input="${input//\^/\\^}"
    input="${input//\$/\\$}"
    printf '%s' "$input"
}

# Función para extraer variables de forma segura usando source
extract_config_safe() {
    local script_path="$1"
    local extractor_script="/tmp/config_extractor_$$.sh"
    
    # Crear script extractor temporal
    cat > "$extractor_script" << 'EXTRACTOR_EOF'
#!/bin/bash
# Deshabilitar set -e temporalmente para permitir source
set +e

# Source del script de backup (solo para leer variables)
source "$1" 2>/dev/null || {
    echo "ERROR_SOURCING"
    exit 1
}

# Imprimir variables en formato seguro (cada una en su línea)
echo "TOKEN=${TOKEN}"
echo "CHAT_ID=${CHAT_ID}"
echo "HOTCOPY_NOTIFICATION_HOURS=${HOTCOPY_NOTIFICATION_HOURS}"
echo "BASE_DIR=${BASE_DIR}"
echo "SOURCE_DIR=${SOURCE_DIR}"

# Para el array BACKUP_DESTINATIONS, necesitamos un approach diferente
# Lo extraeremos directamente del archivo
EXTRACTOR_EOF

    chmod +x "$extractor_script"
    
    # Ejecutar extractor y capturar salida
    local output
    output=$("$extractor_script" "$script_path" 2>/dev/null)
    
    if [[ "$output" == "ERROR_SOURCING" ]]; then
        rm -f "$extractor_script"
        return 1
    fi
    
    # Parsear salida de forma segura
    while IFS='=' read -r key value; do
        case "$key" in
            TOKEN) TOKEN="$value" ;;
            CHAT_ID) CHAT_ID="$value" ;;
            HOTCOPY_NOTIFICATION_HOURS) HOTCOPY_HOURS="$value" ;;
            BASE_DIR) BASE_DIR="$value" ;;
            SOURCE_DIR) SOURCE_DIR="$value" ;;
        esac
    done <<< "$output"
    
    rm -f "$extractor_script"
    return 0
}

# ============================================================================
# PASO 1: Extraer configuración actual (MÉTODO SEGURO)
# ============================================================================
print_info "[1/6] Extrayendo configuración actual de forma segura..."

# Variables globales para la configuración
TOKEN=""
CHAT_ID=""
HOTCOPY_HOURS=""
BASE_DIR=""
SOURCE_DIR=""

# Extraer variables simples mediante source seguro
if ! extract_config_safe "$BACKUP_SCRIPT"; then
    print_warning "No se pudo hacer source del script, usando método alternativo..."
    
    # Fallback: extracción manual pero más robusta
    TOKEN=$(awk -F'=' '/^TOKEN=/ {print $2; exit}' "$BACKUP_SCRIPT" | sed 's/^"//; s/"$//')
    CHAT_ID=$(awk -F'=' '/^CHAT_ID=/ {print $2; exit}' "$BACKUP_SCRIPT" | sed 's/^"//; s/"$//')
    HOTCOPY_HOURS=$(awk -F'=' '/^HOTCOPY_NOTIFICATION_HOURS=/ {print $2; exit}' "$BACKUP_SCRIPT")
    BASE_DIR=$(awk -F'=' '/^BASE_DIR=/ {print $2; exit}' "$BACKUP_SCRIPT" | sed 's/^"//; s/"$//')
    SOURCE_DIR=$(awk -F'=' '/^SOURCE_DIR=/ {print $2; exit}' "$BACKUP_SCRIPT" | sed 's/^"//; s/"$//')
fi

# Extraer array de destinos TAL CUAL (sin procesamiento)
ARRAY_TEMP="/tmp/backup_array_$$.tmp"
awk '/^BACKUP_DESTINATIONS=\(/,/^\)/' "$BACKUP_SCRIPT" > "$ARRAY_TEMP"

# Contar destinos configurados
DEST_COUNT=$(grep -c '"' "$ARRAY_TEMP" 2>/dev/null || echo 0)

print_success "Configuración extraída de forma segura"
echo ""
print_info "  • TOKEN: ${TOKEN:+configurado}${TOKEN:-no configurado}"
print_info "  • CHAT_ID: ${CHAT_ID:+configurado}${CHAT_ID:-no configurado}"
print_info "  • Frecuencia notificaciones: ${HOTCOPY_HOURS}h"
print_info "  • Directorio base: $BASE_DIR"
print_info "  • Directorio origen: $SOURCE_DIR"
print_info "  • Destinos: $DEST_COUNT configurados"
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
        rm -f "$ARRAY_TEMP"
        exit 1
    fi
elif command -v wget &> /dev/null; then
    if wget -q "$REPO_RAW_URL/backup_vaultwarden.sh" -O "$TEMP_SCRIPT"; then
        print_success "Nueva versión descargada"
    else
        print_error "Fallo la descarga con wget"
        rm -f "$ARRAY_TEMP"
        exit 1
    fi
else
    print_error "No se encontró curl ni wget"
    rm -f "$ARRAY_TEMP"
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
# PASO 4: Aplicar configuración a nueva versión (MÉTODO SEGURO)
# ============================================================================
print_info "[4/6] Aplicando tu configuración a la nueva versión de forma segura..."

# Detectar si estamos en macOS (para sed -i compatible)
if sed --version 2>&1 | grep -q "GNU sed"; then
    SED_INPLACE="sed -i"
else
    # macOS y BSD requieren argumento vacío después de -i
    SED_INPLACE="sed -i ''"
fi

# Escapar valores para uso seguro en sed
TOKEN_ESCAPED=$(escape_sed "$TOKEN")
CHAT_ID_ESCAPED=$(escape_sed "$CHAT_ID")
BASE_DIR_ESCAPED=$(escape_sed "$BASE_DIR")
SOURCE_DIR_ESCAPED=$(escape_sed "$SOURCE_DIR")

# Reemplazar TOKEN (método seguro con delimitador #)
if [[ -n "$TOKEN" ]]; then
    sed -i.bak "s#^TOKEN=.*#TOKEN=\"$TOKEN_ESCAPED\"#" "$TEMP_SCRIPT" && rm -f "$TEMP_SCRIPT.bak"
    print_success "TOKEN aplicado"
fi

# Reemplazar CHAT_ID (método seguro con delimitador #)
if [[ -n "$CHAT_ID" ]]; then
    sed -i.bak "s#^CHAT_ID=.*#CHAT_ID=\"$CHAT_ID_ESCAPED\"#" "$TEMP_SCRIPT" && rm -f "$TEMP_SCRIPT.bak"
    print_success "CHAT_ID aplicado"
fi

# Reemplazar HOTCOPY_NOTIFICATION_HOURS (numérico, sin escape necesario)
if [[ -n "$HOTCOPY_HOURS" ]]; then
    sed -i.bak "s#^HOTCOPY_NOTIFICATION_HOURS=.*#HOTCOPY_NOTIFICATION_HOURS=$HOTCOPY_HOURS#" "$TEMP_SCRIPT" && rm -f "$TEMP_SCRIPT.bak"
    print_success "Frecuencia de notificaciones aplicada"
fi

# Reemplazar BASE_DIR (método seguro con delimitador #)
if [[ -n "$BASE_DIR" ]]; then
    sed -i.bak "s#^BASE_DIR=.*#BASE_DIR=\"$BASE_DIR_ESCAPED\"#" "$TEMP_SCRIPT" && rm -f "$TEMP_SCRIPT.bak"
    print_success "Directorio base aplicado"
fi

# Reemplazar SOURCE_DIR (método seguro con delimitador #)
if [[ -n "$SOURCE_DIR" ]]; then
    sed -i.bak "s#^SOURCE_DIR=.*#SOURCE_DIR=\"$SOURCE_DIR_ESCAPED\"#" "$TEMP_SCRIPT" && rm -f "$TEMP_SCRIPT.bak"
    print_success "Directorio origen aplicado"
fi

# ============================================================================
# Inyección "quirúrgica" del array BACKUP_DESTINATIONS
# ============================================================================

# Archivos temporales para ensamblaje
BEFORE_ARRAY="/tmp/before_array_$$.tmp"
AFTER_ARRAY="/tmp/after_array_$$.tmp"
ASSEMBLED="/tmp/assembled_$$.tmp"

# Extraer la parte ANTES del array en el nuevo script
awk '/^BACKUP_DESTINATIONS=\(/ {exit} {print}' "$TEMP_SCRIPT" > "$BEFORE_ARRAY"

# Extraer la parte DESPUÉS del array en el nuevo script (incluyendo el cierre)
awk '
BEGIN { found=0; in_array=0 }
/^BACKUP_DESTINATIONS=\(/ { in_array=1; next }
in_array && /^\)/ { found=1; next }
found { print }
' "$TEMP_SCRIPT" > "$AFTER_ARRAY"

# Ensamblar: ANTES + ARRAY_ANTIGUO + DESPUÉS
cat "$BEFORE_ARRAY" > "$ASSEMBLED"
cat "$ARRAY_TEMP" >> "$ASSEMBLED"
cat "$AFTER_ARRAY" >> "$ASSEMBLED"

# Reemplazar el script temporal con la versión ensamblada
mv "$ASSEMBLED" "$TEMP_SCRIPT"

# Limpiar archivos temporales de ensamblaje
rm -f "$BEFORE_ARRAY" "$AFTER_ARRAY" "$ARRAY_TEMP"

print_success "Destinos de backup aplicados (método quirúrgico)"

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
