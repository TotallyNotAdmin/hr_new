from fastapi import APIRouter, Request, HTTPException, Depends
from passlib.hash import bcrypt
from schemas import LoginRequest, TokenResponse, ChangePasswordRequest
from auth import create_token, require_role
from models import Role
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


def _safe_password(pwd: str, max_bytes: int = 72) -> str:
    pwd_bytes = pwd.encode('utf-8')
    if len(pwd_bytes) <= max_bytes:
        return pwd
    return pwd_bytes[:max_bytes].decode('utf-8', errors='ignore')


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, request: Request):
    logger.debug(f"Попытка входа: {data.login} (длина пароля: {len(data.password.encode('utf-8'))} байт)")
    pool = request.app.state.pool
    async with pool.acquire() as conn:
        login_input = data.login.lower().strip()
        user = await conn.fetchrow(
            "SELECT * FROM users WHERE login=$1",
            login_input
        )
        print("INPUT PASSWORD:", data.password)
        print("HASH FROM DB:", user["password_hash"])
        #  print("VERIFY:", bcrypt.verify(data.password, user["password_hash"]))        


        if not user:
            raise HTTPException(status_code=401, detail="Неверный логин или пароль")
            
        if not bcrypt.verify(_safe_password(data.password), user["password_hash"]):
            raise HTTPException(status_code=401, detail="Неверный логин или пароль")
            
        token = create_token({
            "user_id": user["id"],
            "login": user["login"],
            "role": user["role"]
        })
        
        return {
            "access_token": token,
            "role": user["role"]
        }


@router.post("/change-password")
async def change_password(
    data: ChangePasswordRequest,
    request: Request,
    user=Depends(require_role([Role.MANAGER, Role.APPROVER, Role.EXECUTOR]))
):
    pool = request.app.state.pool
    async with pool.acquire() as conn:
        row = await conn.fetchrow("SELECT password_hash FROM users WHERE id=$1", user["user_id"])
        
        if not row or not bcrypt.verify(_safe_password(data.current_password), row["password_hash"]):
            raise HTTPException(status_code=400, detail="Неверный текущий пароль!")
            
        if data.current_password == data.new_password:
            raise HTTPException(status_code=400, detail="Новый пароль не должен совпадать с текущим!")
            
        await conn.execute(
            "UPDATE users SET password_hash=$1 WHERE id=$2",
            bcrypt.hash(_safe_password(data.new_password)),
            user["user_id"]
        )
        return {"message": "Пароль успешно изменен"}
