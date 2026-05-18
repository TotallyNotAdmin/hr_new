import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    # Ищем .env в корне проекта
    env_path = Path(__file__).parent.parent / ".env"
    if env_path.exists():
        load_dotenv(env_path)
except ImportError:
    pass

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError(
        "Ошибка: DATABASE_URL не задан!\n"
        "1) Убедитесь, что файл .env существует в корне проекта\n"
        "2) Проверьте, что переменная экспортирована: export DATABASE_URL=..."
    )

JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-secret-key-change-in-production")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost")