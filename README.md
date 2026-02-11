# Script de Backup Vaultwarden - Profesional

Sistema completo de backups para Vaultwarden con cifrado AES-256, multi-destino configurable y notificaciones inteligentes por Telegram.

## ✨ Características Principales

- 🔐 **Cifrado AES-256**: Todos los backups cifrados con GPG
- 🌐 **Multi-destino flexible**: Configura tantos destinos como necesites (local, NAS, nubes)
- ☁️ **Soporte rclone integrado**: Backups directos a nubes sin montar (Google Drive, OneDrive, S3, etc.)  
- ⚡ **Dos tipos de backup**: 
  - Hotcopy horario (solo base de datos)
  - Full diario (backup completo)
- 📊 **Notificaciones detalladas**: Reportes profesionales por Telegram con estadísticas
- � **Control de frecuencia de notificaciones**: Configura cada cuánto quieres recibir notificaciones de hotcopy (1h, 3h, 6h o solo errores)
- 🔍 **Validación automática**: Verifica integridad de BD y backups cifrados
- 🧹 **Retención inteligente**: Hotcopy 24h, Full 7 días con limpieza automática (incluye directorios vacíos)
- 🛡️ **Tolerancia a fallos**: Continúa funcionando si algunos destinos fallan
- 📝 **Logs centralizados**: Todo registrado con timestamps en un solo archivo
- 🤖 **Instalación automatizada**: Instala dependencias y configura todo automáticamente

## 📁 Estructura de Archivos

Todo centralizado en un único directorio configurable:

```
/home/usuario/servicio_backups/
├── backup_vaultwarden.sh    # Script principal (chmod 700)
├── vaultwarden_backup.log   # Logs del sistema
└── .vaultwarden_backup_pass # Clave de cifrado (chmod 600, oculta)
```

## 🚀 Instalación

### ⚡ Instalación Rápida (Recomendado)

**Comando de una sola línea:**

```bash
bash <(curl -sSL https://raw.githubusercontent.com/GamersEC/script_backups_vaultwarden/main/setup.sh)
```

**O si prefieres wget:**

```bash
bash <(wget -qO- https://raw.githubusercontent.com/GamersEC/script_backups_vaultwarden/main/setup.sh)
```

> 🛡️ **Nota de Seguridad**: Siempre revisa scripts antes de ejecutarlos con `curl | bash`. Puedes primero descargar y revisar:
> ```bash
> curl -O https://raw.githubusercontent.com/GamersEC/script_backups_vaultwarden/main/setup.sh
> cat setup.sh  # Revisar contenido
> chmod +x setup.sh
> ./setup.sh
> ```

**¿Qué hace este comando?**

1. ✅ Descarga automáticamente `setup.sh` y `backup_vaultwarden.sh`
2. ✅ Instala todas las dependencias necesarias
3. ✅ Configura el servicio completo interactivamente
4. ✅ Genera claves de cifrado seguras
5. ✅ Te guarda la passphrase de cifrado

---

### ⚙️ Requisitos Previos

**Permisos necesarios:**

- **Usuario normal**: Puede instalar el servicio en su directorio home (ej: `/home/usuario/servicio_backups`)
- **Permisos sudo**: Necesarios solo si faltan dependencias del sistema que instalar
- **Acceso de lectura**: Al directorio de datos de Vaultwarden (ej: `/opt/vaultwarden/data`)
- **Permisos de escritura**: En los directorios de destino de backups

**Sistema operativo compatible:**

- Ubuntu/Debian (apt)
- Fedora/RHEL/CentOS (dnf/yum)
- Arch Linux (pacman)
- openSUSE (zypper)

### Método 1: Instalador Interactivo (Recomendado)

El instalador te guía paso a paso en la configuración:

```bash
chmod +x setup.sh
./setup.sh
```

**¿Qué hace el instalador?**

1. **Verifica e instala dependencias**: sqlite3, gpg, curl, tar, rclone (opcional)
2. **Configura el directorio base** donde se instalará todo el servicio
3. **Pregunta por el origen de Vaultwarden** (ej: `/opt/vaultwarden/data`)
4. **Configura rclone (opcional)** para backups directos a la nube:
   - Google Drive, OneDrive, Dropbox, S3, Backblaze B2, etc.
   - Asistente interactivo guiado
   - Sin necesidad de montar unidades
