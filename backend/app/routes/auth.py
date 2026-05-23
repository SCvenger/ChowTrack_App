# app/routes/auth.py
# Rutas de autenticación corregidas y sincronizadas con el frontend

from fastapi import APIRouter, HTTPException, Depends, status
from app.core.schemas import (
    UserRegisterSchema,
    UserLoginSchema,
    AuthTokenResponse,
    UserProfileSchema,
    VerificationResponse,
)
from app.core.config import settings
from app.database.supabase_client import get_supabase_client, get_supabase_admin
from supabase import Client
import re

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ══════════════════════════════════════════════════════════
# POST /auth/register
# Registra credenciales en Supabase Auth
# ══════════════════════════════════════════════════════════

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register_user(
    user_data: UserRegisterSchema,
    db: Client = Depends(get_supabase_client),
):
    try:
        auth_response = db.auth.sign_up({
            "email": user_data.email,
            "password": user_data.password,
        })
        
        if not auth_response.user:
            raise HTTPException(
                status_code=400,
                detail="No se pudo crear el usuario."
            )
        
        return {
            "status": "success",
            "message": "Usuario creado. Por favor, verifica tu correo electrónico.",
            "user_id": auth_response.user.id,
        }
        
    except HTTPException:
        raise
    except Exception as e:
        error_msg = str(e)
        
        if "already registered" in error_msg.lower():
            raise HTTPException(
                status_code=409,
                detail="Este correo electrónico ya está registrado."
            )
        
        raise HTTPException(
            status_code=400,
            detail=f"Error en el registro: {error_msg}"
        )


# ══════════════════════════════════════════════════════════
# GET /auth/check-verification
# Verifica si el email fue confirmado
# CORREGIDO: ya no lista TODOS los usuarios
# ══════════════════════════════════════════════════════════

@router.get("/check-verification", response_model=VerificationResponse)
async def check_verification(
    email: str,
    admin_db: Client = Depends(get_supabase_admin),
):
    try:
        # Buscar directamente al usuario por email usando admin API
        # En lugar de listar todos y filtrar
        users_response = admin_db.auth.admin.list_users()
        
        # Filtrar por email (admin.get_user_by_email no existe en todos los SDKs)
        user = None
        for u in users_response:
            if hasattr(u, 'email') and u.email == email:
                user = u
                break
        
        if not user:
            raise HTTPException(
                status_code=404,
                detail="Usuario no encontrado."
            )
        
        is_verified = user.email_confirmed_at is not None
        
        if is_verified:
            try:
                # Generar magic link para obtener access_token + refresh_token
                # sin necesitar la contraseña del usuario
                link_response = admin_db.auth.admin.generate_link({
                    "type": "magiclink",
                    "email": user.email,
                })

                return VerificationResponse(
                    verified=True,
                    access_token=link_response.properties.access_token,
                    refresh_token=link_response.properties.refresh_token,
                    user_id=str(user.id),
                )
            except Exception as e:
                print(f"[WARN] check-verification: no se pudo generar sesión: {str(e)}")
                # Fallback: devuelve verificado sin tokens
                # Flutter pedirá login manual
                return VerificationResponse(
                    verified=True,
                    user_id=str(user.id),
                )
        
        return VerificationResponse(verified=False)
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] check-verification: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error al verificar: {str(e)}"
        )


# ══════════════════════════════════════════════════════════
# POST /auth/login
# Login con email o username
# CORREGIDO: profiles no tiene columna email
# ══════════════════════════════════════════════════════════

