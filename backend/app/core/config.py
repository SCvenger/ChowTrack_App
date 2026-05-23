import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    PROJECT_NAME: str = "Chow-Track API"
    VERSION: str = "1.0.0"
    
    # Supabase 
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "")
    SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    
    # Servidor 
    PORT: int = int(os.getenv("PORT", "8000"))
    DEBUG: bool = os.getenv("DEBUG", "true").lower() == "true"
    
    # CORS 
    CORS_ORIGINS: list = [
        "http://localhost:3000",      
        "http://10.0.2.2:3000",       
        "http://127.0.0.1:3000",      
    ]
    
    # OAuth 
    GOOGLE_REDIRECT_URI: str = os.getenv(
        "GOOGLE_REDIRECT_URI",
        "chowtrack://auth/callback"
    )
    
    # Validaciones
    MIN_PASSWORD_LENGTH: int = 6 
    EMBEDDING_DIMENSION: int = 512

    def validate(self):
        missing = []
        if not self.SUPABASE_URL:
            missing.append("SUPABASE_URL")
        if not self.SUPABASE_ANON_KEY:
            missing.append("SUPABASE_ANON_KEY")
        if not self.SUPABASE_SERVICE_ROLE_KEY:
            missing.append("SUPABASE_SERVICE_ROLE_KEY")
        
        if missing:
            raise EnvironmentError(
                f"Faltan variables de entorno: {', '.join(missing)}. "
                f"Revisa tu archivo .env"
            )

# Instancia global
settings = Settings()