5. **Permite agregar múltiples destinos** de backup:
   - Almacenamiento local
   - Unidades de red (NAS)
   - Nubes montadas
   - **Destinos rclone** (backups directos a la nube)
   - Para cada destino puedes configurar verificación de montaje
6. **Genera automáticamente una clave de cifrado segura** de 32 caracteres
7. **Muestra la clave para que la guardes** (¡IMPORTANTE!)
8. **Configura credenciales de Telegram** (opcional):
   - Token del bot
   - Chat ID
   - **Frecuencia de notificaciones hotcopy**: Elige cada cuánto recibir notificaciones (cada hora, cada 3h, solo errores, etc.)
9. **Crea todos los archivos** con permisos correctos

**Salida del instalador:**

```
╔═══════════════════════════════════════════════════════════════╗
║                    ⚠️  IMPORTANTE ⚠️                           ║
║                                                               ║
║  GUARDA ESTA CLAVE EN UN LUGAR SEGURO                         ║
║  La necesitarás para restaurar los backups                    ║
║                                                               ║
║  Clave de cifrado:                                            ║
║                                                               ║
║  aB3dE5fG7hJ9kL2mN4pQ6rS8tU1vW3xY                             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

### Método 2: Instalación Manual

<details>
<summary>Click para ver instrucciones manuales</summary>

```bash
# 1. Crear estructura
mkdir -p /home/usuario/servicio_backups
cd /home/usuario/servicio_backups

# 2. Copiar script
cp /ruta/al/backup_vaultwarden.sh .
chmod 700 backup_vaultwarden.sh

# 3. Generar y guardar passphrase
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32 > .vaultwarden_backup_pass
chmod 600 .vaultwarden_backup_pass

# Mostrar la clave (¡GUÁRDALA!)
cat .vaultwarden_backup_pass

# 4. Crear log
touch vaultwarden_backup.log
chmod 644 vaultwarden_backup.log

# 5. Editar configuración
nano backup_vaultwarden.sh
# Modificar:
#   - BASE_DIR
#   - SOURCE_DIR
#   - BACKUP_DESTINATIONS (array con tus destinos)
#   - TOKEN y CHAT_ID (Telegram, opcional)
```

</details>

## ⚙️ Configuración de Destinos

### Formato del Array de Destinos

En el script, los destinos se configuran así:

```bash
BACKUP_DESTINATIONS=(
    "Nombre|Ruta|Requiere_Montaje|Punto_Montaje"
)
```

### Ejemplos de Configuración

```bash
# Destino local (no requiere montaje)
"Local|/home/usuario/backups/local|no|"

# NAS Synology (requiere verificar montaje)
"NAS Synology|/mnt/nas/vaultwarden|si|/mnt/nas"

# Google Drive montado manualmente (requiere verificar montaje)
"Google Drive Montado|/mnt/gdrive/backups_vaultwarden|si|/mnt/gdrive"

# Google Drive con rclone (SIN montar, backup directo)
"Google Drive|rclone:gdrive_remote:vaultwarden_backups|rclone|"

# OneDrive con rclone
"OneDrive|rclone:onedrive:backups/vaultwarden|rclone|"

# Backblaze B2 con rclone
"Backblaze B2|rclone:b2_bucket:vaultwarden|rclone|"

# Amazon S3 con rclone
"AWS S3|rclone:s3_remote:my-bucket/vaultwarden|rclone|"
```

### Ejemplo Completo (Mixto: Local + NAS + Nubes con rclone)

```bash
BACKUP_DESTINATIONS=(
    "Local|/home/marcus/backups/local|no|"
    "NAS Principal|/mnt/nas01/vaultwarden_backups|si|/mnt/nas01"
    "Google Drive|rclone:gdrive:vaultwarden_backups|rclone|"
    "OneDrive Personal|rclone:onedrive:backups/vaultwarden|rclone|"
    "Backblaze B2|rclone:b2:vaultwarden-backup|rclone|"
)
```

### ☁️ Configuración de Rclone

Si usas destinos rclone, primero configura los remotos:

```bash
# Configurar un remoto de Google Drive
rclone config
# Seguir el asistente:
# 1. Nombre: gdrive
# 2. Tipo: drive (Google Drive)
# 3. Completar autenticación OAuth

# Configurar OneDrive
rclone config
# Nombre: onedrive
# Tipo: onedrive

