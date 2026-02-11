# 📱 Vista Previa de Notificaciones Telegram

## ✅ Mensaje de Hotcopy Exitoso

```
━━━━━━━━━━━━━━━━━━━━━━
⚡ HOTCOPY COMPLETADO

━━━━━━━━━━━━━━━━━━━━━━

Servidor: vaultwarden-prod

━━━━━━━━━━━━━━━━━━━━━━
📊 ESTADÍSTICAS DEL BACKUP
━━━━━━━━━━━━━━━━━━━━━━

🔹 Información General
├─ Tipo: Hotcopy Incremental
├─ Timestamp: 2026-02-11 15:30
├─ Duración: 3s
└─ Archivo: db_hot_2026-02-11_15-30.sqlite3.gpg

💾 Tamaños
├─ BD Original: 45M
├─ Cifrado: 32M
└─ Registros: 1,247

🌐 Estado de Destinos
├─ ✅ Local /home/marcus/backups/local/hot/
├─ ✅ OneDrive /home/marcus/backups/onedrive/hot/
└─ ✅ Google Drive /home/marcus/backups/google_drive/hot/

⏰ Retención: 24 horas
🔐 Cifrado: AES-256 GPG

━━━━━━━━━━━━━━━━━━━━━━
```

## ✅ Mensaje de Full Backup Exitoso

```
━━━━━━━━━━━━━━━━━━━━━━━━━━
🛡️ VAULTWARDEN SECURE BACKUP

━━━━━━━━━━━━━━━━━━━━━━━━━━

Servidor: vaultwarden-prod

━━━━━━━━━━━━━━━━━━━━━━━━━━
🛡️ BACKUP COMPLETO DIARIO
━━━━━━━━━━━━━━━━━━━━━━━━━━

🔹 Información General
├─ Tipo: Full Backup (Completo)
├─ Timestamp: 2026-02-11 03:00
├─ Duración: 2m 34s
└─ Archivo: VW_FULL_2026-02-11_03-00.tar.gz.gpg

📦 Contenido del Backup
├─ Archivos totales: 156
├─ Registros BD: 1,247
├─ Tamaño original: 245M
├─ Tamaño final: 89M
└─ Compresión: 36.3% del original

🌐 Distribución Multicloud
├─ ✅ Almacenamiento Local
│  └─ /home/marcus/backups/local/full/
├─ ✅ Microsoft OneDrive
│  └─ /home/marcus/backups/onedrive/full/
└─ ✅ Google Drive
   └─ /home/marcus/backups/google_drive/full/

🔐 Seguridad
├─ Cifrado: AES-256 GPG
├─ Formato: tar.gz.gpg
└─ Integridad: ✅ Verificada

⏰ Política de Retención
└─ 7 días con versionado automático

━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Backup completado exitosamente
```

## ❌ Mensaje de Error en Hotcopy

```
❌ FALLO EN HOTCOPY

Servidor: vaultwarden-prod

❌ Error en distribución de hotcopy

Timestamp: 2026-02-11 15:30
Destinos fallidos: 2/3

Estado:
├─ ✅ Local
├─ ❌ FAILED OneDrive
└─ ❌ FAILED Google Drive

⚠️ Acción requerida: Verificar montajes y permisos
```

## 🚨 Mensaje de Error en Full Backup

```
🚨 FALLO CRÍTICO

Servidor: vaultwarden-prod

🚨 FALLO EN BACKUP DIARIO

⏰ Timestamp: 2026-02-11 03:00
📦 Tamaño backup: 89M
❌ Destinos fallidos: 1/3

Estado detallado:
├─ ✅ Local
├─ ✅ OneDrive
└─ ❌ FAILED Google Drive

⚠️ ACCIÓN REQUERIDA:
• Verificar montajes de unidades
• Comprobar permisos de escritura
• Revisar espacio disponible
• Consultar logs: /var/log/vaultwarden_backup.log
```

---

## 🎨 Características de las Notificaciones Mejoradas

### ✨ Mejoras Visuales
- **Separadores Unicode**: Uso de caracteres box-drawing (├─, └─) para estructura clara
- **Emojis profesionales**: Iconos contextuales que facilitan la lectura rápida
- **Jerarquía visual**: Indentación y símbolos para mostrar relaciones
- **Formato HTML**: Uso de `<b>` y `<code>` para resaltar información importante

### 📊 Información Detallada
- **Estadísticas completas**: Duración, tamaños, compresión, registros
- **Validación individual**: Estado específico de cada destino (Local, OneDrive, GDrive)
- **Ratio de compresión**: Porcentaje real de reducción de tamaño
- **Conteo de archivos**: Total de archivos incluidos en el backup

### 🔍 Diagnóstico de Errores
- **Contador de fallos**: Muestra cuántos destinos fallaron
- **Estado por destino**: Identifica exactamente dónde ocurrió el problema
- **Acciones específicas**: Lista de verificaciones a realizar
- **Referencia a logs**: Ruta exacta del archivo de log para investigación

### 🚀 Tolerancia a Fallos
- **Fallo parcial aceptable**: Si 1 de 3 destinos falla, el backup continúa
- **Fallo crítico**: Solo si 2 o más destinos fallan se marca como error
- **Variables de estado**: `DEST_STATUS_*` para tracking individual

