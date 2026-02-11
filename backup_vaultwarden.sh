#!/bin/bash

# ==============================================================================
# SERVICIO DE BACKUPS VAULTWARDEN
# ==============================================================================


set -euo pipefail  # Modo estricto: salir en errores, variables no definidas y errores en pipes

# --- CONFIGURACIÓN ---
# Este bloque es modificado automáticamente por setup.sh

# Credenciales de Telegram
TOKEN=""  # Token del bot de Telegram
CHAT_ID=""  # ID del chat de Telegram

# Frecuencia de notificaciones hotcopy (en horas)
# 0 = desactivar notificaciones hotcopy exitosas (solo errores)
# 1 = notificar cada hotcopy (cada hora)
# 3 = notificar cada 3 hotcopies (cada 3 horas)
HOTCOPY_NOTIFICATION_HOURS=0

# Directorio base del servicio
BASE_DIR="/home/marcus/servicio_backups"

# Directorio de origen de Vaultwarden
SOURCE_DIR="/opt/vaultwarden/data"

# Archivos del sistema
HOST=$(hostname)
PASSPHRASE_FILE="$BASE_DIR/.vaultwarden_backup_pass"
LOG_FILE="$BASE_DIR/vaultwarden_backup.log"
TEMP_FILES=()

# --- DESTINOS DE BACKUP ---
# Formato: "NOMBRE|RUTA|REQUIERE_MONTAJE"
# Ejemplo: "Local|/home/user/backups|no"
#          "Google Drive|/mnt/gdrive/backups|si"
BACKUP_DESTINATIONS=(
    "Local|/home/marcus/backups/local|no"
    "OneDrive|/home/marcus/backups/onedrive/backups_vaultwarden|si|/home/marcus/backups/onedrive"
    "Google Drive|/home/marcus/backups/google_drive/backups_vaultwarden|si|/home/marcus/backups/google_drive"
)

# --- TRAP PARA LIMPIEZA AUTOMÁTICA ---
cleanup() {
    local exit_code=$?
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        log "INFO" "Limpiando archivos temporales..."
        rm -f "${TEMP_FILES[@]}" 2>/dev/null || true
    fi
    [[ $exit_code -ne 0 ]] && log "ERROR" "Script finalizado con errores (código: $exit_code)"
    exit $exit_code
}
trap cleanup EXIT INT TERM

# --- FUNCIÓN DE LOGGING ---
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# --- FUNCIÓN DE NOTIFICACIÓN PROFESIONAL ---
send_notif() {
    local status_icon=$1
    local title=$2
    local body=$3
    
    # Solo notificar si están configuradas las credenciales
    if [[ -z "$TOKEN" ]] || [[ -z "$CHAT_ID" ]]; then
        log "WARN" "Notificación omitida: credenciales de Telegram no configuradas"
        return 0
    fi
    
    # Formateo del mensaje en HTML para Telegram
    local message="<b>$status_icon $title</b>%0A%0A"
    message+="<b>Servidor:</b> <code>$HOST</code>%0A"
    message+="$body"
    
    # Codificar caracteres HTML para URL
    message="${message//</%3C}"
    message="${message//>/%3E}"

    if curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
         -d "chat_id=$CHAT_ID" \
         -d "parse_mode=HTML" \
         -d "text=$message" > /dev/null 2>&1; then
        log "INFO" "Notificación enviada: $title"
    else
        log "ERROR" "Fallo al enviar notificación a Telegram"
    fi
}

# --- VERIFICACIÓN DE DEPENDENCIAS ---
check_dependencies() {
    local missing=()
    for cmd in sqlite3 gpg curl tar find mountpoint; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Verificar rclone solo si hay destinos que lo requieren
    local needs_rclone=false
    for dest_config in "${BACKUP_DESTINATIONS[@]}"; do
        IFS='|' read -r name path requires_mount mount_point <<< "$dest_config"
        if [[ "$path" == rclone:* ]]; then
            needs_rclone=true
            break
        fi
    done
    
    if [[ "$needs_rclone" == true ]] && ! command -v rclone &> /dev/null; then
        missing+=("rclone")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR" "Dependencias faltantes: ${missing[*]}"
        send_notif "🚨" "ERROR DE DEPENDENCIAS" "<b>Faltantes:</b> <code>${missing[*]}</code>"
        exit 1
    fi
    log "INFO" "Todas las dependencias están disponibles"
}

