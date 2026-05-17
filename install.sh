#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ==================== ПРОВЕРКА ЗАВИСИМОСТЕЙ ====================
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    # curl
    if ! command -v curl &> /dev/null; then
        log_warn "curl не найден, выполняется установка..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v yum &> /dev/null; then
            sudo yum install -y curl
        else
            log_error "Не удалось установить curl. Установите вручную"
            exit 1
        fi
    fi
    
    # Docker
    if ! command -v docker &> /dev/null; then
        log_warn "Docker не найден, выполняется установка..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        log_success "Docker установлен"
    fi
    
    # Добавляем пользователя в группу docker (если нужно)
    if ! groups $USER | grep -q docker; then
        log_warn "Добавляю пользователя $USER в группу docker..."
        sudo usermod -aG docker $USER
        log_warn "WARN: Для применения изменений перезайдите в систему или выполните: newgrp docker"
    fi
    
    # docker compose (v2)
    if ! docker compose version &> /dev/null; then
        log_warn "docker compose v2 не найден, будет выполнена установка..."
        sudo apt-get update && sudo apt-get install -y docker-compose-plugin 2>/dev/null || \
        sudo yum install -y docker-compose-plugin 2>/dev/null || \
        log_warn "WARN: docker compose-plugin не установлен, будет установлен docker-compose v1..."
        
        if ! command -v docker-compose &> /dev/null; then
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
    fi
    
    log_success "Зависимости проверены"
}

# ==================== ПОИСК POSTGRESQL ====================
detect_postgres() {
    log_info "Поиск PostgreSQL..."
    
    local detected_host="localhost"
    local detected_port=""
    local detected_user=""
    
    # Через ss (systemd-socket или netstat)
    if command -v ss &>/dev/null; then
        log_info "Сканирование активных портов через ss..."
        # Ищем процессы с именем postgres или порт 5432
        local pg_lines=$(ss -tlnp 2>/dev/null | grep -iE '(postgres|:543[0-9])' || true)
        
        if [ -n "$pg_lines" ]; then
            # Парсим вывод: LISTEN 0 128 127.0.0.1:5432 ...
            detected_port=$(echo "$pg_lines" | head -1 | grep -oE ':[0-9]+' | tail -1 | tr -d ':')
            local addr=$(echo "$pg_lines" | head -1 | awk '{print $4}' | cut -d: -f1)
            
            # Если адрес 0.0.0.0 или *, используем 127.0.0.1
            if [[ "$addr" == "0.0.0.0" || "$addr" == "*" || "$addr" == "::" ]]; then
                detected_host="127.0.0.1"
            else
                detected_host="$addr"
            fi
            log_success "PostgreSQL найден: $detected_host:$detected_port"
        fi
    fi
    
    # если ss не дал результата
    if [ -z "$detected_port" ]; then
        for port in 5432 5433 5434; do
            if pg_isready -h localhost -p $port -q 2>/dev/null; then
                detected_port=$port
                detected_host="localhost"
                log_success "PostgreSQL найден на порту $port"
                break
            fi
        done
    fi
    
    # Способ 3: Unix socket
    if [ -z "$detected_port" ] && [ -S /var/run/postgresql/.s.PGSQL.5432 ]; then
        detected_port=5432
        detected_host="/var/run/postgresql"
        log_success "PostgreSQL найден через Unix-socket"
    fi
    
    # Если не нашли — интерактивный ввод
    if [ -z "$detected_port" ]; then
        log_warn "PostgreSQL не найден автоматически"
        echo "Подсказка: убедитесь, что PostgreSQL запущен и слушает подключения"
        echo "   Проверьте: sudo ss -tlnp | grep postgres"
        
        read -p "Введите хост PostgreSQL [127.0.0.1]: " detected_host
        detected_host=${detected_host:-127.0.0.1}
        read -p "Введите порт PostgreSQL [5432]: " detected_port
        detected_port=${detected_port:-5432}
        
        # Тест подключения
        if ! timeout 3 bash -c "echo > /dev/tcp/$detected_host/$detected_port" 2>/dev/null; then
            log_error "Не удалось подключиться к $detected_host:$detected_port"
            echo "   Проверьте: 1) PostgreSQL запущен, 2) pg_hba.conf разрешает подключения"
            exit 1
        fi
        log_success "Подключение проверено"
    fi
    
    # Учётные данные
    read -p "Введите пользователя PostgreSQL [postgres]: " detected_user
    detected_user=${detected_user:-postgres}
    
    read -s -p "Введите пароль для $detected_user: " db_password
    echo
    if [ -z "$db_password" ]; then
        log_error "Пароль не может быть пустым!"
        exit 1
    fi
    
    # Сохраняем
    PG_HOST="$detected_host"
    PG_PORT="$detected_port"
    PG_USER="$detected_user"
    PG_PASS="$db_password"
}

