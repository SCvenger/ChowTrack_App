from app.core.errors import ChowTrackException
import os
# pyrefly: ignore [missing-import]
from supabase import create_client, Client
# pyrefly: ignore [missing-import]
from dotenv import load_dotenv


# Cargar las variables de entorno desde el archivo .env
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

# Validar que las credenciales existan para evitar que falle en silencio
if not SUPABASE_URL or not SUPABASE_KEY:
    raise ChowTrackException(
        status_code=500, 
        message="Faltan las credenciales de Supabase en el archivo .env",
        detail="Por favor, asegúrate de que las variables SUPABASE_URL y SUPABASE_KEY estén correctamente configuradas en tu archivo .env"
    )
try:
    # Creamos la conexión oficial
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("🚀 ¡Conexión exitosa con la base de datos de Supabase!")
except Exception as e:
    raise ChowTrackException(
        status_code=500,
        message="No se pudo establecer conexión con los servidores de la base de datos.",
        detail=str(e)
    )



# Esta es la función que tu archivo auth.py está intentando importar
def get_supabase_client() -> Client:
    """
    Inyector de dependencia para FastAPI.
    Devuelve la instancia activa del cliente de Supabase.
    """
    return supabase