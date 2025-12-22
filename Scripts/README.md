# Scripts

Простые скрипты для управления приложением в Docker.

## backup.sh
Резервное копирование PostgreSQL из Docker контейнера.

**Использование:**
```bash
./backup.sh
```

**Cron (ежедневно в 2:00):**
```
0 2 * * * /path/to/Scripts/backup.sh >> /var/log/backup.log 2>&1
```

**Конфигурация:**
- `BACKUP_DIR=/opt/backups` - директория для бэкапов
- `RETENTION_DAYS=7` - хранить бэкапы 7 дней
- `CONTAINER_NAME=postgres` - имя Docker контейнера
- `DB_USER=devops` - пользователь БД
- `DB_NAME=flask` - имя БД

## healthcheck.sh
Проверка работоспособности Docker контейнеров.

**Использование:**
```bash
./healthcheck.sh
```

**Cron (каждые 10 минут):**
```
*/10 * * * * /path/to/Scripts/healthcheck.sh
```

**Проверяет:**
- Flask app контейнер запущен
- PostgreSQL контейнер запущен
- Nginx контейнер запущен (на VM2)
- HTTP ответ приложения (200/302)
- Использование диска (<80%)

## setup.sh
Установка зависимостей для локальной разработки.

**Использование:**
```bash
./setup.sh
```

**Устанавливает:**
- Python 3.12
- Virtual environment
- Все зависимости из requirements.txt
- PostgreSQL client

**После установки:**
```bash
source flask-auth-example/venv/bin/activate
cd flask-auth-example
gunicorn main:app
```

## Примеры

### Восстановление из бэкапа
```bash
# Найти последний бэкап
LATEST_BACKUP=$(ls -t /opt/backups/postgres_*.sql.gz | head -1)

# Восстановить
gunzip < "$LATEST_BACKUP" | docker exec -i postgres psql -U devops -d flask
```

### Мониторинг логов
```bash
# Flask app
docker logs flask-app -f

# PostgreSQL
docker logs postgres -f

# Nginx
docker logs nginx -f
```

### Ручной healthcheck
```bash
# На VM1 (app + database)
./healthcheck.sh

# На VM2 (nginx)
curl -k https://localhost
docker ps
```
