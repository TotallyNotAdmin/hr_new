from fastapi import APIRouter, Request, Depends
from schemas import Position
from auth import require_role
from models import Role
import io
from openpyxl import Workbook
from fastapi.responses import StreamingResponse

router = APIRouter(prefix="/positions")


@router.get("/", response_model=list[Position])
async def get_positions(
    request: Request,
    user=Depends(require_role([Role.MANAGER, Role.APPROVER, Role.EXECUTOR]))
):
    pool = request.app.state.pool

    async with pool.acquire() as conn:
        rows = await conn.fetch("SELECT * FROM hr.positions WHERE is_active=true")

    return [dict(row) for row in rows]


@router.get("/export")
async def export_positions(request: Request, user=Depends(require_role([Role.MANAGER]))):
    pool = request.app.state.pool
    async with pool.acquire() as conn:
        rows = await conn.fetch("SELECT id, position_name, address, salary, is_active FROM hr.positions ORDER BY id")

    wb = Workbook()
    ws = wb.active
    ws.title = "Штатные единицы"
    ws.append(["ID", "Должность", "Адрес", "Оклад", "Активна"])
    for r in rows: ws.append(
        [r["id"], r["position_name"], r["address"] or "—", r["salary"] or "—", "Да" if r["is_active"] else "Нет"])

    from openpyxl.styles import Border, Side
    thin_border = Border(left=Side(style='thin'), right=Side(style='thin'), top=Side(style='thin'),
                         bottom=Side(style='thin'))
    for col in ws.columns:
        max_l = max(len(str(c.value)) for c in col if c.value) if any(c.value for c in col) else 10
        if col[0].column_letter: ws.column_dimensions[col[0].column_letter].width = min(max_l + 3, 45)
        for cell in col: cell.border = thin_border

    output = io.BytesIO()
    wb.save(output)
    output.seek(0)
    return StreamingResponse(output, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                             headers={"Content-Disposition": "attachment; filename=positions.xlsx"})


@router.get("/{id}")
async def get_position(
    id: int,
    request: Request,
    user=Depends(require_role([Role.MANAGER, Role.APPROVER, Role.EXECUTOR]))
):
    pool = request.app.state.pool

    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM hr.positions WHERE id=$1",
            id
        )

    return dict(row)


@router.get("/{id}/check")
async def check_position(
    id: int,
    request: Request,
    user=Depends(require_role([Role.MANAGER]))
):
    pool = request.app.state.pool

    async with pool.acquire() as conn:
        employee = await conn.fetchrow(
            "SELECT * FROM hr.employees WHERE position_id=$1",
            id
        )

    return {"has_employee": bool(employee)}