# Verificar remotos configurados
rclone listremotes
```

**Ventajas de rclone:**
- ✅ No requiere montar unidades
- ✅ Transferencia directa y eficiente
- ✅ Soporte para +40 proveedores de nube
- ✅ Gestión automática de autenticación
- ✅ Compresión y encriptación en tránsito

Ver [documentación oficial de rclone](https://rclone.org/) para más detalles.

## 📋 Uso

### Ejecutar Manualmente

```bash
# Backup completo (diario)
cd /home/usuario/servicio_backups
./backup_vaultwarden.sh

# Hotcopy (horario, solo BD)
./backup_vaultwarden.sh hotcopy
```

### Programar en Crontab

```bash
crontab -e
```

Agregar estas líneas:

```cron
# Hotcopy cada hora
0 * * * * /home/usuario/servicio_backups/backup_vaultwarden.sh hotcopy

# Backup completo diario a las 3 AM
0 3 * * * /home/usuario/servicio_backups/backup_vaultwarden.sh
```

## 📊 Monitoreo

### Ver Logs en Tiempo Real

```bash
tail -f /home/usuario/servicio_backups/vaultwarden_backup.log
```

### Notificaciones de Telegram

Los mensajes incluyen:
- ⚡ Hotcopy: Duración, tamaños, estado de cada destino
- 🛡️ Full Backup: Archivos totales, ratio de compresión, distribución completa
- 🚨 Errores: Diagnóstico detallado, destinos fallidos, acciones requeridas

Ver ejemplos en [TELEGRAM_PREVIEW.md](TELEGRAM_PREVIEW.md)

## 🔐 Restaurar Backups

### Prerequisito: Tener la Clave de Cifrado

Necesitarás la passphrase que guardaste durante la instalación.

### Restaurar Hotcopy (solo BD)

```bash
cd /home/usuario/servicio_backups

# Opción 1: Usando archivo de passphrase
gpg --passphrase-file .vaultwarden_backup_pass \
    --decrypt /ruta/al/db_hot_2026-02-11_15-30.sqlite3.gpg \
    > db_restaurada.sqlite3

# Opción 2: Ingresando passphrase manualmente
gpg --decrypt /ruta/al/db_hot_2026-02-11_15-30.sqlite3.gpg \
    > db_restaurada.sqlite3
```

### Restaurar Full Backup

```bash
cd /home/usuario/servicio_backups

# Descomprimir y descifrar
gpg --passphrase-file .vaultwarden_backup_pass \
    --decrypt /ruta/al/VW_FULL_2026-02-11_03-00.tar.gz.gpg | \
    tar -xzf -

# Los archivos estarán descomprimidos en el directorio actual
```

### Aplicar Restauración

```bash
# 1. Detener Vaultwarden
sudo systemctl stop vaultwarden

# 2. Hacer backup del estado actual (por si acaso)
sudo mv /opt/vaultwarden/data /opt/vaultwarden/data.old

# 3. Para hotcopy (solo BD):
sudo mkdir -p /opt/vaultwarden/data
sudo cp db_restaurada.sqlite3 /opt/vaultwarden/data/db.sqlite3

# 4. Para full backup (todo):
sudo mv ruta_restaurada /opt/vaultwarden/data

# 5. Ajustar permisos
sudo chown -R vaultwarden:vaultwarden /opt/vaultwarden/data

# 6. Iniciar Vaultwarden
sudo systemctl start vaultwarden
```

## 🧹 Mantenimiento

### Rotar Logs

```bash
cd /home/usuario/servicio_backups

# Archivar log actual
gzip -c vaultwarden_backup.log > vaultwarden_backup_$(date +%Y%m%d).log.gz

# Limpiar log actual
> vaultwarden_backup.log
```

### Limpiar Logs Antiguos

```bash
# Eliminar logs comprimidos de más de 30 días
cd /home/usuario/servicio_backups
find . -name "vaultwarden_backup_*.log.gz" -mtime +30 -delete
```

### Ver Espacio Utilizado

```bash
# Tamaño total del directorio de servicio
du -sh /home/usuario/servicio_backups

