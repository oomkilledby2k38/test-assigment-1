# Базовые требования

1. Ubuntu 24.04 LTS 2 CPUs 2GB RAM 10 GB DISK
2. Ubuntu 24.04 LTS 2 CPUs 2GB RAM 10 GB DISK

## Создание пользователя

```shell
sudo adduser devops
```

## Права sudo

```shell
sudo vim /etc/sudeoers %devops ALL=(ALL) ALL
```

## ufw / iptables

```shell
sudo ufw enable
```

## ufw allow 22 443 ports and etc

```shell
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 52/udp
sudo ufw allow from 192.168.1.122 to any port 22 # локальная машина
```

Такие же правила на второй виртуальной машине

Так как приложение находиться в Docker образе, Docker обходит ufw, поэтому нужно добавить правила в iptables

```shell
devops@server1:~$ sudo iptables -I DOCKER-USER -p tcp --dport 5000 -j DROP
devops@server1:~$ sudo iptables -I DOCKER-USER -s 192.168.1.137 -p tcp --dport 5000 -j ACCEPT # Вторая локальная машина , где находится nginx
```

## Password Authenfication и  Root login

```shell
sudo nano /etc/ssh/sshd_config
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

## Установка Docker и PostgreSQL

[Docker](https://docs.docker.com/engine/install/)

[PostgreSQL](hub.docker.com/_/postgres/)

```yaml
services:
  postgres:
    image: postgres:15
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: devops
      POSTGRES_PASSWORD: devops
      POSTGRES_DB: flask
      POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256"
    command: >
      postgres
      -c log_statement=all
      -c log_destination=stderr
      -c logging_collector=off
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
```

## Flask приложение

1. git clone
2. Dockerfile

```
#  Builder
FROM python:3.11-alpine AS builder

WORKDIR /app


RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    postgresql-dev


COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install --prefer-binary -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-alpine

WORKDIR /app


RUN apk add --no-cache libpq

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY . .


RUN adduser -D -u 1000 appuser && chown -R appuser:appuser /app
USER appuser


EXPOSE 5000

# Set environment variables
ENV FLASK_ENV=production \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1


CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "2", "--worker-class", "gthread", "--timeout", "30", "main:app"]
```

3. Окружение .env

```
SECRET_KEY=YOUR-SECRET-KEY-HERE
DB_USER=devops
DB_PASSWORD=devops
DB_HOST=192.168.1.101
DB_PORT=5432
DB_NAME=flask
```

4. Systemd-service

```
[Unit]
Description=Flask Application (Docker)
After=docker.service
Requires=docker.service

[Service]
Restart=always
RestartSec=5
TimeoutStartSec=0


StandardOutput=append:/var/log/flask-app.log
StandardError=append:/var/log/flask-app.log


ExecStartPre=/bin/mkdir -p /var/log


ExecStartPre=/usr/bin/docker rm -f flask-application


ExecStart=/usr/bin/docker run \
  --name flask-application \
  -p 5000:5000 \
  kirill4goodmopsa/flask-app


ExecStop=/usr/bin/docker stop flask-application

# Обязательно не убивать дочерние процессы
KillMode=process

[Install]
WantedBy=multi-user.target
```

# Установка nginx и проксирование на VM1

### Структура

```text
.
└── nginx
├── conf.d
│ └── flask-proxy.conf
├── docker-compose.yaml
└── nginx.conf
```

### Docker Compose для nginx

```
version: '3.8'

services:
  nginx:
    image: nginx:1.29-alpine  # лёгкая версия
    container_name: nginx-proxy
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro 
      - ./conf.d:/etc/nginx/conf.d:ro
      - nginx_cache:/var/cache/nginx  # volume для кеша
    restart: unless-stopped
    networks:
      - proxy-net

volumes:
  nginx_cache:

networks:
  proxy-net:
    driver: bridge
    
