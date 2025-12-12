#!/bin/bash

# backup.sh - Скрипт резервного копирования Flask приложения
# Использование: ./backup.sh
# Cron setup (ежедневно в 02:00): 0 2 * * * /path/to/Scripts/backup.sh >> /var/log/backup-cron.log 2>&1

set -e

# Конфигурация (используем абсолютные пути для cron)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && cd .. && pwd)"
APP_DIR="${PROJECT_ROOT}/flask-app"
BACKUP_DIR="${SCRIPT_DIR}/backups"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/backup.log"

# База данных
DB_TYPE="postgresql"

# Загрузить переменные окружения из .env
if [ -f "${APP_DIR}/.env" ]; then
    export $(grep -v '^#' "${APP_DIR}/.env" | xargs)
fi

# PostgreSQL настройки (из .env или значения по умолчанию)
PG_HOST="${DB_HOST:-localhost}"
PG_PORT="${DB_PORT:-5432}"
PG_USER="${DB_USER:-devops}"
PG_DATABASE="${DB_NAME:-flask}"
PG_PASSWORD="${DB_PASSWORD:-devops"}"



# Ротация бэкапов
RETENTION_DAYS=7


ALERT_EMAIL=""


mkdir -p "${BACKUP_DIR}"
mkdir -p "${LOG_DIR}"

# Функция логирования
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Функция для отправки уведомлений
send_notification() {
    local subject="$1"
    local message="$2"

    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    fi
}

# Проверка наличия необходимых утилит
check_requirements() {
    log "INFO" "Проверка необходимых утилит..."

    local missing_tools=()

    if ! command -v gzip &> /dev/null; then
        missing_tools+=("gzip")
    fi

    if [ "$DB_TYPE" = "postgresql" ]; then
        if ! command -v pg_dump &> /dev/null; then
            missing_tools+=("pg_dump")
        fi
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log "ERROR" "Отсутствуют необходимые утилиты: ${missing_tools[*]}"
        exit 1
    fi

    log "INFO" "Все необходимые утилиты установлены"
}


# Создание бэкапа PostgreSQL
backup_postgresql() {
    log "INFO" "Создание бэкапа PostgreSQL базы данных..."

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/postgres_${timestamp}.sql"
    local backup_gz="${backup_file}.gz"

    # Экспорт пароля из переменных окружения
    export PGPASSWORD="${DB_PASSWORD}"

    # Создать дамп в формате plain SQL (легче восстановить)
    if pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" --clean --if-exists > "${backup_file}"; then
        log "INFO" "Дамп PostgreSQL создан: ${backup_file}"

        # Сжать дамп
        if gzip "${backup_file}"; then
            local size=$(du -h "${backup_gz}" | cut -f1)
            log "INFO" "Дамп сжат: ${backup_gz} (${size})"
            echo "${backup_gz}"
            return 0
        else
            log "ERROR" "Ошибка при сжатии дампа"
            return 1
        fi
    else
        log "ERROR" "Ошибка при создании дампа PostgreSQL"
        return 1
    fi
}