# --- VERIFICACIÓN DE ENTORNO ---
check_env() {
    log "INFO" "Iniciando verificaciones de entorno..."
    
    # 0. Verificar permisos del archivo de passphrase
    if [[ ! -f "$PASSPHRASE_FILE" ]]; then
        log "ERROR" "Archivo de passphrase no encontrado: $PASSPHRASE_FILE"
        send_notif "🚨" "ERROR DE CONFIGURACIÓN" "<b>Fallo:</b> Archivo de passphrase no existe."
        exit 1
    fi
    
    # Forzar permisos seguros (operación idempotente, portable entre Linux/BSD/macOS)
    chmod 600 "$PASSPHRASE_FILE" 2>/dev/null || {
        log "ERROR" "No se pueden establecer permisos en $PASSPHRASE_FILE"
        exit 1
    }
    log "INFO" "Permisos de passphrase verificados (600)"
    
    # 1. Verificar montajes y destinos
    for dest_config in "${BACKUP_DESTINATIONS[@]}"; do
        IFS='|' read -r name path requires_mount mount_point <<< "$dest_config"
        
        # Saltar verificación para destinos rclone (se verifican cuando se usan)
        if [[ "$path" == rclone:* ]]; then
            log "INFO" "Destino $name es rclone, se verificará al momento de usar"
            continue
        fi
        
        # Verificar si requiere montaje
        if [[ "$requires_mount" == "si" ]] && [[ -n "$mount_point" ]]; then
            if ! mountpoint -q "$mount_point"; then
                log "ERROR" "Montaje no disponible: $mount_point (requerido para $name)"
                send_notif "🚨" "ERROR DE MONTAJE" "<b>Fallo:</b> <code>$mount_point</code> no está montado.%0A<b>Destino afectado:</b> $name"
                exit 1
            fi
            log "INFO" "Montaje verificado: $mount_point ($name)"
        fi
        
        # Verificar espacio en disco (mínimo 500MB)
        if [[ -d "$path" ]] || mkdir -p "$path" 2>/dev/null; then
            local available=$(df -m "$path" | awk 'NR==2 {print $4}')
            if [[ $available -lt 500 ]]; then
                log "ERROR" "Espacio insuficiente en $name: ${available}MB disponibles"
                send_notif "🚨" "ESPACIO INSUFICIENTE" "<b>Destino:</b> $name%0A<b>Ruta:</b> <code>$path</code>%0A<b>Disponible:</b> ${available}MB"
                exit 1
            fi
            log "INFO" "Espacio verificado en $name: ${available}MB disponibles"
        else
            log "ERROR" "No se puede acceder o crear el destino: $path ($name)"
            exit 1
        fi
    done
    
    # 2. Verificar integridad de la base de datos (SQLite)
    if ! sqlite3 "$SOURCE_DIR/db.sqlite3" "PRAGMA integrity_check;" | grep -q "ok"; then
        log "ERROR" "Base de datos corrupta detectada"
        send_notif "☢️" "INTEGRIDAD FALLIDA" "<b>Fallo:</b> Base de datos corrupta detectada.%0A<b>Ruta:</b> <code>$SOURCE_DIR</code>"
        exit 1
    fi
    log "INFO" "Integridad de base de datos verificada"
}

