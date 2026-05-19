import asyncpg
from fastapi import FastAPI
from const import DATABASE_URL

async def set_search_path(connection):
    await connection.execute("SET search_path TO app, hr, public")

async def connect_db(app: FastAPI):
    app.state.pool = await asyncpg.create_pool(
        DATABASE_URL,
        init=set_search_path,
        min_size=2,
        max_size=10
    )
    async with app.state.pool.acquire() as conn:
        result = await conn.fetchval("SHOW search_path")
        print(f"Search path установлен: {result}")    


async def close_db(app: FastAPI):
    await app.state.pool.close()