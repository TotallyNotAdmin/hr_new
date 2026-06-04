#!/bin/bash
# update.sh

set -e
echo "Обновление системы..."

# Скачиваем новые файлы (через git или curl)
if [ -d ".git" ]; then
    git pull origin main
else
    # Если нет git — скачиваем архив
    curl -fsSL https://github.com/TotallyNotAdmin/hr_new/archive/main.tar.gz | \
        tar -xz --strip-components=1 -C . --exclude='.git'
fi

# Проверяем .env
if [ ! -f ".env" ]; then
    echo "ERROR: .env не найден! Запустите сначала install.sh"
    exit 1
fi

# Пере-инициализация БД (таблицы уже есть)
echo "Проверка миграций БД..."
python3 init_db.py || echo "WARN: init_db.py завершился с предупреждением"

echo "Пересборка образов..."
sudo docker compose down
sudo docker compose build --no-cache
sudo docker compose up -d

echo "Обновление завершено!"
sudo docker compose ps