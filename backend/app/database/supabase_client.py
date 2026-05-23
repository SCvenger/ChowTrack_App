# pyrefly: ignore [missing-import]
from supabase import create_client, Client
from app.core.config import settings

# Validar credenciales al importar
settings.validate()

try:
    supabase_anon: Client = create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_ANON_KEY
    )
    print("[OK] Conexión Supabase (anon) establecida")
except Exception as e:
    raise RuntimeError(f"No se pudo conectar a Supabase (anon): {e}")

try:
    supabase_admin: Client = create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_ROLE_KEY
    )
    print("[OK] Conexión Supabase (service_role) establecida")
except Exception as e:
    raise RuntimeError(f"No se pudo conectar a Supabase (service_role): {e}")


# Inyectores de dependencia para FastAPI

# Llave Cliente
def get_supabase_client() -> Client:
    return supabase_anon

# Llave Administrador
def get_supabase_admin() -> Client:
    return supabase_admin