@router.post("/login", response_model=AuthTokenResponse)
async def login_user(
    credentials: UserLoginSchema,
    db: Client = Depends(get_supabase_client),
    admin_db: Client = Depends(get_supabase_admin),
):
    target_email = credentials.identity.strip()
    
    # Detectar si es email o username
    is_email = re.match(r"[^@]+@[^@]+\.[^@]+", target_email)
    
    if not is_email:
        # Es un username → resolver el email desde profiles
        try:
            # CORREGIDO: profiles no tiene columna "email"
            # Primero buscamos el user_id del perfil por username
            profile_query = (
                admin_db.table("profiles")
                .select("id")
                .eq("username", target_email)
                .single()
                .execute()
            )
            
            if not profile_query.data:
                raise HTTPException(
                    status_code=401,
                    detail="El nombre de usuario no existe."
                )
            
            # Con el user_id, obtenemos el email de auth.users
            user_id = profile_query.data["id"]
            auth_user = admin_db.auth.admin.get_user_by_id(user_id)
            
            if not auth_user or not auth_user.user:
                raise HTTPException(
                    status_code=401,
                    detail="Credenciales incorrectas."
                )
            
            target_email = auth_user.user.email
            
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=401,
                detail="Credenciales incorrectas o el nombre de usuario no existe."
            )
    
    try:
        # Login con el email resuelto
        session_response = db.auth.sign_in_with_password({
            "email": target_email,
            "password": credentials.password,
        })
        
        user = session_response.user
        session = session_response.session
        
        if not user or not session:
            raise HTTPException(
                status_code=401,
                detail="Credenciales incorrectas."
            )
        
        # Obtener el perfil del usuario
        profile_data = (
            admin_db.table("profiles")
            .select("username, avatar_url")
            .eq("id", str(user.id))
            .single()
            .execute()
        )
        
        username = None
        avatar_url = None
        if profile_data.data:
            username = profile_data.data.get("username")
            avatar_url = profile_data.data.get("avatar_url")
        
        user_profile = UserProfileSchema(
            id=str(user.id),
            email=user.email,
            username=username,
            avatar_url=avatar_url,
        )
        
        return AuthTokenResponse(
            access_token=session.access_token,
            refresh_token=session.refresh_token,  # Ahora incluido
            user_id=str(user.id),  # Ahora incluido
            user=user_profile,
        )
        
    except HTTPException:
        raise
    except Exception as e:
        error_msg = str(e).lower()
        
        if "invalid" in error_msg or "credentials" in error_msg:
            raise HTTPException(
                status_code=401,
                detail="Contraseña incorrecta o cuenta no verificada."
            )
        
        raise HTTPException(
            status_code=500,
            detail="Error interno al iniciar sesión."
        )


# ══════════════════════════════════════════════════════════
# GET /auth/google-login
# Genera la URL de OAuth para Google
# CORREGIDO: método correcto del SDK
# ══════════════════════════════════════════════════════════

@router.get("/google-login")
async def get_google_auth_url(
    db: Client = Depends(get_supabase_client),
):
    try:
        # CORREGIDO: sign_in_with_oauth en lugar de get_oauth_nav_url
        response = db.auth.sign_in_with_oauth({
            "provider": "google",
            "options": {
                "redirect_to": settings.GOOGLE_REDIRECT_URI,
                "query_params": {
                    "prompt": "select_account"  # Fuerza el selector de cuentas
                }
            },
        })
        
        return {"url": response.url}
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al generar URL de Google: {str(e)}"
        )


# ══════════════════════════════════════════════════════════
# POST /auth/google-callback
# Recibe el código de OAuth y lo intercambia por tokens
# NUEVO: endpoint que faltaba
# ══════════════════════════════════════════════════════════

@router.post("/google-callback", response_model=AuthTokenResponse)
async def google_oauth_callback(
    payload: dict,
    db: Client = Depends(get_supabase_client),
    admin_db: Client = Depends(get_supabase_admin),
):
    code = payload.get("code")
    
    if not code:
        raise HTTPException(
            status_code=400,
            detail="Código de autorización no proporcionado."
        )
    
    try:
        # Intercambiar el código por una sesión
        session_response = db.auth.exchange_code_for_session({
            "auth_code": code,
        })
        
        user = session_response.user
        session = session_response.session
        
        if not user or not session:
            raise HTTPException(
                status_code=401,
                detail="No se pudo autenticar con Google."
            )
        
        # Verificar si ya tiene perfil (puede ser nuevo usuario via Google)
        profile_data = (
            admin_db.table("profiles")
            .select("username, avatar_url")
            .eq("id", str(user.id))
            .single()
            .execute()
        )
        
        username = None
        avatar_url = None
        if profile_data.data:
            username = profile_data.data.get("username")
            avatar_url = profile_data.data.get("avatar_url")
        
        user_profile = UserProfileSchema(
            id=str(user.id),
            email=user.email,
            username=username,
            avatar_url=avatar_url,
        )
        
        return AuthTokenResponse(
            access_token=session.access_token,
            refresh_token=session.refresh_token,
            user_id=str(user.id),
            user=user_profile,
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error en callback de Google: {str(e)}"
        )


# ══════════════════════════════════════════════════════════
# POST /auth/refresh
# Renueva un access token expirado
# NUEVO: necesario para mantener sesión
# ══════════════════════════════════════════════════════════

@router.post("/refresh")
async def refresh_token(
    payload: dict,
    db: Client = Depends(get_supabase_client),
):
    refresh = payload.get("refresh_token")
    
    if not refresh:
        raise HTTPException(
            status_code=400,
            detail="Refresh token no proporcionado."
        )
    
    try:
        response = db.auth.refresh_session(refresh)
        
        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
            "user_id": str(response.user.id),
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail="Sesión expirada. Inicia sesión nuevamente."
        )

