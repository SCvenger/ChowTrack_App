# pyrefly: ignore [missing-import]
from pydantic import BaseModel, EmailStr, Field
from typing import Optional


# AUTH SCHEMAS
class UserRegisterSchema(BaseModel):
    email: EmailStr = Field(..., description="Correo electrónico del usuario")
    password: str = Field(
        ...,
        min_length=6,
        description="Contraseña de mínimo 6 caracteres con letras y números"
    )


class UserLoginSchema(BaseModel):
    identity: str = Field(
        ...,
        description="Puede ser el correo electrónico o el username"
    )
    password: str = Field(..., min_length=1)


class UserProfileSchema(BaseModel):
    id: str
    email: EmailStr
    username: Optional[str] = None
    avatar_url: Optional[str] = None


class AuthTokenResponse(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    user_id: str
    user: UserProfileSchema


class VerificationResponse(BaseModel):
    verified: bool
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    user_id: Optional[str] = None


# PET SCHEMAS
class PetCreateSchema(BaseModel):
    name: str = Field(
        ...,
        min_length=2,
        max_length=20,
        description="Nombre de la mascota",
    )
    breed: Optional[str] = Field(
        None,
        max_length=20,
        description="Raza de la mascota",
    )
    age_years: Optional[int] = Field(
        None,
        ge=0,
        le=30,
        description="Edad en años (0–30)",
    )
    photo_url: Optional[str] = Field(
        None,
        description="URL pública en Supabase Storage",
    )
    notes: Optional[str] = Field(
        None,
        max_length=500,
        description="Descripción adicional",
    )
    phone: Optional[str] = Field(
        None,
        pattern=r'^\+591\s?[678]\d{7}$',
        description="Teléfono: +591 seguido de 8 dígitos",
    )


class PetResponseSchema(BaseModel):
    id: str
    owner_id: str
    name: str
    breed: Optional[str] = None
    age_years: Optional[int] = None
    photo_url: Optional[str] = None
    status: str = "home"
    notes: Optional[str] = None
    created_at: Optional[str] = None


class PetStatusUpdateSchema(BaseModel):
    status: str = Field(..., pattern="^(home|lost|found)$")
    notes: Optional[str] = None

