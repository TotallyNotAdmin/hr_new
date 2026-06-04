#!/bin/bash
# deploy.sh

set -e

# === НАСТРОЙКИ ===
REPO_URL="https://github.com/TotallyNotAdmin/hr_new.git"
DEFAULT_DIR="$HOME/hr-system"
TARGET_DIR="${1:-$DEFAULT_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Преобразуем ~/путь в /home/user/путь
expand_path() {
    local path="$1"
    if [[ "$path" == ~* ]]; then
        echo "${HOME}${path:1}"
    else
        echo "$path"
    fi
}

# ==================== ПРОВЕРКА И УСТАНОВКА GIT ====================
ensure_git() {
    if command -v git &>/dev/null; then
        log_success "Git уже установлен: $(git --version)"
        return 0
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log_info "Для установки git требуются права sudo..."
        sudo -v || { log_error "Требуется ввод пароля sudo"; exit 1; }
    fi
    
    # Определяем пакетный менеджер
    if command -v apt-get &>/dev/null; then
        # Debian / Ubuntu
        sudo apt-get update -qq
        sudo apt-get install -y -qq git
    elif command -v dnf &>/dev/null; then
        # Fedora / RHEL 8+
        sudo dnf install -y -q git
    elif command -v yum &>/dev/null; then
        # CentOS / RHEL 7
        sudo yum install -y -q git
    elif command -v zypper &>/dev/null; then
        # openSUSE
        sudo zypper --quiet install -y git
    elif command -v pacman &>/dev/null; then
        # Arch Linux
        sudo pacman -Sy --noconfirm git
    elif command -v apk &>/dev/null; then
        # Alpine
        sudo apk add --no-cache git
    else
        log_error "Не удалось определить пакетный менеджер вашей системы!"
        log_error "Установите git вручную и повторите запуск скрипта"
        log_error "Пример: sudo apt install git  (для Ubuntu/Debian)"
        exit 1
    fi
    
    # Проверяем, что git действительно появился
    if ! command -v git &>/dev/null; then
        log_error "Git не найден после установки!"
        log_error "Попробуйте установить вручную: sudo apt install git"
        exit 1
    fi
    
    log_success "Git успешно установлен: $(git --version)"
}

# === ОСНОВНОЙ СЦЕНАРИЙ ===
main() {
    echo -e "${GREEN}Загрузчик системы Штат-контроль${NC}"
    echo "================================"
    
    ensure_git
    TARGET_DIR=$(expand_path "$TARGET_DIR")
    log_info "Целевая директория: $TARGET_DIR"
    
    mkdir -p "$(dirname "$TARGET_DIR")"
    
    # Клонирование или обновление
    if [ -d "$TARGET_DIR/.git" ]; then
        log_info "Обновление существующего репозитория..."
        cd "$TARGET_DIR"
        git fetch origin
        git reset --hard origin/prod 2>/dev/null || git checkout -f origin/prod
        git clean -fd
    else
        log_info "Клонирование репозитория..."
        # Удаляем, если есть пустая папка
        [ -d "$TARGET_DIR" ] && rmdir "$TARGET_DIR" 2>/dev/null || true
        git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
        cd "$TARGET_DIR"
    fi
    
    # Проверка наличия install.sh
    if [ ! -f "install.sh" ]; then
        log_error "install.sh не найден в $TARGET_DIR"
        echo "Проверьте структуру репозитория или связь с веткой prod"
        exit 1
    fi
    
    log_info "Запуск установки..."
    sudo chmod +x install.sh
    sudo chmod +x update.sh
    exec ./install.sh
}

main "$@"