# --- DISTRIBUCIÓN Y LIMPIEZA ---
distribute_and_clean() {
    local file=$1
    local type=$2 # "hot" o "full"
    local filename=$(basename "$file")
    
    # Arrays para almacenar el estado de cada destino
    declare -a DEST_NAMES
    declare -a DEST_PATHS
    declare -a DEST_STATUS
    DEST_FAIL_COUNT=0
    local index=0
    
    # Copiar a todos los destinos configurados
    for dest_config in "${BACKUP_DESTINATIONS[@]}"; do
        IFS='|' read -r name path requires_mount mount_point <<< "$dest_config"
        
        DEST_NAMES[$index]="$name"
        
        # Verificar si es destino rclone
        if [[ "$path" == rclone:* ]]; then
            # Formato: rclone:remote_name:remote_path
            local rclone_full="${path#rclone:}"
            local dest_path="$rclone_full/$type"
            DEST_PATHS[$index]="$dest_path"
            
            log "INFO" "Copiando a rclone: $dest_path"
            if rclone copy "$file" "$dest_path" --progress 2>&1 | tee -a "$LOG_FILE"; then
                DEST_STATUS[$index]="✅"
                log "INFO" "Copia exitosa: $name (rclone)"
            else
                DEST_STATUS[$index]="❌ FAILED"
                DEST_FAIL_COUNT=$((DEST_FAIL_COUNT + 1))
                log "ERROR" "Fallo al copiar a $name (rclone)"
            fi
        else
            # Destino local o montado
            local dest_path="$path/$type"
            DEST_PATHS[$index]="$dest_path"
            mkdir -p "$dest_path" 2>/dev/null
            
            if cp "$file" "$dest_path/" && [[ -f "$dest_path/$filename" ]]; then
                DEST_STATUS[$index]="✅"
                log "INFO" "Copia exitosa: $name -> $dest_path"
            else
                DEST_STATUS[$index]="❌ FAILED"
                DEST_FAIL_COUNT=$((DEST_FAIL_COUNT + 1))
                log "ERROR" "Fallo al copiar a $name ($dest_path)"
            fi
        fi
        
        index=$((index + 1))
    done
    
    # Si falló más de la mitad de los destinos, es crítico
    local total_dests=${#BACKUP_DESTINATIONS[@]}
    local max_fails=$((total_dests / 2))
    if [[ $DEST_FAIL_COUNT -gt $max_fails ]]; then
        log "ERROR" "Demasiados destinos fallidos: $DEST_FAIL_COUNT/$total_dests"
        return 1
    fi
    
    # Aplicar política de retención según el tipo
    for dest_config in "${BACKUP_DESTINATIONS[@]}"; do
        IFS='|' read -r name path requires_mount mount_point <<< "$dest_config"
        
        # Verificar si es destino rclone
        if [[ "$path" == rclone:* ]]; then
            local rclone_full="${path#rclone:}"
            local dest_path="$rclone_full/$type"
            
            if [[ "$type" == "hot" ]]; then
                # Borrar archivos con más de 24 horas usando rclone
                local deleted=$(rclone delete "$dest_path" --min-age 24h --rmdirs --dry-run 2>/dev/null | grep -c "Deleted" || echo "0")
                if [[ $deleted -gt 0 ]]; then
                    rclone delete "$dest_path" --min-age 24h --rmdirs 2>/dev/null
                    log "INFO" "$name (rclone): Eliminados $deleted backups antiguos (hot)"
                fi
            else
                # Borrar archivos con más de 7 días
                local deleted=$(rclone delete "$dest_path" --min-age 7d --rmdirs --dry-run 2>/dev/null | grep -c "Deleted" || echo "0")
                if [[ $deleted -gt 0 ]]; then
                    rclone delete "$dest_path" --min-age 7d --rmdirs 2>/dev/null
                    log "INFO" "$name (rclone): Eliminados $deleted backups antiguos (full)"
                fi
            fi
        else
            # Destino local o montado
            local dest_path="$path/$type"
            
            if [[ "$type" == "hot" ]]; then
                # Borrar archivos con más de 24 horas (1440 min)
                local deleted=$(find "$dest_path" -type f -mmin +1440 -delete -print 2>/dev/null | wc -l)
                [[ $deleted -gt 0 ]] && log "INFO" "$name: Eliminados $deleted backups antiguos (hot)"
            else
                # Borrar archivos con más de 7 días
                local deleted=$(find "$dest_path" -type f -mtime +7 -delete -print 2>/dev/null | wc -l)
                [[ $deleted -gt 0 ]] && log "INFO" "$name: Eliminados $deleted backups antiguos (full)"
            fi
        fi
    done
    
    return 0
}

# --- VALIDACIÓN DE BACKUP CIFRADO ---
validate_gpg_backup() {
    local file=$1
    log "INFO" "Validando backup cifrado: $file"
    
    if gpg --batch --passphrase-file "$PASSPHRASE_FILE" --list-packets "$file" &>/dev/null; then
        log "INFO" "Backup GPG válido"
        return 0
    else
        log "ERROR" "Backup GPG inválido o corrupto"
        return 1
    fi
}

# --- INICIO DEL PROCESO ---
log "INFO" "=== Iniciando script de backup Vaultwarden ==="
log "INFO" "Modo: ${1:-full}"

check_dependencies
check_env

TS_MSG=$(date +"%Y-%m-%d %H:%M")
TS_FILE=$(date +"%Y-%m-%d_%H-%M")

if [[ "$1" == "hotcopy" ]]; then
    # --- PROCESO HOTCOPY (CADA HORA) ---
    log "INFO" "Iniciando proceso HOTCOPY"
    START_TIME=$(date +%s)
    
    TEMP_DB="/tmp/vw_hot_$TS_FILE.sqlite3"
    FINAL_GPG="/tmp/db_hot_$TS_FILE.sqlite3.gpg"
    TEMP_FILES=("$TEMP_DB" "$FINAL_GPG")
    
    log "INFO" "Creando backup SQLite..."
    sqlite3 "$SOURCE_DIR/db.sqlite3" ".backup '$TEMP_DB'"
    DB_SIZE=$(du -h "$TEMP_DB" | cut -f1)
    
    log "INFO" "Cifrando backup..."
    gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase-file "$PASSPHRASE_FILE" -o "$FINAL_GPG" "$TEMP_DB"
    
    if ! validate_gpg_backup "$FINAL_GPG"; then
        send_notif "❌" "FALLO EN CIFRADO" "El archivo cifrado no es válido (hotcopy)."
        exit 1
    fi
    
    ENCRYPTED_SIZE=$(du -h "$FINAL_GPG" | cut -f1)
    DB_RECORDS=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM cipher;" 2>/dev/null || echo "N/A")
    
    if distribute_and_clean "$FINAL_GPG" "hot"; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        log "INFO" "Hotcopy distribuido exitosamente"
        
        # Construir reporte profesional con estadísticas
        REPORT="━━━━━━━━━━━━━━━━━━━━━━%0A"
        REPORT+="<b>📊 ESTADÍSTICAS DEL BACKUP</b>%0A"
        REPORT+="━━━━━━━━━━━━━━━━━━━━━━%0A%0A"
        REPORT+="<b>🔹 Información General</b>%0A"
        REPORT+="├─ <b>Tipo:</b> <code>Hotcopy Incremental</code>%0A"
        REPORT+="├─ <b>Timestamp:</b> <code>$TS_MSG</code>%0A"
        REPORT+="├─ <b>Duración:</b> <code>${DURATION}s</code>%0A"
        REPORT+="└─ <b>Archivo:</b> <code>$(basename "$FINAL_GPG")</code>%0A%0A"
        REPORT+="<b>💾 Tamaños</b>%0A"
        REPORT+="├─ <b>BD Original:</b> <code>$DB_SIZE</code>%0A"
        REPORT+="├─ <b>Cifrado:</b> <code>$ENCRYPTED_SIZE</code>%0A"
        REPORT+="└─ <b>Registros:</b> <code>$DB_RECORDS</code>%0A%0A"
        REPORT+="<b>🌐 Estado de Destinos</b>%0A"
        
        # Construir lista dinámica de destinos
        for i in "${!DEST_NAMES[@]}"; do
            local connector="├─"
            [[ $i -eq $((${#DEST_NAMES[@]} - 1)) ]] && connector="└─"
            REPORT+="$connector ${DEST_STATUS[$i]} <b>${DEST_NAMES[$i]}</b> <code>${DEST_PATHS[$i]}</code>%0A"
        done
        REPORT+="%0A"
        REPORT+="<b>⏰ Retención:</b> <code>24 horas</code>%0A"
        REPORT+="<b>🔐 Cifrado:</b> <code>AES-256 GPG</code>%0A%0A"
        REPORT+="━━━━━━━━━━━━━━━━━━━━━━"
        
        # Verificar si debe enviar notificación según frecuencia configurada
        SHOULD_NOTIFY=false
        if [[ $HOTCOPY_NOTIFICATION_HOURS -eq 1 ]]; then
            # Notificar cada hotcopy
            SHOULD_NOTIFY=true
        elif [[ $HOTCOPY_NOTIFICATION_HOURS -gt 1 ]]; then
            # Notificar cada N horas
            CURRENT_HOUR=$(date +%H)
            if (( CURRENT_HOUR % HOTCOPY_NOTIFICATION_HOURS == 0 )); then
                SHOULD_NOTIFY=true
            fi
        fi
        
        if [[ "$SHOULD_NOTIFY" == true ]]; then
            send_notif "⚡" "HOTCOPY COMPLETADO" "$REPORT"
        else
            log "INFO" "Notificación hotcopy omitida (frecuencia: cada ${HOTCOPY_NOTIFICATION_HOURS}h)"
        fi
        
        rm -f "$TEMP_DB" "$FINAL_GPG"
        TEMP_FILES=()
    else
        log "ERROR" "Fallo al distribuir hotcopy"
        ERROR_REPORT="<b>❌ Error en distribución de hotcopy</b>%0A%0A"
        ERROR_REPORT+="<b>Timestamp:</b> <code>$TS_MSG</code>%0A"
        ERROR_REPORT+="<b>Destinos fallidos:</b> <code>$DEST_FAIL_COUNT/${#BACKUP_DESTINATIONS[@]}</code>%0A%0A"
        ERROR_REPORT+="<b>Estado:</b>%0A"
        
        # Construir lista dinámica de destinos con errores
        for i in "${!DEST_NAMES[@]}"; do
            local connector="├─"
            [[ $i -eq $((${#DEST_NAMES[@]} - 1)) ]] && connector="└─"
            ERROR_REPORT+="$connector ${DEST_STATUS[$i]} ${DEST_NAMES[$i]}%0A"
        done
        ERROR_REPORT+="%0A"
        ERROR_REPORT+="<b>⚠️ Acción requerida:</b> Verificar montajes y permisos"
        send_notif "❌" "FALLO EN HOTCOPY" "$ERROR_REPORT"
        exit 1
    fi

else
    # --- PROCESO FULL BACKUP (DIARIO) ---
    log "INFO" "Iniciando proceso FULL BACKUP"
    START_TIME=$(date +%s)
    
    FINAL_FULL="/tmp/VW_FULL_$TS_FILE.tar.gz.gpg"
    TEMP_FILES=("$FINAL_FULL")
    
    # Obtener info previa
    TOTAL_FILES=$(find "$SOURCE_DIR" -type f | wc -l)
    UNCOMPRESSED_SIZE=$(du -sh "$SOURCE_DIR" | cut -f1)
    DB_RECORDS=$(sqlite3 "$SOURCE_DIR/db.sqlite3" "SELECT COUNT(*) FROM cipher;" 2>/dev/null || echo "N/A")
    
    log "INFO" "Comprimiendo y cifrando datos..."
    # Comprimir y encriptar en un solo flujo
    tar -czf - -C "$SOURCE_DIR" . | gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase-file "$PASSPHRASE_FILE" -o "$FINAL_FULL"
    
    if ! validate_gpg_backup "$FINAL_FULL"; then
        send_notif "❌" "FALLO EN CIFRADO" "El archivo cifrado no es válido (full backup)."
        exit 1
    fi
    
    COMPRESSED_SIZE=$(du -h "$FINAL_FULL" | cut -f1)
    COMPRESSED_SIZE_BYTES=$(du -b "$FINAL_FULL" | cut -f1)
    UNCOMPRESSED_SIZE_BYTES=$(du -sb "$SOURCE_DIR" | cut -f1)
    
    # Calcular ratio de compresión
    if [[ $UNCOMPRESSED_SIZE_BYTES -gt 0 ]]; then
        COMPRESSION_RATIO=$(awk "BEGIN {printf \"%.1f\", ($COMPRESSED_SIZE_BYTES / $UNCOMPRESSED_SIZE_BYTES) * 100}")
    else
        COMPRESSION_RATIO="N/A"
    fi
    
    log "INFO" "Backup creado: $COMPRESSED_SIZE (ratio: ${COMPRESSION_RATIO}%)"
    
    if distribute_and_clean "$FINAL_FULL" "full"; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        DURATION_MIN=$((DURATION / 60))
        DURATION_SEC=$((DURATION % 60))
        
        log "INFO" "Full backup distribuido exitosamente"
        
        # Construir reporte profesional detallado
        REPORT="━━━━━━━━━━━━━━━━━━━━━━━━━━%0A"
        REPORT+="<b>🛡️ BACKUP COMPLETO DIARIO</b>%0A"
        REPORT+="━━━━━━━━━━━━━━━━━━━━━━━━━━%0A%0A"
        REPORT+="<b>🔹 Información General</b>%0A"
        REPORT+="├─ <b>Tipo:</b> <code>Full Backup (Completo)</code>%0A"
        REPORT+="├─ <b>Timestamp:</b> <code>$TS_MSG</code>%0A"
        REPORT+="├─ <b>Duración:</b> <code>${DURATION_MIN}m ${DURATION_SEC}s</code>%0A"
        REPORT+="└─ <b>Archivo:</b> <code>$(basename "$FINAL_FULL")</code>%0A%0A"
        REPORT+="<b>📦 Contenido del Backup</b>%0A"
        REPORT+="├─ <b>Archivos totales:</b> <code>$TOTAL_FILES</code>%0A"
        REPORT+="├─ <b>Registros BD:</b> <code>$DB_RECORDS</code>%0A"
        REPORT+="├─ <b>Tamaño original:</b> <code>$UNCOMPRESSED_SIZE</code>%0A"
        REPORT+="├─ <b>Tamaño final:</b> <code>$COMPRESSED_SIZE</code>%0A"
        REPORT+="└─ <b>Compresión:</b> <code>${COMPRESSION_RATIO}%</code> del original%0A%0A"
        REPORT+="<b>🌐 Distribución Multicloud</b>%0A"
        
        # Construir lista dinámica de destinos para full backup
        for i in "${!DEST_NAMES[@]}"; do
            local connector="├─"
            local sub_connector="│"
            if [[ $i -eq $((${#DEST_NAMES[@]} - 1)) ]]; then
                connector="└─"
                sub_connector=" "
            fi
            REPORT+="$connector ${DEST_STATUS[$i]} <b>${DEST_NAMES[$i]}</b>%0A"
            REPORT+="$sub_connector  └─ <code>${DEST_PATHS[$i]}</code>%0A"
        done
        REPORT+="%0A"
        REPORT+="<b>🔐 Seguridad</b>%0A"
        REPORT+="├─ <b>Cifrado:</b> <code>AES-256 GPG</code>%0A"
        REPORT+="├─ <b>Formato:</b> <code>tar.gz.gpg</code>%0A"
        REPORT+="└─ <b>Integridad:</b> <code>✅ Verificada</code>%0A%0A"
        REPORT+="<b>⏰ Política de Retención</b>%0A"
        REPORT+="└─ <code>7 días con versionado automático</code>%0A%0A"
        REPORT+="━━━━━━━━━━━━━━━━━━━━━━━━━━%0A"
        REPORT+="<i>✅ Backup completado exitosamente</i>"
        
        send_notif "🛡️" "VAULTWARDEN SECURE BACKUP" "$REPORT"
        rm -f "$FINAL_FULL"
        TEMP_FILES=()
    else
        log "ERROR" "Fallo al distribuir full backup"
        
        ERROR_REPORT="<b>🚨 FALLO EN BACKUP DIARIO</b>%0A%0A"
        ERROR_REPORT+="<b>⏰ Timestamp:</b> <code>$TS_MSG</code>%0A"
        ERROR_REPORT+="<b>📦 Tamaño backup:</b> <code>$COMPRESSED_SIZE</code>%0A"
        ERROR_REPORT+="<b>❌ Destinos fallidos:</b> <code>$DEST_FAIL_COUNT/${#BACKUP_DESTINATIONS[@]}</code>%0A%0A"
        ERROR_REPORT+="<b>Estado detallado:</b>%0A"
        
        # Construir lista dinámica de destinos con errores
        for i in "${!DEST_NAMES[@]}"; do
            local connector="├─"
            [[ $i -eq $((${#DEST_NAMES[@]} - 1)) ]] && connector="└─"
            ERROR_REPORT+="$connector ${DEST_STATUS[$i]} ${DEST_NAMES[$i]}%0A"
        done
        ERROR_REPORT+="%0A"
        ERROR_REPORT+="<b>⚠️ ACCIÓN REQUERIDA:</b>%0A"
        ERROR_REPORT+="• Verificar montajes de unidades%0A"
        ERROR_REPORT+="• Comprobar permisos de escritura%0A"
        ERROR_REPORT+="• Revisar espacio disponible%0A"
        ERROR_REPORT+="• Consultar logs: <code>$LOG_FILE</code>"
        
        send_notif "🚨" "FALLO CRÍTICO" "$ERROR_REPORT"
        exit 1
    fi
fi

log "INFO" "=== Script finalizado exitosamente ==="