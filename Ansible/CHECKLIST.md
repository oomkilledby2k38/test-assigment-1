# Чеклист для ручной проверки

## Сервисы и порты

| Сервис | Порт | Описание |
|--------|------|----------|
| Frontend (Nginx) | 80, 443 | Веб-интерфейс |
| Backend | 8000 | API сервер |
| PostgreSQL | 5432 | База данных |

# Команды для диагностики

### Проверка доступности сервисов

```bash
# Frontend
curl -I http://<frontend_ip>

# Backend
curl http://<backend_ip>:8000

# PostgreSQL
nc -zv <database_ip> 5432
```

### Проверка Docker контейнеров

```bash
# Список запущенных контейнеров
docker ps

# Логи контейнера
docker logs <container_name>

# Статус ресурсов
docker stats
```

### Проверка подключения к БД

```bash
# Проверка доступности PostgreSQL
psql -h <database_ip> -U <username> -d <dbname> -c "SELECT 1;"
```

### Проверка сети

```bash
# Пинг из backend в database
docker exec <backend_container> ping database
```
