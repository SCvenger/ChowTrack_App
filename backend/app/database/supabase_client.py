# pyrefly: ignore [missing-import]
from supabase import create_client, Client
from app.core.config import settings
from app.core.errors import ChowTrackException

# Variables globales para el cliente
supabase: Client = None

def init_supabase():
    """
    Inicializa el cliente global de Supabase utilizando las variables de entorno.
    """
    global supabase
    
    # Control de errores explícito por si olvidaste llenar el .env
    if not settings.SUPABASE_URL or not settings.SUPABASE_KEY:
        raise ChowTrackException(
            status_code=500,
            message="Error de configuración interna del servidor.",
            detail="Las variables SUPABASE_URL o SUPABASE_KEY no están configuradas en el archivo .env"
        )
        
    try:
        # Creamos la conexión oficial
        supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        print("🚀 ¡Conexión exitosa con la base de datos de Supabase!")
    except Exception as e:
        raise ChowTrackException(
            status_code=500,
            message="No se pudo establecer conexión con los servidores de la base de datos.",
            detail=str(e)
        )