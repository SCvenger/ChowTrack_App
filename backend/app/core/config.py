import os
# pyrefly: ignore [missing-import]
from dotenv import load_dotenv

# Cargamos el archivo .env
load_dotenv()

class Settings:
    PROJECT_NAME: str = "Chow-Track API"
    VERSION: str = "1.0.0"
    
    # Credenciales de Supabase
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")
    
    # Configuración del servidor
    PORT: int = int(os.getenv("PORT", 8000))

# Instancia global para usar en todo el backend
settings = Settings()