# ==================== ВЫБОР БАЗЫ ДАННЫХ ====================
select_database() {
    log_info "Загружаем список баз данных..."
    
    # Временный файл для вывода
    local tmp_list=$(mktemp)
    
    # Получаем список БД (парсим вывод psql)
    PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -lqt 2>/dev/null | \
        cut -d \| -f 1 | grep -w '[a-zA-Z0-9_]\+' | grep -v '^ *$' | sort > "$tmp_list"
    
    if [ ! -s "$tmp_list" ]; then
        log_error "Не удалось получить список баз данных. Проверьте права пользователя"
        rm -f "$tmp_list"
        exit 1
    fi
    
    echo -e "\n${GREEN}Доступные базы данных:${NC}"
    local i=1
    local -a db_array=()
    while IFS= read -r db; do
        echo "  $i) $db"
        db_array+=("$db")
        ((i++))
    done < "$tmp_list"
    rm -f "$tmp_list"
    
    # Выбор
    read -p "Выберите номер базы [1]: " db_choice
    db_choice=${db_choice:-1}
    
    if [[ ! "$db_choice" =~ ^[0-9]+$ ]] || [ "$db_choice" -lt 1 ] || [ "$db_choice" -gt "${#db_array[@]}" ]; then
        log_error "Неверный выбор"
        exit 1
    fi
    
    SELECTED_DB="${db_array[$((db_choice-1))]}"
    log_success "Выбрана база: $SELECTED_DB"
}

# ==================== ГЕНЕРАЦИЯ .ENV ====================
generate_env() {
    log_info "Генерация .env..."
    
    # Формируем DATABASE_URL
    if [[ "$PG_HOST" == /* ]]; then
        # Unix socket
        DB_URL="postgresql://$PG_USER:$PG_PASS@$PG_HOST:$PG_PORT/$SELECTED_DB"
    else
        DB_URL="postgresql://$PG_USER:$PG_PASS@$PG_HOST:$PG_PORT/$SELECTED_DB"
    fi
    
    # Генерируем JWT_SECRET
    JWT_SECRET=$(openssl rand -hex 32)
    
    # Создаём .env
    cat > .env << EOF
# === АВТО-ГЕНЕРАЦИЯ ===
# Дата: $(date '+%Y-%m-%d %H:%M:%S')

DATABASE_URL=$DB_URL
JWT_SECRET_KEY=$JWT_SECRET
FRONTEND_URL=http://localhost

# === ДОПОЛНИТЕЛЬНО ===
# LOG_LEVEL=info
# MAX_CONNECTIONS=10
EOF
    
    chmod 600 .env  # Только владелец может читать
    log_success ".env создан и защищён"
    
    # Показываем предупреждение о паролях
    echo -e "\n${YELLOW}ВАЖНО:${NC}"
    echo "   Сгенерированные пароли пользователей будут выведены после инициализации БД."
    echo "   Сохраните их в безопасном месте или сразу смените пароли через интерфейс."
    echo -e "   JWT_SECRET: ${GREEN}$JWT_SECRET${NC} (не меняйте его вручную!)\n"
}

# ==================== ИНИЦИАЛИЗАЦИЯ БД ====================
init_database() {
    log_info "Инициализация схемы 'app'..."
    
    # Проверяем, есть ли Python с нужными пакетами
    if ! python3 -c "import asyncpg, passlib, dotenv" &>/dev/null; then
        log_warn "Установка Python-зависимостей для init_db.py..."
        python3 -m pip install --user -q asyncpg passlib[bcrypt] python-dotenv 2>/dev/null || \
        sudo python3 -m pip install -q asyncpg passlib[bcrypt] python-dotenv
    fi
    
    # Запускаем init_db.py с переменными окружения
    export DATABASE_URL
    export JWT_SECRET_KEY
    python3 init_db.py
    
    if [ $? -eq 0 ]; then
        log_success "База данных инициализирована"
    else
        log_error "Ошибка инициализации БД"
        exit 1
    fi
}

# ==================== ЗАПУСК КОНТЕЙНЕРОВ ====================
start_containers() {
    log_info "Запуск контейнеров..."
    
    # Проверяем docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml не найден в текущей директории"
        exit 1
    fi
    
    # Останавливаем старые (если есть)
    docker compose down --remove-orphans 2>/dev/null || true
    
    # Собираем и запускаем
    docker compose up -d --build
    
    # Ждём запуска
    sleep 5
    
    # Проверяем статус
    if docker compose ps | grep -q "Up"; then
        log_success "Контейнеры запущены"
    else
        log_warn "Контейнеры запущены, но могут быть ошибки. Проверьте логи:"
        echo "   docker compose logs -f"
    fi
}

# ==================== ФИНАЛЬНЫЕ СООБЩЕНИЯ ====================
show_completion() {
    echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}    Система успешно установлена!    ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"
    
    echo "Frontend: http://$(hostname -I | awk '{print $1}' | head -1)"
    echo "Backend API: http://$(hostname -I | awk '{print $1}' | head -1):8000/docs"
    echo ""
    echo "Основные команды:"
    echo "   • Просмотр логов:     docker compose logs -f"
    echo "   • Остановка:          docker compose down"
    echo "   • Обновление:         ./update.sh"
    echo "   • Перезапуск:         ./install.sh --restart"
    echo ""
    echo "Файлы установлены в: $(pwd)"
    echo "!Файл .env содержит чувствительные данные — не передавайте его!"
}

# ==================== ОБРАБОТКА АРГУМЕНТОВ ====================
parse_args() {
    case "${1:-}" in
        --restart)
            log_info "Режим перезапуска..."
            docker compose down
            start_containers
            show_completion
            exit 0
            ;;
        --help|-h)
            echo "Использование: $0 [ОПЦИИ]"
            echo "Опции:"
            echo "  --restart   Перезапустить контейнеры без переустановки"
            echo "  --help      Показать эту справку"
            exit 0
            ;;
    esac
}

# ==================== MAIN ====================
main() {
    parse_args "$@"
    
    echo -e "${GREEN}HR-System Installer${NC}"
    echo "========================\n"
    
    check_dependencies
    detect_postgres
    select_database
    generate_env
    init_database
    start_containers
    show_completion
}

main "$@"