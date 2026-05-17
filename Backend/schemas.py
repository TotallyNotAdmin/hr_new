from pydantic import BaseModel
from typing import Optional, List


# -------- AUTH --------
class LoginRequest(BaseModel):
    login: str
    password: str


class TokenResponse(BaseModel):
    access_token: str


# -------- USERS --------
class User(BaseModel):
    id: int
    full_name: str
    role: str


# -------- REQUEST DATA --------
class RequestField(BaseModel):
    name: str
    as_is: Optional[str] = None
    to_be: Optional[str] = None


class CreateRequest(BaseModel):
    #  creator_id: int
    scenario_type: int
    fields: List[RequestField]
    comment: Optional[str] = None
    description: Optional[str] = None


class RequestResponse(BaseModel):
    id: int
    creator_id: int
    scenario_type: int
    status: str


# -------- EMPLOYEES --------
class Employee(BaseModel):
    id: int
    full_name: str
    position_id: Optional[int]
    position_name: Optional[str] = None


# -------- POSITIONS --------
class Position(BaseModel):
    id: int
    system_name: str
    position_name: str
    address: Optional[str]
    salary: Optional[float]
    bonus_month: Optional[float] = 0
    bonus_quarter: Optional[float] = 0
    bonus_year: Optional[float] = 0


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str
