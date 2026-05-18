# pyrefly: ignore [missing-import]
from pydantic import BaseModel, EmailStr, Field
from typing import Optional

# 1. Registro ultra limpio (Solo Credenciales)
class UserRegisterSchema(BaseModel):
    email: EmailStr = Field(..., description="Correo electrónico del usuario")
    password: str = Field(..., min_length=8, description="Contraseña de mínimo 8 caracteres")

# 2. Login Flexible (Acepta Correo o Username en 'identity')
class UserLoginSchema(BaseModel):
    identity: str = Field(..., description="Puede ser el correo electrónico o el username")
    password: str

# 3. El formato de perfil que Flutter leerá/guardará después
class UserProfileSchema(BaseModel):
    id: str
    email: EmailStr
    username: Optional[str] = None
    avatar_url: Optional[str] = None

# 4. Respuesta completa para Flutter
class AuthTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserProfileSchema