from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import settings
from app.database import health_check, init_db
from app.routers.account import router as account_router
from app.routers.company import router as company_router
from app.routers.current_account import router as current_account_router
from app.routers.document import router as document_router
from app.routers.parameter import router as parameter_router
from app.routers.period_end import router as period_end_router
from app.routers.report import router as report_router
from app.routers.voucher import router as voucher_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "Turkiye muhasebe mevzuatina uygun SQL tabanli muhasebe cekirdegi. "
        "Mizan, yevmiye, buyuk defter, muavin, vergi ve donem sonu islemlerini kapsar."
    ),
    lifespan=lifespan,
)


@app.get("/")
def root() -> dict:
    return {
        "application": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
        "db_healthy": health_check(),
        "api_prefix": settings.API_V1_PREFIX,
    }


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok" if health_check() else "degraded",
        "database": "up" if health_check() else "down",
    }


app.include_router(company_router, prefix=settings.API_V1_PREFIX)
app.include_router(account_router, prefix=settings.API_V1_PREFIX)
app.include_router(current_account_router, prefix=settings.API_V1_PREFIX)
app.include_router(document_router, prefix=settings.API_V1_PREFIX)
app.include_router(voucher_router, prefix=settings.API_V1_PREFIX)
app.include_router(report_router, prefix=settings.API_V1_PREFIX)
app.include_router(period_end_router, prefix=settings.API_V1_PREFIX)
app.include_router(parameter_router, prefix=settings.API_V1_PREFIX)
