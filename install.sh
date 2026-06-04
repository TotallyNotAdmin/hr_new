#!/bin/bash
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ==================== ПРОВЕРКА ЗАВИСИМОСТЕЙ ====================
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    if ! command -v curl &> /dev/null; then
        log_warn "Установка curl..."
        sudo apt-get update -qq && sudo apt-get install -y -qq curl
    fi
    if ! python3 -m pip --version &>/dev/null; then
        log_warn "Установка pip..."
        sudo apt-get update -qq && sudo apt-get install -y -qq python3-pip python3-venv
    fi
    if ! command -v docker &> /dev/null; then
        log_warn "Установка Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm -f get-docker.sh
    fi
    if ! groups $USER | grep -q docker; then
        log_warn "Добавление пользователя $USER в группу docker..."
        sudo usermod -aG docker $USER
        log_warn "WARN: Для применения изменений перезайдите в систему или выполните: newgrp docker"
    fi
    if ! docker compose version &> /dev/null; then
        log_warn "Установка docker compose v2..."
        sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || \
        sudo yum install -y -q docker-compose-plugin 2>/dev/null || \
        { sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose; }
    fi
    log_success "Зависимости проверены"
}

ensure_docker_access() {
    if sudo docker info &>/dev/null; then
        log_success "Доступ к Docker через sudo подтверждён"
        return 0
    else
        log_error "Не удалось получить доступ к Docker с sudo"
        log_error "Проверьте: 1) установлен ли Docker; 2) работает ли служба"
        exit 1
    fi
}

# ==================== ПОИСК POSTGRESQL ====================
detect_postgres() {
	log_info "Поиск PostgreSQL..."
	local detected_host="" detected_port=""

	# Авто-поиск через ss
	if command -v ss &>/dev/null; then
	    log_info "Сканирование через ss..."
	    local ss_line
	    ss_line=$(sudo ss -tlnp -n 2>/dev/null | grep -i 'postgres' | head -1 || true)
	    if [ -n "$ss_line" ]; then
	        local addr=$(echo "$ss_line" | awk '{print $4}')
	        detected_port=$(echo "$addr" | rev | cut -d: -f1 | rev)
	        detected_host=$(echo "$addr" | rev | cut -d: -f2- | rev)
	        case "$detected_host" in
	            "0.0.0.0"|"*"|"::") detected_host="127.0.0.1" ;;
	        esac
	        if [[ "$detected_port" =~ ^[0-9]+$ ]]; then
	            log_success "PostgreSQL найден: $detected_host:$detected_port"
	        else
	            log_warn "Обнаружен нечисловой порт '$detected_port' (возможно, имя сервиса). Потребуется ручной ввод"
	            detected_port=""
	        fi
	    fi
	fi

	# Резерв: pg_isready
	if [ -z "$detected_port" ] && command -v pg_isready &>/dev/null; then
	    for port in 5432 5433 5434; do
	        if pg_isready -h 127.0.0.1 -p $port -q 2>/dev/null; then
	            detected_port=$port; detected_host="127.0.0.1"
	            log_success "PostgreSQL найден через pg_isready на порту $port"
	            break
	        fi
	    done
	fi

	# Ручной ввод ТОЛЬКО если авто-поиск не удался
	if [ -z "$detected_port" ] || [ -z "$detected_host" ]; then
	    log_warn "WARN: PostgreSQL не найден автоматически"
	    while true; do
	        [ -z "$detected_host" ] && read -p "Введите хост PostgreSQL [127.0.0.1]: " detected_host
	        detected_host=${detected_host:-127.0.0.1}
	        [ -z "$detected_port" ] && read -p "Введите порт PostgreSQL [5432]: " detected_port
	        detected_port=${detected_port:-5432}
	        
	        # Валидация порта
	        if ! [[ "$detected_port" =~ ^[0-9]+$ ]]; then
	            log_error "Порт должен быть числом!"
	            detected_port=""
	            continue
	        fi
	        
	        # Проверка доступности
	        if timeout 3 bash -c "echo >/dev/tcp/$detected_host/$detected_port" 2>/dev/null || \
	           pg_isready -h "$detected_host" -p "$detected_port" -q 2>/dev/null; then
	            break
	        else
	            log_error "Не удалось подключиться к $detected_host:$detected_port"
	            read -p "Повторить ввод? (y/n) [y]: " rep
	            [[ "$rep" =~ ^[Nn]$ ]] && exit 1
	            detected_host=""
	            detected_port=""
	        fi
	    done
	fi

	# Проверка учётных данных
	while true; do
	    read -p "Введите пользователя PostgreSQL [postgres]: " PG_USER
	    PG_USER=${PG_USER:-postgres}
	    read -s -p "Введите пароль для $PG_USER: " PG_PASS; echo
	    [ -z "$PG_PASS" ] && { log_error "Пароль не может быть пустым!"; continue; }
	    if PGPASSWORD="$PG_PASS" pg_isready -h "$detected_host" -p "$detected_port" -U "$PG_USER" &>/dev/null; then
	        log_success "Подключение к БД установлено"
	        break
	    else
	        log_error "Ошибка подключения! Проверьте логин, пароль и pg_hba.conf"
	        read -p "Повторить ввод учётных данных? (y/n) [y]: " rep
	        [[ "$rep" =~ ^[Nn]$ ]] && exit 1
	    fi
	done
	PG_HOST="$detected_host"
	PG_PORT="$detected_port"
}

