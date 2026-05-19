import asyncpg
from fastapi import FastAPI
from const import DATABASE_URL


async def connect_db(app: FastAPI):
    app.state.pool = await asyncpg.create_pool(DATABASE_URL)


async def close_db(app: FastAPI):
    await app.state.pool.close()
