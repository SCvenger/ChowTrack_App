# app/core/dependencies.py

# pyrefly: ignore [missing-import]
from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.errors import ChowTrackException
from app.database.supabase_client import supabase_anon

bearer_scheme = HTTPBearer()

async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> str:
    try:
        token = credentials.credentials

        if not token:
            raise ChowTrackException(
                status_code=401,
                message="Token vacío",
                detail="empty_token",
            )

        user_response = supabase_anon.auth.get_user(token)

        if not user_response or not user_response.user:
            raise ChowTrackException(
                status_code=401,
                message="Sesión inválida o expirada",
                detail="invalid_token",
            )

        return user_response.user.id

    except ChowTrackException:
        raise
    except Exception as e:
        raise ChowTrackException(
            status_code=401,
            message="No autorizado",
            detail=str(e),
        )