# ==================== ВЫБОР БАЗЫ ДАННЫХ ====================
select_database() {
    while true; do
        log_info "Загружаем список баз данных..."
        local tmp_list=$(mktemp)
        
        PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -lqt 2>/dev/null | \
            cut -d \| -f 1 | grep -w '[a-zA-Z0-9_]\+' | grep -v '^ *$' | xargs -I{} echo "{}" | sort -u > "$tmp_list"
        
        if [ ! -s "$tmp_list" ]; then
            log_error "Не удалось получить список БД. Проверьте права пользователя"
            rm -f "$tmp_list"; continue
        fi
        
        echo -e "\n${GREEN}Доступные базы данных:${NC}"
        local i=1; local -a db_array=()
        while IFS= read -r db; do
            db=$(echo "$db" | xargs)
            [[ -z "$db" ]] && continue
            echo "  $i) $db"
            db_array+=("$db"); ((i++))
        done < "$tmp_list"
        rm -f "$tmp_list"
        
        read -p "Выберите номер базы [1]: " db_choice
        db_choice=${db_choice:-1}
        
        if [[ "$db_choice" =~ ^[0-9]+$ ]] && [ "$db_choice" -ge 1 ] && [ "$db_choice" -le "${#db_array[@]}" ]; then
            SELECTED_DB="${db_array[$((db_choice-1))]}"
            SELECTED_DB=$(echo "$SELECTED_DB" | tr -d '[:space:]')
            log_success "Выбрана база: $SELECTED_DB"
            break
        else
            log_error "Неверный номер! Попробуйте снова"
        fi
    done
}

# ==================== АВТОПРОДЛЕНИЕ СЕРТИФИКАТОВ ====================
setup_certbot_cron() {
    log_info "Настройка автоматического продления сертификатов (cron)..."
    
    if sudo crontab -l 2>/dev/null | grep -qF "certbot renew.*$DOMAIN"; then
        log_warn "Задача продления для $DOMAIN уже существует в crontab"
        return 0
    fi
    
    local CERTBOT_PATH=$(command -v certbot 2>/dev/null || echo "/usr/bin/certbot")
    local DOCKER_PATH=$(command -v docker 2>/dev/null || echo "/usr/bin/docker")
    local PROJECT_DIR="$SCRIPT_DIR"
    
    local DEPLOY_HOOK="cp -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem $PROJECT_DIR/certs/ && "
    DEPLOY_HOOK+="cp -f /etc/letsencrypt/live/$DOMAIN/privkey.pem $PROJECT_DIR/certs/ && "
    DEPLOY_HOOK+="chmod 644 $PROJECT_DIR/certs/*.pem && "
    DEPLOY_HOOK+="$DOCKER_PATH restart hr-frontend"
    
    local CRON_CMD="0 3 * * * $CERTBOT_PATH renew --quiet --deploy-hook \"$DEPLOY_HOOK\" # HR-System SSL renewal for $DOMAIN"
    
    (sudo crontab -l 2>/dev/null; echo "$CRON_CMD") | sudo crontab -
    
    if [ $? -eq 0 ]; then
        log_success "Задача автопродления добавлена в crontab (ежедневно в 03:00)"
        log_info "Команда: $CRON_CMD"
        log_warn "Сертификат будет продлён автоматически за 30 дней до истечения"
    else
        log_error "Не удалось добавить задачу в crontab!"
        log_warn "Добавьте вручную командой: sudo crontab -e"
        log_warn "Строка для добавления:"
        log_warn "  $CRON_CMD"
    fi
}