# Tamaño de cada destino
du -sh /home/usuario/backups/local/hot
du -sh /home/usuario/backups/local/full
```

## 🔧 Mejoras Implementadas

### Seguridad
- ✅ Generación automática de passphrase segura (32 caracteres)
- ✅ Verificación de permisos (600 para passphrase, 700 para script)
- ✅ Validación de backups cifrados antes de distribuir
- ✅ Credenciales opcionales (funciona sin Telegram)

### Robustez
- ✅ Modo estricto bash (`set -euo pipefail`)
- ✅ Trap para limpieza automática de archivos temporales
- ✅ Verificación de dependencias (sqlite3, gpg, curl, tar, etc.)
- ✅ Verificación de espacio en disco (mínimo 500MB por destino)
- ✅ Tolerancia a fallos parciales (continúa si <50% de destinos fallan)

### Flexibilidad
- ✅ Destinos completamente configurables
- ✅ Número ilimitado de destinos
- ✅ Soporte para montajes opcionales (NAS, nubes)
- ✅ Origen de Vaultwarden configurable
- ✅ Instalador interactivo completo

### Funcionalidad
- ✅ Sistema de logs con timestamps
- ✅ Logs centralizados en un solo directorio
- ✅ Notificaciones detalladas con estadísticas
- ✅ Contador de archivos eliminados por retención
- ✅ Retención corregida: 7 días reales para full, 24h para hotcopy
- ✅ Validación de integridad de base de datos SQLite

### Monitoreo
- ✅ Reportes profesionales por Telegram
- ✅ Estado individual de cada destino
- ✅ Estadísticas de compresión y duración
- ✅ Diagnóstico detallado de errores
- ✅ Logs con niveles (INFO, WARN, ERROR)

## 📊 Estadísticas de Ejemplo

### Backup Completo
- **Archivos totales**: ~150-200
- **Tamaño original**: ~200-300MB
- **Tamaño comprimido+cifrado**: ~70-100MB
- **Ratio de compresión**: ~35-40%
- **Duración**: 2-4 minutos

### Hotcopy
- **Tamaño BD**: ~40-60MB
- **Tamaño cifrado**: ~30-50MB
- **Duración**: 3-8 segundos

## ❓ Preguntas Frecuentes

<details>
<summary><b>¿Necesito permisos de root para ejecutar el instalador?</b></summary>

No necesariamente. El instalador solo requiere `sudo` si necesita instalar dependencias faltantes (sqlite3, gpg, curl, rclone). Si todas las dependencias ya están instaladas, puedes ejecutarlo como usuario normal siempre que:
- Tengas permisos de lectura en el directorio de Vaultwarden
- Tengas permisos de escritura en el directorio de destino de backups

Si instalas en tu home (`/home/usuario/servicio_backups`), no necesitas privilegios especiales.
</details>

<details>
<summary><b>El instalador dice "No tienes permisos de escritura". ¿Qué hago?</b></summary>

Esto significa que no puedes crear directorios en la ubicación que elegiste. Soluciones:
- Usa un directorio en tu home: `/home/tu_usuario/servicio_backups`
- Si necesitas usar otra ubicación (ej: `/opt/backups`), créala primero con permisos adecuados:
  ```bash
  sudo mkdir -p /opt/backups
  sudo chown $USER:$USER /opt/backups
  ```
</details>

<details>
<summary><b>¿El script de backup necesita ejecutarse con sudo?</b></summary>

**Solo si:**
- El directorio de Vaultwarden requiere permisos de root para leer (ej: si está en `/opt` con permisos 700)
- Los destinos de backup requieren permisos elevados

**En la mayoría de casos NO**, especialmente si:
- Vaultwarden está en `/home/vaultwarden/data` con permisos adecuados
- Los backups van a directorios accesibles por tu usuario
- Has configurado correctamente los permisos de lectura/escritura

Si necesitas ejecutarlo con sudo, agrega `sudo` en tu crontab:
```bash
0 * * * * sudo /ruta/al/backup_vaultwarden.sh hotcopy
```
</details>

<details>
<summary><b>¿Puedo cambiar la passphrase después de la instalación?</b></summary>

Sí, pero deberás descifrar y volver a cifrar todos los backups existentes, o simplemente empezar de cero con la nueva clave.
</details>

<details>
<summary><b>¿Qué pasa si pierdo la clave de cifrado?</b></summary>

**No podrás restaurar los backups**. Por eso es crítico guardarla en múltiples lugares seguros (gestor de contraseñas, papel en caja fuerte, etc.).
</details>

<details>
<summary><b>¿Puedo agregar más destinos después de la instalación?</b></summary>

Sí, edita el script `backup_vaultwarden.sh` y modifica el array `BACKUP_DESTINATIONS` agregando nuevas líneas siguiendo el formato.
</details>

<details>
<summary><b>¿Qué pasa si falla un destino?</b></summary>

El script es tolerante a fallos. Si menos del 50% de los destinos fallan, el backup se marca como exitoso con advertencia. Solo falla si la mayoría de destinos son inaccesibles.
</details>

<details>
<summary><b>¿Puedo usar esto para otros servicios?</b></summary>

Sí, el script es adaptable. Solo necesitas modificar el `SOURCE_DIR` y ajustar la verificación de integridad si no usas SQLite.
</details>

<details>
<summary><b>¿Cómo puedo controlar la frecuencia de notificaciones de hotcopy?</b></summary>

Durante la instalación con `setup.sh`, se te preguntará la frecuencia de notificaciones hotcopy. Opciones:
- **0** (predeterminado): Solo notificar errores, no notificaciones de éxito
- **1**: Notificar cada hotcopy (cada hora)
- **3**: Notificar cada 3 horas
- **6**: Notificar cada 6 horas

Las notificaciones de Full Backup (diarias) y los errores de hotcopy **SIEMPRE** se envían.

Para cambiar después de la instalación, edita `backup_vaultwarden.sh`:
```bash
HOTCOPY_NOTIFICATION_HOURS=3  # Cambiar a la frecuencia deseada
```
</details>

## 🔧 Troubleshooting

### Error: `fusermount: option allow_other only allowed if 'user_allow_other' is set in /etc/fuse.conf`

**Problema común #1 con rclone mount**: Este es el error más frecuente al usar rclone con sistemas de archivos FUSE.

**Síntomas:**
- rclone mount falla con error de permisos
- Mensaje sobre `allow_other` o `user_allow_other`
- Los montajes de rclone no funcionan para usuarios no-root

**Solución:**

1. **Editar configuración de FUSE:**
   ```bash
   sudo nano /etc/fuse.conf
   ```

2. **Descomentar la línea:**
   ```bash
   # Buscar esta línea:
   #user_allow_other
   
   # Cambiarla a (sin el #):
   user_allow_other
   ```

3. **Guardar y salir:**
   - Presiona `Ctrl+O` para guardar
   - Presiona `Ctrl+X` para salir

4. **Reintentar el montaje:**
   ```bash
   rclone mount tu_remoto:ruta /punto/montaje --daemon
   ```

**Nota importante:** Este script usa **rclone copy directamente**, NO rclone mount, por lo que **NO deberías** encontrar este error. Solo lo verías si intentas montar manualmente servicios de nube con rclone mount.

### Error: `Failed to copy: directory not found`

**Síntomas:**
- rclone copy falla
- Mensaje de directorio no encontrado
- El backup falla en destinos rclone

**Solución:**

1. **Verificar configuración del remoto:**
   ```bash
   rclone listremotes
   ```
   Debe aparecer tu remoto configurado.

2. **Verificar conectividad:**
   ```bash
   rclone lsd nombre_remoto:
   ```
   Debe listar directorios o crear uno nuevo.

3. **Crear ruta manualmente:**
   ```bash
   rclone mkdir nombre_remoto:ruta/completa
   ```

4. **Verificar credenciales:**
   ```bash
   rclone config reconnect nombre_remoto:
   ```

### Error: `mount: only root can do that`

**Síntomas:**
- No puedes montar NAS o unidades de red
- Error de permisos al montar

**Solución para montajes CIFS/SMB:**

> ⚠️ **ADVERTENCIA CRÍTICA**: Editar `/etc/fstab` es delicado. Un error de sintaxis aquí puede **impedir que el sistema arranque**. Prueba siempre con `sudo mount -a` antes de reiniciar para verificar que no hay errores.

> 🛡️ **IMPORTANTE**: 
> - Haz una copia de seguridad antes: `sudo cp /etc/fstab /etc/fstab.backup`
> - Prueba con `sudo mount -a` ANTES de reiniciar
> - Ten a mano un LiveUSB por si necesitas reparar el archivo

1. **Hacer copia de seguridad:**
   ```bash
   sudo cp /etc/fstab /etc/fstab.backup
   ```

2. **Agregar entrada en /etc/fstab:**
   ```bash
   sudo nano /etc/fstab
   ```

3. **Agregar línea (ejemplo NAS):**
   ```
   //192.168.1.100/backups /home/usuario/nas cifs credentials=/home/usuario/.smbcreds,uid=1000,gid=1000 0 0
   ```

4. **Crear archivo de credenciales:**
   ```bash
   nano ~/.smbcreds
   ```
   ```
   username=tu_usuario
   password=tu_contraseña
   ```
   ```bash
   chmod 600 ~/.smbcreds
   ```

5. **IMPORTANTE - Probar ANTES de reiniciar:**
   ```bash
   sudo mount -a
   ```
   
   Si este comando da error, NO reinicies. Revisa la sintaxis en /etc/fstab. Si todo funciona correctamente, el montaje debería estar activo y persistirá al reiniciar.

### Error: `gpg: decryption failed: No secret key`

**Síntomas:**
- No puedes descifrar backups
- Perdiste la clave de cifrado

**Solución:**

**Si tienes el archivo `.vaultwarden_backup_pass`:**
```bash
cat /home/usuario/servicio_backups/.vaultwarden_backup_pass
```

**Para restaurar un backup:**
```bash
gpg --batch --passphrase-file /ruta/a/.vaultwarden_backup_pass -d backup.tar.gz.gpg | tar -xzf - -C /destino/
```

**Si perdiste la clave:** No hay recuperación posible. Por eso es crítico guardarla en múltiples ubicaciones seguras.

### Error: `sqlite3: database is locked`

**Síntomas:**
- El backup falla con "database is locked"
- Vaultwarden está escribiendo en la BD

**Solución:**

El script usa `.backup` de SQLite que maneja bloqueos automáticamente. Si persiste:

1. **Verificar que Vaultwarden no esté escribiendo excesivamente:**
   ```bash
   lsof /opt/vaultwarden/data/db.sqlite3
   ```

2. **Considerar ajustar el horario de hotcopy** para evitar períodos de alta actividad.

3. **Aumentar timeout de SQLite** (editar script):
   ```bash
   sqlite3 "$SOURCE_DIR/db.sqlite3" ".timeout 30000" ".backup '$TEMP_DB'"
   ```

### Error: `insufficient space on device`

**Síntomas:**
- El backup falla por falta de espacio
- Mensaje de espacio insuficiente

**Solución automática:** El script verifica espacio (mínimo 500MB) antes de ejecutar.

**Soluciones manuales:**

1. **Verificar espacio:**
   ```bash
   df -h /ruta/destino
   ```

2. **Reducir retención:**
   - Hotcopy: Cambiar de 24h a 12h
   - Full: Cambiar de 7 días a 3 días

3. **Limpiar manualmente backups antiguos:**
   ```bash
   # Para destinos locales
   find /ruta/destino/hot -type f -mtime +1 -delete
   find /ruta/destino/full -type f -mtime +3 -delete
   
   # Para destinos rclone
   rclone delete nombre_remoto:ruta/hot --min-age 24h --rmdirs
   rclone delete nombre_remoto:ruta/full --min-age 3d --rmdirs
   ```

### Error: Notificaciones de Telegram no llegan

**Síntomas:**
- El backup se ejecuta pero no recibes notificaciones
- No hay mensajes en Telegram

**Diagnóstico:**

1. **Verificar credenciales en el script:**
   ```bash
   grep -E "TOKEN|CHAT_ID" /home/usuario/servicio_backups/backup_vaultwarden.sh
   ```

2. **Probar manualmente el bot:**
   ```bash
   TOKEN="tu_token"
   CHAT_ID="tu_chat_id"
   curl -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=Test desde terminal"
   ```

3. **Verificar que curl está instalado:**
   ```bash
   command -v curl
   ```

4. **Verificar frecuencia de notificaciones hotcopy:**
   Si configuraste `HOTCOPY_NOTIFICATION_HOURS=0`, solo recibirás errores.

### Verificar que el sistema está funcionando correctamente

**Comando rápido de diagnóstico:**
```bash
# Ver últimos logs
tail -n 50 /home/usuario/servicio_backups/vaultwarden_backup.log

# Probar backup manualmente
cd /home/usuario/servicio_backups
./backup_vaultwarden.sh hotcopy

# Verificar cron
crontab -l | grep vaultwarden

# Verificar permisos
ls -lah /home/usuario/servicio_backups/
```

## 📄 Licencia

Este proyecto es de código abierto. Úsalo y modifícalo libremente.

## 🤝 Contribuciones

¿Encontraste un bug o tienes una mejora? ¡Pull requests bienvenidos!

---

**Desarrollado con ❤️ para la comunidad de Vaultwarden**
