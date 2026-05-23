from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.errors import global_exception_handler, ChowTrackException
from app.routes import auth
from app.routes import pets

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    docs_url="/docs" if settings.DEBUG else None,  # Desactivar docs en prod
    redoc_url="/redoc" if settings.DEBUG else None,
)


# MIDDLEWARE: CORS (Conexión con flutter)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS if not settings.DEBUG else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(ChowTrackException, global_exception_handler)
app.add_exception_handler(Exception, global_exception_handler)


# RUTAS
app.include_router(auth.router)
app.include_router(pets.router)


@app.get("/", tags=["Health"])
def root():
    return {
        "status": "online",
        "project": settings.PROJECT_NAME,
        "version": settings.VERSION,
    }

