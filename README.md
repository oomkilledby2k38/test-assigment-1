# Базовые требования 
1.Ubuntu 24.04 LTS 2 CPUs 2GB RAM 10 GB DISK
2.Ubuntu 24.04 LTS 2 CPUs 2GB RAM 10 GB DISK

## Создание пользователя 
sudo adduser devops 
## Права sudo
sudo vim /etc/sudeoers %devops ALL=(ALL) ALL
## ufw / iptables ( Настроить! )


## ufw allow 22 443 ports and etc  ( Также настроить ! )

## Password Authenfication и  Root login
sudo nano /etc/ssh/sshd_config
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes

## Установка Docker и PostgreSQL
[Docker](https://docs.docker.com/engine/install/)
[PostgreSQL](hub.docker.com/_/postgres/)

```
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
# Stage 1: Builder
FROM python:3.11-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    postgresql-dev

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install --prefer-binary -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-alpine

WORKDIR /app

# Install runtime dependencies only
RUN apk add --no-cache libpq

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY . .

# Create non-root user
RUN adduser -D -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5000

# Set environment variables
ENV FLASK_ENV=production \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Run the application with optimized settings
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
