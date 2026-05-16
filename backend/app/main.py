from contextlib import asynccontextmanager
# pyrefly: ignore [missing-import]
from fastapi import FastAPI 
from app.core.errors import global_exception_handler
from app.core.config import settings
from app.database.supabase_client import init_supabase

# Configuramos el ciclo de vida de la aplicación
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Código que se ejecuta AL ARRANCAR el servidor
    init_supabase()
    yield
    # Aquí iría código que se ejecuta AL APAGAR el servidor (si fuera necesario)

# Pasamos el lifespan a la instancia de FastAPI
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Backend oficial para la recuperación canina por biometría nasal",
    version=settings.VERSION,
    lifespan=lifespan
)

# Registramos el manejador global de excepciones
app.add_exception_handler(Exception, global_exception_handler)

@get_route := app.get("/")
def read_root():
    return {
        "status": "online",
        "app": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "environment": "development"
    }