# Создание бэкапа дополнительных файлов
backup_additional_files() {
    log "INFO" "Создание бэкапа дополнительных файлов..."

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/files_${timestamp}.tar.gz"

    # Список директорий и файлов для бэкапа
    local files_to_backup=(
        "${APP_DIR}/.env"
        "${APP_DIR}/data"
        "${APP_DIR}/uploads"
    )

    # Фильтровать существующие файлы
    local existing_files=()
    for file in "${files_to_backup[@]}"; do
        if [ -e "$file" ]; then
            existing_files+=("$file")
        fi
    done

    if [ ${#existing_files[@]} -eq 0 ]; then
        log "WARNING" "Нет файлов для бэкапа"
        return 0
    fi

    # Создать архив
    if tar -czf "${backup_file}" -C "${SCRIPT_DIR}" $(printf '%s\n' "${existing_files[@]}" | sed "s|${SCRIPT_DIR}/||g"); then
        local size=$(du -h "${backup_file}" | cut -f1)
        log "INFO" "Архив файлов создан: ${backup_file} (${size})"
        return 0
    else
        log "ERROR" "Ошибка при создании архива файлов"
        return 1
    fi
}

# Ротация старых бэкапов
rotate_backups() {
    log "INFO" "Ротация старых бэкапов (хранить последние ${RETENTION_DAYS} дней)..."

    local deleted_count=0

    # Найти и удалить старые бэкапы
    while IFS= read -r backup; do
        rm -f "$backup"
        deleted_count=$((deleted_count + 1))
        log "INFO" "Удален старый бэкап: $(basename "$backup")"
    done < <(find "${BACKUP_DIR}" -name "*.gz" -type f -mtime +${RETENTION_DAYS})

    if [ $deleted_count -gt 0 ]; then
        log "INFO" "Удалено старых бэкапов: ${deleted_count}"
    else
        log "INFO" "Старых бэкапов для удаления не найдено"
    fi

    # Показать текущее использование места
    local backup_size=$(du -sh "${BACKUP_DIR}" | cut -f1)
    local backup_count=$(find "${BACKUP_DIR}" -name "*.gz" -type f | wc -l)
    log "INFO" "Текущий размер директории бэкапов: ${backup_size} (файлов: ${backup_count})"
}

# Проверка целостности бэкапа
verify_backup() {
    local backup_file="$1"

    log "INFO" "Проверка целостности бэкапа..."

    if [ ! -f "$backup_file" ]; then
        log "ERROR" "Файл бэкапа не найден: ${backup_file}"
        return 1
    fi

    # Проверить gzip архив
    if gzip -t "$backup_file" 2>/dev/null; then
        log "INFO" "Бэкап прошел проверку целостности"
        return 0
    else
        log "ERROR" "Бэкап поврежден!"
        send_notification "Backup Failed" "Backup file is corrupted: ${backup_file}"
        return 1
    fi
}

# Генерация отчета
generate_report() {
    local status=$1
    local backup_file=$2
    local duration=$3

    cat <<EOF

========================================
Backup Report
========================================
Дата: $(date '+%Y-%m-%d %H:%M:%S')
Статус: ${status}
Файл: ${backup_file}
Продолжительность: ${duration} секунд
Размер бэкапа: $(du -h "${backup_file}" 2>/dev/null | cut -f1 || echo "N/A")
========================================

EOF
}

# Главная функция
main() {
    local start_time=$(date +%s)

    log "INFO" "========== Начало создания бэкапа =========="

    check_requirements

    local backup_file=""
    local status="SUCCESS"

    # Создать бэкап PostgreSQL
    if [ "$DB_TYPE" = "postgresql" ]; then
        backup_file=$(backup_postgresql) || status="FAILED"
    else
        log "ERROR" "Неподдерживаемый тип базы данных: ${DB_TYPE}"
        status="FAILED"
    fi

    # Бэкап дополнительных файлов
    backup_additional_files || log "WARNING" "Не удалось создать бэкап файлов"

    # Проверить целостность бэкапа
    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        verify_backup "$backup_file" || status="FAILED"
    fi

    # Ротация старых бэкапов
    rotate_backups

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Генерировать отчет
    generate_report "$status" "$backup_file" "$duration" | tee -a "${LOG_FILE}"

    if [ "$status" = "SUCCESS" ]; then
        log "INFO" "Бэкап завершен успешно за ${duration} секунд"
        send_notification "Backup Successful" "Backup completed in ${duration} seconds. File: ${backup_file}"
        exit 0
    else
        log "ERROR" "Бэкап завершен с ошибками"
        send_notification "Backup Failed" "Backup failed after ${duration} seconds. Check logs: ${LOG_FILE}"
        exit 1
    fi
}

# Запуск
main "$@"