# ==================== НАСТРОЙКА ДОМЕНА И SSL ====================
configure_domain_and_ssl() {
    log_info "Настройка домена и HTTPS..."
    
    read -p "Хотите настроить HTTPS (выпустить бесплатный сертификат Let's Encrypt)? (y/n) [y]: " USE_SSL
    USE_SSL=${USE_SSL:-y}
    
    DOMAIN=""
    if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "Введите доменное имя (например, hr.company.com): " DOMAIN
            DOMAIN=$(echo "$DOMAIN" | xargs)
            
            if [[ -z "$DOMAIN" ]]; then
                log_error "Домен не может быть пустым!"
            elif [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_error "Let's Encrypt не поддерживает выпуск сертификатов для IP-адресов!"
                log_warn "Введите именно доменное имя, либо выберите 'n' для работы по HTTP"
            else
                break
            fi
        done
        
        if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
            if ! sudo ufw status | grep -qE "^80/tcp\s+ALLOW"; then
                sudo ufw allow 80/tcp
            fi
        fi
        
        log_info "Установка certbot..."
        sudo apt-get update -qq && sudo apt-get install -y -qq certbot
        
        if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
            log_warn "Сертификат для $DOMAIN уже существует"
        else
            log_info "Получение сертификата для $DOMAIN..."
            
            sudo certbot certonly --standalone -d "$DOMAIN" \
                --agree-tos \
                --register-unsafely-without-email \
                --non-interactive
            
            if [ $? -ne 0 ]; then
                log_error "Не удалось получить сертификат!"
                log_error "Возможные причины:"
                log_error "  1. Домен $DOMAIN не указывает на IP-адрес этого сервера"
                log_error "  2. Порт 80 закрыт на уровне провайдера или внешнего роутера"
                read -p "Продолжить установку в режиме HTTP (без сертификата)? (y/n) [y]: " CONTINUE_NO_SSL
                CONTINUE_NO_SSL=${CONTINUE_NO_SSL:-y}
                if [[ "$CONTINUE_NO_SSL" =~ ^[Yy]$ ]]; then
                    USE_SSL="n"
                else
                    exit 1
                fi
            else
                log_success "Сертификат успешно получен!"
            fi
        fi
        
        if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
            log_info "Копирование сертификатов в ./certs..."
            mkdir -p ./certs
            sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./certs/
            sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./certs/
            sudo chown $USER:$USER ./certs/*
            chmod 644 ./certs/privkey.pem
            
            setup_certbot_cron
        fi
    else
        log_info "Выпуск сертификатов пропущен. Система будет работать по обычному HTTP"
        mkdir -p ./certs
    fi
    
    export DOMAIN
    export USE_SSL
}

# ==================== ГЕНЕРАЦИЯ .ENV ====================
generate_env() {
    log_info "Генерация .env..."
    SELECTED_DB=$(echo "$SELECTED_DB" | tr -d '[:space:]')
    
    local DB_URL="postgresql://$PG_USER:$PG_PASS@$PG_HOST:$PG_PORT/$SELECTED_DB"
    log_info "DATABASE_URL (без пароля): postgresql://$PG_USER:****@$PG_HOST:$PG_PORT/$SELECTED_DB"
    
    # подмена хоста для Docker
    local docker_host="$PG_HOST"
    if [[ "$docker_host" == "127.0.0.1" || "$docker_host" == "localhost" ]]; then
        docker_host="host.docker.internal"
    fi
    local DB_URL_DOCKER="postgresql://$PG_USER:$PG_PASS@$docker_host:$PG_PORT/$SELECTED_DB"
    
    local JWT_SECRET=$(openssl rand -hex 32)
    
    cat > .env << EOF
# === АВТО-ГЕНЕРАЦИЯ ===
DATABASE_URL=$DB_URL
# Отдельный URL для Docker-контейнеров
DATABASE_URL_DOCKER=$DB_URL_DOCKER
JWT_SECRET_KEY=$JWT_SECRET
FRONTEND_URL=http://localhost
EOF
    chmod 600 .env
    log_success ".env сгенерирован"
    echo -e "\n${YELLOW}ВАЖНО:${NC} Пароли пользователей будут выведены в отдельный файл после инициализации БД"
    echo -e "   JWT_SECRET: ${GREEN}$JWT_SECRET${NC}"
}

# ==================== ИНИЦИАЛИЗАЦИЯ БД ====================
init_database() {
    export DATABASE_URL
    export JWT_SECRET_KEY
    export FRONTEND_URL

    log_info "Инициализация схемы 'app'..."
    if ! python3 -c "import asyncpg, passlib, dotenv" &>/dev/null; then
        log_warn "Установка Python-зависимостей для init_db.py..."
        python3 -m pip install --user -q asyncpg passlib[bcrypt] python-dotenv 2>/dev/null || \
        sudo python3 -m pip install -q asyncpg passlib[bcrypt] python-dotenv
    fi

    export DATABASE_URL
    export JWT_SECRET_KEY
    
    PASS_FILE="$SCRIPT_DIR/hr_passwords.txt"
    > "$PASS_FILE"

    log_info "Инициализация данных в схеме 'app'..."
    OUTPUT=$(python3 "$SCRIPT_DIR/init_db.py" 2>&1)
    EXIT_CODE=$?

    echo "# Сгенерированные пароли ($(date '+%Y-%m-%d %H:%M:%S'))" > "$PASS_FILE"
    echo "# ==========================================" >> "$PASS_FILE"
    echo "$OUTPUT" | grep -iE "пароль:|→ .* \| пароль:" >> "$PASS_FILE" 2>/dev/null || true
    chmod 600 "$PASS_FILE"

    # Выводим в консоль всё, КРОМЕ строк с паролями
    echo "$OUTPUT" | grep -ivE "пароль:|→ .* \| пароль:" || true

    if [ $EXIT_CODE -ne 0 ]; then
        log_error "Ошибка инициализации БД"
        exit 1
    fi
    log_success "База данных инициализирована! Пароли сохранены в: ${GREEN}$PASS_FILE${NC}"
    log_warn "  Не храните этот файл на сервере! Удалите его после раздачи доступа сотрудникам"
}
# ==================== НАСТРОЙКА PG_HBA.CONF ====================
configure_pg_hba() {
    log_info "Настройка доступа Docker к PostgreSQL..."
    local HBA_FILE
    HBA_FILE=$(sudo -u postgres psql -t -A -c "SHOW hba_file;" 2>/dev/null | tr -d '[:space:]')
    
    if [ -z "$HBA_FILE" ]; then
        log_warn "Не удалось найти pg_hba.conf! Настройте доступ вручную"
        return
    fi

    # Резервная копия
    sudo cp "$HBA_FILE" "${HBA_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    
    # Добавляем правило для Docker-сетей (172.16.0.0/12 покрывает стандартные подсети Docker)
    if ! sudo grep -q "Docker networks" "$HBA_FILE"; then
        log_info "Добавление правила в pg_hba.conf для доступа из Docker-контейнеров..."
        sudo sh -c 'echo "host all all 172.16.0.0/12 md5 # Docker networks" >> '"$HBA_FILE"''
        sudo systemctl reload postgresql 2>/dev/null || sudo pg_ctlcluster $(ls /etc/postgresql | head -1) main reload 2>/dev/null || true
        log_success "pg_hba.conf обновлён"
        log_success "PostgreSQL перезагружен"
    else
        log_info "Правило для Docker уже присутствует в pg_hba.conf"
    fi
}

# ==================== ГЕНЕРАЦИЯ NGINX ====================
generate_nginx_conf() {
    log_info "Генерация конфигурации Nginx..."
    local NGINX_CONF="./Frontend/nginx.conf"
    mkdir -p ./Frontend
    
    # Общий блок проксирования API
    local API_PROXY='
    location /api/ {
        proxy_pass http://hr-backend:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
    
    location /docs {
        proxy_pass http://hr-backend:8000/docs;
        proxy_set_header Host $host;
    }
    location /openapi.json {
        proxy_pass http://hr-backend:8000/openapi.json;
        proxy_set_header Host $host;
    }
    location /redoc {
        proxy_pass http://hr-backend:8000/redoc;
        proxy_set_header Host $host;
    }'

    if [ "$USE_SSL" = "y" ] || [ "$USE_SSL" = "Y" ]; then
        cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
$API_PROXY
}
EOF
    else
        local SERVER_NAME="_"
        [ -n "$DOMAIN" ] && SERVER_NAME="$DOMAIN"
        cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
$API_PROXY
}
EOF
    fi
    log_success "Nginx конфигурация сгенерирована"
}

# ==================== ЗАПУСК КОНТЕЙНЕРОВ ====================
start_containers() {
    log_info "Запуск контейнеров..."
    sudo docker compose down --remove-orphans 2>/dev/null || true
    if ! sudo docker compose up -d --build; then
        log_error "Не удалось собрать (запустить) контейнеры!"
        sudo docker compose logs --tail=50
        exit 1
    fi
    
    log_info "Ожидание запуска сервисов..."
	for i in {1..12}; do
	    if sudo docker compose ps --format "table {{.Status}}" | grep -q "Up"; then
	        if sudo docker compose ps backend --format "{{.Status}}" | grep -q "healthy"; then
	            log_success "Все контейнеры запущены"
	            return 0
	        fi
	    fi
	    sleep 5
	done
	log_error "Превышено время ожидания запуска контейнеров"
	sudo docker compose logs --tail=30
	return 1
}

# ==================== НАСТРОЙКА БРАНДМАУЭРА ====================
configure_firewall() {
    log_info "Настройка правил брандмауэра (UFW)"
    
    if ! command -v ufw &>/dev/null; then
        log_warn "UFW не установлен - пропуск настройки..."
        return 0
    fi
    
    if ! sudo ufw status &>/dev/null; then
        log_warn "UFW не активен (статус: inactive) - пропуск настройки..."
        return 0
    fi
    
    if ! sudo ufw status | grep -qE "^80/tcp\s+ALLOW"; then
        log_info "Проверка доступности порта 80 (HTTP)..."
        sudo ufw allow 80/tcp
    else
        log_info "Порт 80 открыт"
    fi
    
    if [ "$USE_SSL" = "y" ] || [ "$USE_SSL" = "Y" ]; then
        if ! sudo ufw status | grep -qE "^443/tcp\s+ALLOW"; then
            log_info "Проверка доступности порта 443 (HTTPS)..."
            sudo ufw allow 443/tcp
        fi
    fi
    
    log_success "Правила брандмауэра настроены"
}

# ==================== ФИНАЛЬНЫЕ СООБЩЕНИЯ ====================
show_completion() {
    local PROTOCOL="http"
    [ "$USE_SSL" = "y" ] || [ "$USE_SSL" = "Y" ] && PROTOCOL="https"
    local URL_HOST="$DOMAIN"
    [ -z "$URL_HOST" ] && URL_HOST="$(hostname -I | awk '{print $1}' | head -1)"

    echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}    Система успешно установлена!        ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"
    echo "Frontend: $PROTOCOL://$URL_HOST"
    echo "Backend API: $PROTOCOL://$URL_HOST/docs (через Reverse Proxy)"
    echo "   • Просмотр логов:     docker compose logs -f"
    echo "   • Остановка:          docker compose down"
    echo "   • Обновление:         ./update.sh"
    echo -e "\n${YELLOW}! Файл .env содержит чувствительные данные — не передавайте его!${NC}"
}

# ==================== MAIN ====================
main() {
    echo -e "${GREEN}Система Штат-Контроль (установщик)${NC}\n========================\n"
    if ! sudo -n true 2>/dev/null; then
        log_warn "Запрос прав sudo для управления Docker..."
        sudo -v || { log_error "Требуется ввод пароля sudo"; exit 1; }
    fi
    check_dependencies
    ensure_docker_access
    detect_postgres
    select_database
    configure_domain_and_ssl
    generate_env
    if ! init_database; then
        log_error "Установка прервана: ошибка инициализации БД"
        exit 1
    fi
    configure_pg_hba
    configure_firewall
    generate_nginx_conf
    if ! start_containers; then
        log_error "Установка не завершена из-за ошибки запуска контейнеров"
        exit 1
    fi
    show_completion
}

main "$@"