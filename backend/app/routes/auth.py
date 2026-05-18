# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException, Depends, status
from app.core.schemas import UserRegisterSchema, UserLoginSchema, AuthTokenResponse, UserProfileSchema
from app.database.supabase_client import get_supabase_client
# pyrefly: ignore [missing-import]
from supabase import Client
import re

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register_user(user_data: UserRegisterSchema, db: Client = Depends(get_supabase_client)):
    try:
        # 1. Registrar únicamente las credenciales en Supabase Auth
        auth_response = db.auth.sign_up({
            "email": user_data.email,
            "password": user_data.password
        })
        
        if not auth_response.user:
            raise HTTPException(
                status_code=400, 
                detail="No se pudo crear el usuario.")
        
        return {"status": "success", "message": "Usuario creado. Por favor, verifica tu correo electrónico."}
        
    except Exception as e:
        raise HTTPException(
            status_code=400, 
            detail=f"Error en el registro: {str(e)}")

@router.get("/check-verification")
def check_verification(email: str, db: Client = Depends(get_supabase_client)):
    try:
        # 1. Obtenemos la respuesta del listado de administración
        response = db.auth.admin.list_users()
        
        # 2. Extraemos la lista real de usuarios usando la propiedad '.users'
        users_list = response.users if hasattr(response, 'users') else response
        
        # 3. Buscamos al usuario por correo electrónico
        user = next((u for u in users_list if u.email == email), None)

        # 4. Evaluamos si el campo de confirmación ya tiene la estampa de tiempo
        if user and user.email_confirmed_at is not None:
            return {"verified": True}
            
        return {"verified": False}
        
    except Exception as e:
        print(f"Falló la verificación: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error en servidor: {str(e)}")

@router.get("/google-login")
def get_google_auth_url(db: Client = Depends(get_supabase_client)):
    try:
        # Le pedimos a Supabase la URL para iniciar sesión con Google
        res = db.auth.get_oauth_nav_url({
            "provider": "google",
            "options": {
                "redirect_to": "io.supabase.chowtrack://login-callback/"
            }
        })
        return {"url": res.url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/login", response_model=AuthTokenResponse)
async def login_user(credentials: UserLoginSchema, db: Client = Depends(get_supabase_client)):
    target_email = credentials.identity.strip()
    
    # Expresión regular simple para verificar si la identidad provista NO es un correo
    is_email = re.match(r"[^@]+@[^@]+\.[^@]+", target_email)
    
    # LÓGICA DE DOBLE IDENTIDAD: Si no es un correo, asumimos que es un username
    if not is_email:
        try:
            # Buscamos en la tabla de perfiles cuál correo pertenece a ese username
            profile_query = db.table("profiles").select("email").eq("username", target_email).single().execute()
            if not profile_query.data:
                raise HTTPException(
                    status_code=401, 
                    detail="El nombre de usuario no existe.")
            
            # Reemplazamos la identidad por el correo real asociado
            target_email = profile_query.data["email"]
        except Exception:
            raise HTTPException(
                status_code=401, 
                detail="Credenciales incorrectas o el nombre de usuario no existe.")

    try:
        # 2. Intentar el inicio de sesión en Supabase Auth con el correo resuelto
        session_response = db.auth.sign_in_with_password({
            "email": target_email,
            "password": credentials.password
        })
        
        user_id = session_response.user.id
        access_token = session_response.session.access_token
        
        # 3. Traer los datos actualizados del perfil para enviárselos a Flutter
        profile_data = db.table("profiles").select("username", "email").eq("id", user_id).single().execute()
        
        user_profile = UserProfileSchema(
            id=user_id,
            email=profile_data.data["email"],
            username=profile_data.data["username"]
        )
        
        return AuthTokenResponse(
            access_token=access_token,
            user=user_profile
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=401, 
            detail="Contraseña incorrecta o cuenta no verificada.")