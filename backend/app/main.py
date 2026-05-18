# pyrefly: ignore [missing-import]
from fastapi import FastAPI
from app.routes import auth  # Importamos nuestro nuevo enrutador

app = FastAPI(title="Chow-Track API", version="1.0.0")

# Registrar las rutas del módulo de Autenticación
app.include_router(auth.router)

@app.get("/")
def root():
    return {"status": "online", "project": "Chow-Track"}