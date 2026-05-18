#!/bin/bash
# deploy.sh
set -e

REPO_URL="https://github.com/TotallyNotAdmin/hr_new.git"
TARGET_DIR="${1:-~/hr-system}"

echo "Загрузка системы в $TARGET_DIR..."

if [ -d "$TARGET_DIR/.git" ]; then
    echo "Обновление существующего репозитория..."
    cd "$TARGET_DIR" && git pull origin main
else
    echo "Клонирование репозитория..."
    git clone "$REPO_URL" "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

echo "Запуск установки..."
cd "$TARGET_DIR"
chmod +x install.sh
exec ./install.sh