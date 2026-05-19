from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from db import connect_db, close_db
from routes import login, requests, employees, positions


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db(app)
    yield
    await close_db(app)

app = FastAPI(lifespan=lifespan)
app.include_router(login.router)
app.include_router(requests.router)
app.include_router(employees.router)
app.include_router(positions.router)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8080",
        "http://localhost:80",
        "http://127.0.0.1:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {"message": "HR System API"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", reload=True)
