#!/bin/bash

# healthcheck.sh - Скрипт мониторинга Flask приложения
# Использование: ./healthcheck.sh
# Cron setup (каждые 10 минут): */10 * * * * /path/to/Scripts/healthcheck.sh >> /var/log/healthcheck-cron.log 2>&1

set -e

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && cd .. && pwd)"
APP_DIR="${PROJECT_ROOT}/flask-auth-example"

# Загрузить переменные окружения из .env
if [ -f "${APP_DIR}/.env" ]; then
    export $(grep -v '^#' "${APP_DIR}/.env" | xargs)
fi

# URL приложения
APP_URL="http://localhost:5000"
REGISTER_ENDPOINT="${APP_URL}/register"

# Логи
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/healthcheck.log"
ALERT_LOG="${LOG_DIR}/healthcheck_alerts.log"


    DISK_THRESHOLD=80  # Процент использования диска
    MEMORY_THRESHOLD=80  # Процент использования памяти
    RESPONSE_TIME_THRESHOLD=5  # Секунды


    # Создать директорию для логов
    mkdir -p "${LOG_DIR}"

    # Функция логирования
    log() {
        local level=$1
        shift
        local message="$@"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
    }

    # Функция для алертов
    alert() {
        local message="$@"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[${timestamp}] ALERT: ${message}" >> "${ALERT_LOG}"

        # Отправить email если настроен
        if [ -n "$ALERT_EMAIL" ]; then
            echo "${message}" | mail -s "Flask App Health Alert" "$ALERT_EMAIL" 2>/dev/null || true
        fi
    }

    # Проверка HTTP статуса
    check_http_status() {
        log "INFO" "Проверка HTTP статуса..."

        local start_time=$(date +%s)
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${APP_URL}" 2>/dev/null || echo "000")
        local end_time=$(date +%s)
        local response_time=$((end_time - start_time))

        if [ "$http_code" = "200" ] || [ "$http_code" = "302" ]; then
            log "INFO" "HTTP статус: ${http_code} (OK) - Время ответа: ${response_time}s"

            if [ $response_time -gt $RESPONSE_TIME_THRESHOLD ]; then
                alert "Медленный ответ сервера: ${response_time}s (порог: ${RESPONSE_TIME_THRESHOLD}s)"
            fi

            return 0
        else
            log "ERROR" "HTTP статус: ${http_code} (FAILED)"
            alert "Веб-сервер недоступен. HTTP код: ${http_code}"
            return 1
        fi
    }

    # Проверка доступности приложения через /register
    check_app_endpoint() {
        log "INFO" "Проверка доступности приложения (/register)..."

        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${REGISTER_ENDPOINT}" 2>/dev/null || echo "000")

        if [ "$http_code" = "200" ]; then
            log "INFO" "Приложение доступно: /register вернул HTTP ${http_code}"
            return 0
        else
            log "ERROR" "Приложение недоступно: /register вернул HTTP ${http_code}"
            alert "Эндпоинт /register недоступен. HTTP код: ${http_code}"
            return 1
        fi
    }

    # Проверка Docker контейнера
    check_app_process() {
        log "INFO" "Проверка процесса приложения..."

        # Проверка наличия gunicorn процесса
        if pgrep -f "gunicorn.*main:app" > /dev/null; then
            local pid=$(pgrep -f "gunicorn.*main:app" | head -1)
            log "INFO" "Процесс приложения запущен (PID: ${pid})"

            # Проверка использования памяти процессом
            if command -v ps &> /dev/null; then
                local mem_usage=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | tr -d ' ')
                if [ -n "$mem_usage" ]; then
                    log "INFO" "Использование памяти процессом: ${mem_usage}%"
                fi
            fi

            return 0
        else
            log "ERROR" "Процесс приложения не найден"
            alert "Flask приложение не запущено"
            return 1
        fi
    }


    check_database() {
        log "INFO" "Проверка подключения к базе данных PostgreSQL..."

        # Проверка наличия переменных окружения
        if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_NAME" ]; then
            log "ERROR" "Переменные окружения БД не установлены"
            alert "Отсутствуют переменные окружения для подключения к PostgreSQL"
            return 1
        fi

        # Проверка доступности PostgreSQL
        if command -v psql &> /dev/null; then
            local db_check=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" -t 2>&1)

            if [ $? -eq 0 ]; then
                log "INFO" "База данных PostgreSQL: OK (${DB_HOST}:${DB_PORT:-5432}/${DB_NAME})"

                # Проверка количества подключений
                local conn_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USER" -d "$DB_NAME" \
                    -c "SELECT count(*) FROM pg_stat_activity WHERE datname='${DB_NAME}';" -t 2>/dev/null | tr -d ' ')

                if [ -n "$conn_count" ]; then
                    log "INFO" "Активных подключений к БД: ${conn_count}"
                fi

                return 0
            else
                log "ERROR" "Не удалось подключиться к PostgreSQL: ${db_check}"
                alert "Ошибка подключения к PostgreSQL: ${DB_HOST}:${DB_PORT:-5432}"
                return 1
            fi
        else
            log "WARNING" "psql не установлен, проверка БД пропущена"
            return 0
        fi
    }


    check_disk_space() {
        log "INFO" "Проверка дискового пространства..."

        local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

        log "INFO" "Использование диска: ${disk_usage}%"

        if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
            log "WARNING" "Высокое использование диска: ${disk_usage}%"
            alert "Критическое использование диска: ${disk_usage}% (порог: ${DISK_THRESHOLD}%)"
            return 1
        fi

        return 0
    }


    check_logs() {
        log "INFO" "Проверка логов приложения на критические ошибки..."

        # Проверка логов приложения, если они существуют
        local app_log="${APP_DIR}/logs/app.log"

        if [ -f "$app_log" ]; then
            local error_count=$(tail -100 "$app_log" 2>/dev/null | grep -i "error\|critical\|exception" | wc -l || echo "0")

            if [ "$error_count" -gt 10 ]; then
                log "WARNING" "Обнаружено ${error_count} ошибок в логах за последнее время"
                alert "Большое количество ошибок в логах: ${error_count}"
            else
                log "INFO" "Ошибок в логах: ${error_count}"
            fi
        else
            log "INFO" "Лог файл приложения не найден, пропускаю проверку"
        fi
    }


    check_systemd_service() {
        log "INFO" "Проверка systemd сервиса..."

        # Проверка наличия systemd сервиса
        if systemctl list-units --type=service --all | grep -q "flask-app.service"; then
            if systemctl is-active --quiet flask-app; then
                log "INFO" "Сервис flask-app: active"
                return 0
            else
                log "WARNING" "Сервис flask-app: inactive"
                return 1
            fi
        else
            log "INFO" "Systemd сервис flask-app не настроен (опционально)"
            return 0
        fi
    }


    generate_report() {
        local status=$1
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        cat <<EOF

    ========================================
    Flask Application Health Check Report
    ========================================
    Время проверки: ${timestamp}
    Общий статус: ${status}
    ========================================

    EOF
    }


    main() {
        log "INFO" "========== Начало проверки здоровья =========="

        local all_checks_passed=true
        local failed_checks=()


        check_systemd_service || { all_checks_passed=false; failed_checks+=("systemd_service"); }
        sleep 1

        check_app_process || { all_checks_passed=false; failed_checks+=("app_process"); }
        sleep 1

        check_http_status || { all_checks_passed=false; failed_checks+=("http_status"); }
        sleep 1

        check_app_endpoint || { all_checks_passed=false; failed_checks+=("app_endpoint"); }
        sleep 1

        check_database || { all_checks_passed=false; failed_checks+=("database"); }

        check_disk_space || { all_checks_passed=false; failed_checks+=("disk_space"); }

        check_logs


        if [ "$all_checks_passed" = true ]; then
            log "INFO" "Все проверки пройдены успешно ✓"
            generate_report "HEALTHY" >> "${LOG_FILE}"
            exit 0
        else
            log "ERROR" "Некоторые проверки не прошли: ${failed_checks[*]}"
            generate_report "UNHEALTHY" >> "${LOG_FILE}"
            alert "Healthcheck failed. Проваленные проверки: ${failed_checks[*]}"
            exit 1
        fi
    }

    # Запуск
    main "$@"
