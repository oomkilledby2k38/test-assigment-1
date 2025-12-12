# Скрипты для Flask приложения на Ubuntu 24.04 ARM64

## Обзор

Три скрипта для управления Flask приложением с PostgreSQL на Ubuntu 24.04 ARM64:

1. **setup.sh** - установка зависимостей
2. **healthcheck.sh** - мониторинг здоровья приложения
3. **backup.sh** - резервное копирование базы данных

---

## 1. setup.sh - Установка зависимостей

### Что делает:
- Устанавливает Python 3.12 (стандарт для Ubuntu 24.04)
- Устанавливает PostgreSQL клиент и библиотеки (postgresql-client, libpq-dev)
- Создает виртуальное окружение в `flask-auth-example/venv`
- Устанавливает все зависимости из requirements.txt
- Проверяет подключение к PostgreSQL (если настроен .env)

### Использование:
```bash
cd Scripts
./setup.sh
```

### После установки:
```bash
# Активировать окружение
source ../flask-auth-example/venv/bin/activate

# Запустить приложение
cd ../flask-auth-example
gunicorn --bind 0.0.0.0:5000 main:app
```

---

## 2. healthcheck.sh - Мониторинг

### Что проверяет:
- HTTP статус веб-сервера (localhost:5000)
-  Доступность приложения через /register
-  Подключение к PostgreSQL
-  Использование дискового пространства (порог 80%)
-  Наличие процесса gunicorn
-  Systemd сервис (опционально)
-  Ошибки в логах приложения

### Использование:
```bash
./healthcheck.sh
```

### Логи:
- `logs/healthcheck.log` - основной лог
- `logs/healthcheck_alerts.log` - алерты и критические ошибки

### Настройка cron (каждые 10 минут):
```bash
# Открыть crontab
crontab -e

# Добавить строку (заменить /path/to/ на реальный путь):
*/10 * * * * /path/to/Scripts/healthcheck.sh >> /var/log/healthcheck-cron.log 2>&1
```

### Пример правильного пути:
```bash
*/10 * * * * /home/ubuntu/testovoe/1/Scripts/healthcheck.sh >> /var/log/healthcheck-cron.log 2>&1
```

---

## 3. backup.sh - Резервное копирование

### Что делает:
- Создает дамп PostgreSQL базы данных (plain SQL формат)
- Сжимает архив через gzip
- Выполняет ротацию (хранит последние 7 дней)
- Создает бэкап дополнительных файлов (.env, data/, uploads/)
- Проверяет целостность архива

### Использование:
```bash
./backup.sh
```

### Расположение бэкапов:
- `backups/postgres_YYYYMMDD_HHMMSS.sql.gz` - дамп БД
- `backups/files_YYYYMMDD_HHMMSS.tar.gz` - дополнительные файлы

### Настройка cron (ежедневно в 02:00):
```bash
# Открыть crontab
crontab -e

# Добавить строку (заменить /path/to/ на реальный путь):
0 2 * * * /path/to/Scripts/backup.sh >> /var/log/backup-cron.log 2>&1
```

### Восстановление из бэкапа:
```bash
# Распаковать архив
gunzip backups/postgres_20250112_020000.sql.gz

# Восстановить базу данных
psql -h DB_HOST -U DB_USER -d DB_NAME < backups/postgres_20250112_020000.sql
```

---

## Требования к системе

### Ubuntu 24.04 ARM64
- Python 3.12
- PostgreSQL клиент
- curl
- gzip
- systemd (опционально)

### Переменные окружения (.env)
Все скрипты используют переменные из `flask-auth-example/.env`:

```bash
SECRET_KEY=your-secret-key-here
DB_USER=your-db-username
DB_PASSWORD=your-db-password
DB_HOST=192.168.1.101
DB_PORT=5432
DB_NAME=flask
```

---

## Директории

```
Scripts/
├── setup.sh              # Установка
├── healthcheck.sh        # Мониторинг
├── backup.sh            # Бэкапы
├── logs/                # Логи скриптов
│   ├── healthcheck.log
│   ├── healthcheck_alerts.log
│   └── backup.log
└── backups/             # Бэкапы БД и файлов
    ├── postgres_*.sql.gz
    └── files_*.tar.gz
```

---

## ARM64 совместимость

✅ Все компоненты полностью совместимы с ARM64:
- Python 3.12 имеет нативную поддержку ARM64
- PostgreSQL отлично работает на ARM64
- Все Python пакеты имеют ARM64 wheels
- Системные утилиты (curl, gzip, psql) доступны на ARM64

---

## Примеры запуска

### Полная установка с нуля:
```bash
# 1. Установить зависимости
cd Scripts
./setup.sh

# 2. Активировать окружение
source ../flask-auth-example/venv/bin/activate

# 3. Запустить приложение
cd ../flask-auth-example
gunicorn --bind 0.0.0.0:5000 main:app

# 4. В другом терминале - проверить здоровье
cd Scripts
./healthcheck.sh

# 5. Создать бэкап
./backup.sh
```

### Настройка автоматизации:
```bash
# Добавить в crontab
crontab -e

# Добавить обе строки:
*/10 * * * * /home/ubuntu/testovoe/1/Scripts/healthcheck.sh >> /var/log/healthcheck-cron.log 2>&1
0 2 * * * /home/ubuntu/testovoe/1/Scripts/backup.sh >> /var/log/backup-cron.log 2>&1
```

---

## Troubleshooting

### Проблема: PostgreSQL недоступен
**Решение:** Проверить настройки в .env и доступность сервера
```bash
psql -h $DB_HOST -U $DB_USER -d $DB_NAME
```

### Проблема: Permission denied
**Решение:** Сделать скрипты исполняемыми
```bash
chmod +x setup.sh healthcheck.sh backup.sh
```

### Проблема: Cron не запускается
**Решение:** Использовать абсолютные пути в crontab и проверить логи
```bash
tail -f /var/log/healthcheck-cron.log
```

### Проблема: Нет места для бэкапов
**Решение:** Уменьшить RETENTION_DAYS в backup.sh или очистить старые бэкапы
```bash
# Изменить в backup.sh
RETENTION_DAYS=3  # Хранить 3 дня вместо 7
```
