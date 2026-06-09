# app/core/schemas.py

# pyrefly: ignore [missing-import]
from pydantic import BaseModel, EmailStr, Field
from typing import Optional


# ══════════════════════════════════════════════════════════
# AUTH SCHEMAS
# ══════════════════════════════════════════════════════════

class UserRegisterSchema(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)


class UserLoginSchema(BaseModel):
    identity: str
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


# ══════════════════════════════════════════════════════════
# PET SCHEMAS
# ══════════════════════════════════════════════════════════

class PetCreateSchema(BaseModel):
    name: str = Field(..., min_length=2, max_length=50)
    breed: Optional[str] = Field(None, max_length=50)
    age_years: Optional[int] = Field(None, ge=0, le=30)
    photo_url: Optional[str] = None
    notes: Optional[str] = Field(None, max_length=500)
    phone: Optional[str] = Field(
        None,
        pattern=r'^\+591\s?[678]\d{7}$',
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
    has_nose_scan: bool = False
    last_seen_lat: Optional[float] = None
    last_seen_lng: Optional[float] = None
    last_seen_at: Optional[str] = None


class PetStatusUpdateSchema(BaseModel):
    """Actualiza estado + guarda ubicación cuando status == 'lost'."""
    status: str = Field(..., pattern="^(home|lost|found)$")
    notes: Optional[str] = None
    last_seen_lat: Optional[float] = Field(None, ge=-90, le=90)
    last_seen_lng: Optional[float] = Field(None, ge=-180, le=180)


# ══════════════════════════════════════════════════════════
# MAP SCHEMAS
# ══════════════════════════════════════════════════════════

class MapPetSchema(BaseModel):
    """Schema ligero para marcadores en el mapa."""
    id: str
    name: str
    status: str           # lost | found
    photo_url: Optional[str] = None
    breed: Optional[str] = None
    lat: float
    lng: float
    is_own: bool = False  # True si pertenece al usuario autenticado


# ══════════════════════════════════════════════════════════
# PROFILE SCHEMAS
# ══════════════════════════════════════════════════════════

class ProfileResponseSchema(BaseModel):
    id: str
    display_name: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None
    created_at: Optional[str] = None


# ══════════════════════════════════════════════════════════
# SIGHTING SCHEMAS
# ══════════════════════════════════════════════════════════

class SightingCreateSchema(BaseModel):
    photo_url: str
    nose_photo_url: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_text: Optional[str] = None
    notes: Optional[str] = None
    reporter_name: Optional[str] = None
    reporter_phone: Optional[str] = None


class SightingResponseSchema(BaseModel):
    id: str
    status: str
    photo_url: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_text: Optional[str] = None
    reported_at: str


# ══════════════════════════════════════════════════════════
# MATCH SCHEMAS
# ══════════════════════════════════════════════════════════

class MatchResponseSchema(BaseModel):
    id: str
    sighting_id: str
    pet_id: str
    similarity_score: float
    status: str
    pet: Optional[PetResponseSchema] = None


class MatchStatusUpdateSchema(BaseModel):
    status: str = Field(..., pattern="^(confirmed|rejected|reunited)$")
    notes: Optional[str] = None