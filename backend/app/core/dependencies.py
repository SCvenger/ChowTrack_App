# pyrefly: ignore [missing-import]
from fastapi import Header
from app.core.errors import ChowTrackException
from app.database.supabase_client import supabase_anon


async def get_current_user_id(
    authorization: str = Header(..., description="Bearer <access_token>")
) -> str:

    try:
        if not authorization or not authorization.startswith("Bearer "):
            raise ChowTrackException(
                status_code=401,
                message="Token de autorización requerido",
                detail="missing_bearer_prefix",
            )

        token = authorization.removeprefix("Bearer ").strip()

        if not token:
            raise ChowTrackException(
                status_code=401,
                message="Token vacío",
                detail="empty_token",
            )

        # Validar el JWT contra Supabase Auth
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