```

### Конфиг nginx

```
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    # --------------------------
    # GZIP сжатие
    # --------------------------
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/json
        application/xml
        application/rss+xml
        image/svg+xml;

    # --------------------------
    # Настройки прокси
    # --------------------------
    proxy_set_header Host $host; # передает запрос клиента в бек
    proxy_set_header X-Real-IP $remote_addr; # реальный ip клиента
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; # Добавляет ip клиента в цепочку прокси
    proxy_set_header X-Forwarded-Proto $scheme; # сообщает беку , какой используется протокол http/https

    # --------------------------
    # Включаем кеширование на основе заголовков от Flask
    # --------------------------
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g 
                     inactive=60m use_temp_path=off;

    # --------------------------
    # Включаем сайт
    # --------------------------
    include /etc/nginx/conf.d/*.conf;
}

```

### Proxy

```
# HTTP → перенаправляем на HTTPS 
server {
    listen 80;
    server_name _;

    #
    return 301 https://$host$request_uri;
}

# HTTPS — основной сервер
server {
    listen 443 ssl;
    server_name _;

    # ---- SSL 
    ssl_certificate /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

    # базовые SSL-настройки 
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;
    # логирование
    access_log /var/log/nginx/flask-app-access.log;
    # общие настройки прокси 
    location / {
        proxy_pass http://192.168.1.101:5000;

        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;  # ← теперь будет "https"

        
        proxy_cache_bypass $http_cache_control; # нужно , если клиент присылает no-cache , чтобы свежий кеш доставался из бека сразу
        proxy_cache_valid 200 302 10m; #  кешировать ответы 200 , 302 на 10 минут
        proxy_cache_valid 404 1m; # 404 кешировать на одну минуту
        proxy_cache my_cache; # куда сохранять кеш
        add_header X-Cache-Status $upstream_cache_status; # отобржать в header статус кеширования 

        # Тайм-ауты
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Безопасность
    location ~ /\. { # /\ . означает , что все скрытые файлы .env и тд будут недостпные через URL
        deny all; 
        access_log off; # нет логов , для таких запросов
        log_not_found off; # не логирует 404 для скрытых файлов
    }
}
```

### Логирование

```
services:
  flask-app:
    image: kirill4goodmopsa/flask-app
    container_name: flask-application-v2
    ports:
      - "5000:5000"
    volumes:
      - /opt/flask-logs:/app/logs
```

```
access_log /var/log/nginx/flask-app-access.log;
```

### Ротация логов

Создать файл /etc/logrotate.d/nginx:

```text
/var/log/nginx/nginx.log {
    rotate 14
    daily
    compress
    delaycompress
    missingok
    notifempty
    create 660 linuxuser linuxuser
}
```

[//]: # (дубликат ридми файла из [README.md](Ansible/README.md))
[//]: # (лучше оставить ссылку на оригинал)

# Ansible Infrastructure Deployment

Этот проект содержит Ansible конфигурацию для автоматического развертывания инфраструктуры на двух виртуальных машинах (
VM1 и VM2).

## Структура проекта

```text
.
├── ansible.cfg                
├── inventory.yml              
├── site.yml                   
├── deploy.yml                 
├── group_vars/
│   └── all/
│       ├── vars.yml          
│       └── vault.yml         
└── roles/
    ├── common/               
    │   ├── tasks/
    │   ├── handlers/
    │   └── defaults/
    ├── database/             
    │   ├── tasks/
    │   ├── handlers/
    │   ├── templates/
    │   └── defaults/
    ├── application/          
    │   ├── tasks/
    │   ├── handlers/
    │   ├── templates/
    │   └── defaults/
    └── webserver/           
        ├── tasks/
        ├── handlers/
        ├── templates/
        └── defaults/
```

## Роли

### 1. common

- Обновление системы
- Создание пользователя devops
- Установка Docker
- Настройка firewall (UFW + iptables)

### 2. database

- Установка PostgreSQL 15 (через Docker)
- Создание базы данных и пользователей
- Настройка доступа через pg_hba.conf
- Использование зашифрованных паролей из ansible-vault

### 3. application

- Создание пользователя приложения
- Создание Python virtual environment
- Установка Flask приложения
- Настройка systemd сервиса для автозапуска
- Установка зависимостей из requirements.txt

### 4. webserver

- Установка и настройка Nginx
- Настройка reverse proxy для Flask приложения
- Настройка логирования и security headers
- Оптимизация производительности (gzip, keepalive)

## Использование

### Предварительные требования

1. Ansible установлен на control node
2. SSH доступ к VM1 и VM2 с ключом
3. Python 3 установлен на целевых хостах
4. Sudo права на целевых хостах

### Настройка

1. **Зашифруйте пароли с помощью ansible-vault**:

```bash

echo "kirill" > .vault_pass

ansible-vault encrypt group_vars/all/vault.yml --vault-password-file .vault_pass

ansible-vault edit group_vars/all/vault.yml --vault-password-file .vault_pass
```

3. **Добавьте .vault_pass в .gitignore**:

```bash
echo ".vault_pass" >> .gitignore
```

### Запуск

#### Полное развертывание всей инфраструктуры:

```bash
# С файлом пароля
ansible-playbook site.yml --vault-password-file .vault_pass

# Или с интерактивным вводом пароля
ansible-playbook site.yml --ask-vault-pass

# Проверка без выполнения (dry-run)
ansible-playbook site.yml --check --vault-password-file .vault_pass
```

#### Обновление только приложения:

```bash
ansible-playbook deploy.yml --vault-password-file .vault_pass
```

#### Запуск конкретной роли:

```bash
# Только database роль на VM2
ansible-playbook site.yml --tags database --limit vm2 --vault-password-file .vault_pass

# Только webserver роль на VM1
ansible-playbook site.yml --tags webserver --limit vm1 --vault-password-file .vault_pass
```

### Проверка

После развертывания проверьте работоспособность:

```bash
# Проверка Flask приложения напрямую
curl http://VM1_IP:5000/

# Проверка через Nginx
curl http://VM1_IP/

# Проверка health endpoint
curl http://VM1_IP/health

# Проверка PostgreSQL
ssh user@VM2_IP
docker exec -it postgres psql -U postgres -d appdb
```

## Idempotency

Все роли написаны с соблюдением принципа idempotency - повторный запуск playbook не вызывает изменений, если система уже
находится в целевом состоянии.

## Handlers

Каждая роль использует handlers для перезапуска сервисов только при необходимости:

- **common**: restart docker, reload ufw
- **database**: restart postgresql
- **application**: reload systemd, restart application
- **webserver**: restart nginx, reload nginx

## Templates (Jinja2)

Используются шаблоны для конфигурационных файлов:

- PostgreSQL: `postgresql.conf.j2`, `pg_hba.conf.j2`
- Application: `app.py.j2`, `requirements.txt.j2`, `flask-app.service.j2`
- Nginx: `nginx.conf.j2`, `site.conf.j2`

## Безопасность

- Пароли хранятся в зашифрованном виде (ansible-vault)
- Firewall настроен на обоих хостах
- Nginx использует security headers
- Приложение запускается от непривилегированного пользователя
- SSH ключевая аутентификация

## Troubleshooting

### Проблема с подключением

```bash
# Проверка доступности хостов
ansible all -m ping --vault-password-file .vault_pass

# Проверка inventory
ansible-inventory --list -y
```

### Проблема с vault

```bash
# Просмотр зашифрованного файла
ansible-vault view group_vars/all/vault.yml --vault-password-file .vault_pass

# Расшифровка файла
ansible-vault decrypt group_vars/all/vault.yml --vault-password-file .vault_pass
```

### Логи сервисов

```bash
# Логи Flask приложения
sudo journalctl -u flask-app -f

# Логи Nginx
sudo tail -f /var/log/nginx/flask-app-error.log
sudo tail -f /var/log/nginx/flask-app-access.log

# Логи PostgreSQL
docker logs postgres -f
```

## Дополнительные команды

```bash
# Список всех тасков в playbook
ansible-playbook site.yml --list-tasks

# Список всех хостов
ansible-playbook site.yml --list-hosts

# Подробный вывод
ansible-playbook site.yml -vvv --vault-password-file .vault_pass

# Запуск с определенными тегами
ansible-playbook site.yml --tags "common,webserver" --vault-password-file .vault_pass
```
