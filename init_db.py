import asyncio
import sys
import secrets
import asyncpg
from pathlib import Path
from passlib.hash import bcrypt
from urllib.parse import urlparse

backend_path = Path(__file__).parent / "Backend"
if backend_path.exists() and str(backend_path) not in sys.path:
    sys.path.insert(0, str(backend_path))

try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / ".env"
    if env_path.exists():
        load_dotenv(env_path)
except ImportError:
    # Если dotenv не установлен - полагаемся на экспорт из install.sh
    pass

from const import DATABASE_URL


def validate_database_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
        if parsed.scheme not in ('postgresql', 'postgresql+asyncpg'):
            return False
        if not parsed.hostname:
            return False
        if parsed.port and not str(parsed.port).isdigit():
            return False
        if not parsed.path.lstrip('/'):
            return False
        return True
    except Exception:
        return False

def mask_database_url(url: str) -> str:
    """Безопасное маскирование чувствительных данных"""
    try:
        parsed = urlparse(url)
        port_str = f":{parsed.port}" if parsed.port else ""
        return f"{parsed.scheme}://****:****@{parsed.hostname}{port_str}/{parsed.path.lstrip('/')}"
    except Exception:
        return "postgresql://****:****@****:****/****"


ROLE_MAP = {
    "RTK-HR-MNG-01": "manager",
    "RTK-HR-APR-01": "approver",
    "RTK-HR-EXE-01": "executor"
}

CREATE_TABLES = [
    """
    CREATE TABLE IF NOT EXISTS app.users (
        id SERIAL PRIMARY KEY,
        full_name TEXT NOT NULL,
        login TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('manager', 'approver', 'executor')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS app.requests (
        id SERIAL PRIMARY KEY,
        creator_id INT NOT NULL REFERENCES app.users(id),
        scenario_type INT NOT NULL CHECK (scenario_type IN (1,2,3,4)),
        status TEXT NOT NULL,
        comment TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        description TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS app.request_data (
        id SERIAL PRIMARY KEY,
        request_id INT NOT NULL REFERENCES app.requests(id) ON DELETE CASCADE,
        field_name TEXT NOT NULL,
        as_is_value TEXT,
        to_be_value TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS app.request_history (
        id SERIAL PRIMARY KEY,
        request_id INT NOT NULL REFERENCES app.requests(id) ON DELETE CASCADE,
        action TEXT NOT NULL,
        user_id INT NOT NULL REFERENCES app.users(id),
        comment TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """,
    """
       CREATE OR REPLACE FUNCTION app.updated_at_column()
       RETURNS TRIGGER AS $$
       BEGIN
           NEW.updated_at = CURRENT_TIMESTAMP;
           RETURN NEW;
       END;
       $$ LANGUAGE plpgsql
       """,
    """
    CREATE TRIGGER trg_requests_updated_at
    BEFORE UPDATE ON app.requests
    FOR EACH ROW
    EXECUTE FUNCTION app.updated_at_column()
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_requests_creator ON app.requests(creator_id)
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_requests_status ON app.requests(status)
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_request_data_request ON app.request_data(request_id)
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_request_history_request ON app.request_history(request_id)
    """,
]


async def init_schema(pool):
    """Создаёт схему и все таблицы"""
    async with pool.acquire() as conn:
        await conn.execute("CREATE SCHEMA IF NOT EXISTS app")
        print("Схема 'app' проверена/создана")

        for i, sql in enumerate(CREATE_TABLES, 1):
            await conn.execute(sql)
        print(f"Создано {len(CREATE_TABLES)} таблиц/индексов")


async def sync_users(pool):
    """Синхронизирует пользователей из hr.employees + hr.positions"""
    async with pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT 
                e.id AS emp_id,
                e.full_name,
                e.email,
                p.system_name,
                p.position_name
            FROM hr.employees e
            JOIN hr.positions p ON e.position_id = p.id
            WHERE p.system_name = ANY($1)
            AND e.email IS NOT NULL AND e.email != ''
        """, list(ROLE_MAP.keys()))

        if not rows:
            print("Не найдено сотрудников с целевыми должностями")
            return

        created = 0
        updated = 0

        for row in rows:
            role = ROLE_MAP[row["system_name"]]
            login = row["email"].lower().strip()
            password = secrets.token_urlsafe(12)  # генерируем пароль
            pwd_hash = bcrypt.hash(password)

            # Вставляем или обновляем
            result = await conn.fetchval("""
                INSERT INTO app.users (full_name, login, password_hash, role)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT (login) DO UPDATE 
                SET full_name = $1, role = $4, password_hash = CASE 
                    WHEN app.users.password_hash IS NULL THEN $3 
                    ELSE app.users.password_hash 
                END
                RETURNING (xmax = 0) AS inserted
            """, row["full_name"], login, pwd_hash, role)

            if result:  # xmax=0 значит строка была вставлена (не обновлена)
                created += 1
                print(f"{row['full_name']} ({login}) → {role} | пароль: {password}")
            else:
                updated += 1
                print(f"{row['full_name']} ({login}) → {role} (обновлён)")

        print(f"\nИтого: создано {created}, обновлено {updated} пользователей")


async def main():
    print("Инициализация базы данных...")
    print(f"Подключение: {mask_database_url(DATABASE_URL)}")

    # Валидация DATABASE_URL перед подключением
    if not validate_database_url(DATABASE_URL):
        print(f"Некорректный DATABASE_URL: {DATABASE_URL}")
        print("Ожидаемый формат: postgresql://user:pass@host:port/dbname")
        sys.exit(1)

    try:
        pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=3)

        await init_schema(pool)
        await sync_users(pool)

        async with pool.acquire() as conn:
            count = await conn.fetchval("SELECT COUNT(*) FROM app.users")
            print(f"\nКоличество пользователей в схеме 'app': {count}")

    except asyncpg.exceptions.InvalidCatalogNameError:
        print("Ошибка: база данных не найдена")
        print("  Проверьте, что БД существует и имя указано верно")
        sys.exit(1)
    except asyncpg.exceptions.InvalidAuthorizationSpecificationError:
        print("Ошибка аутентификации: неверный логин или пароль")
        print("  Проверьте учётные данные в .env")
        sys.exit(1)
    except asyncpg.exceptions.PostgresError as e:
        print(f"Ошибка PostgreSQL: {e}")
        print("  Проверьте: 1) подключена ли БД; 2) права пользователя; 3) существует ли схема 'hr'")
        sys.exit(1)
    except Exception as e:
        print(f"Ошибка: {type(e).__name__}: {e}")
        sys.exit(1)
    finally:
        if 'pool' in locals():
            await pool.close()

    print("\nИнициализация успешно завершена!")


if __name__ == "__main__":
    asyncio.run(main())
