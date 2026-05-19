from fastapi import APIRouter, Request, Depends
from schemas import Employee
from auth import require_role
from models import Role
from openpyxl import Workbook

router = APIRouter(prefix="/employees")


@router.get("/", response_model=list[Employee])
async def get_employees(
    request: Request,
    user=Depends(require_role([Role.MANAGER, Role.APPROVER, Role.EXECUTOR]))
):
    pool = request.app.state.pool
    async with pool.acquire() as conn:

        rows = await conn.fetch("""
            SELECT e.id, e.full_name, e.position_id, p.position_name
            FROM hr.employees e
            LEFT JOIN hr.positions p ON e.position_id = p.id
        """)
        return [dict(row) for row in rows]


@router.get("/export")
async def export_employees(request: Request, user=Depends(require_role([Role.MANAGER]))):
    pool = request.app.state.pool
    async with pool.acquire() as conn:
        # Добавляем JOIN для получения должности
        rows = await conn.fetch("""
            SELECT e.id, e.full_name, p.position_name 
            FROM hr.employees e 
            LEFT JOIN hr.positions p ON e.position_id = p.id 
            ORDER BY e.id
        """)

    wb = Workbook()
    ws = wb.active
    ws.title = "Сотрудники"
    ws.append(["ID", "ФИО", "Должность"])
    for r in rows:
        ws.append([r["id"], r["full_name"], r["position_name"] or "Не назначена"])

    # Форматирование
    from openpyxl.styles import Border, Side, Alignment
    thin_border = Border(left=Side(style='thin'), right=Side(style='thin'), top=Side(style='thin'),
                         bottom=Side(style='thin'))
    for col in ws.columns:
        max_l = max(len(str(c.value)) for c in col if c.value) if any(c.value for c in col) else 10
        if col[0].column_letter:
            ws.column_dimensions[col[0].column_letter].width = min(max_l + 3, 45)
        for cell in col:
            cell.border = thin_border
            cell.alignment = Alignment(vertical='center')

    import io
    from fastapi.responses import StreamingResponse
    output = io.BytesIO()
    wb.save(output)
    output.seek(0)
    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=employees.xlsx"}
    )
