# app/routes/map.py

# pyrefly: ignore [missing-import]
from fastapi import APIRouter, Depends, Query
from typing import List
from math import radians, cos, sin, asin, sqrt
from datetime import datetime, timezone, timedelta

from app.core.schemas import MapPetSchema
from app.core.errors import ChowTrackException
from app.core.dependencies import get_current_user_id
from app.database.supabase_client import supabase_admin


router = APIRouter(prefix="/map", tags=["Map"])


# ── Haversine: distancia en metros entre dos coordenadas ────────────────────
def _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6_371_000  # Radio Tierra en metros
    lat1, lng1, lat2, lng2 = map(radians, [lat1, lng1, lat2, lng2])
    dlat = lat2 - lat1
    dlng = lng2 - lng1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlng / 2) ** 2
    return R * 2 * asin(sqrt(a))


# ── ¿El timestamp ISO está dentro de la última hora? ────────────────────────
def _within_last_hour(iso_ts: str | None, now: datetime) -> bool:
    if not iso_ts:
        return False
    try:
        # Supabase devuelve ISO con zona; normaliza el sufijo 'Z'
        ts = datetime.fromisoformat(iso_ts.replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return False
    return (now - ts) <= timedelta(hours=1)


# ══════════════════════════════════════════════════════════
# GET /map/pets
# Mascotas perdidas/avistadas dentro del radio del usuario
# ══════════════════════════════════════════════════════════

@router.get(
    "/pets",
    response_model=List[MapPetSchema],
    summary="Mascotas cercanas en el mapa",
    description=(
        "Retorna mascotas LOST/FOUND con coordenadas conocidas dentro del "
        "radio especificado. Tambien incluye mascotas HOME ('en casa') que "
        "fueron recuperadas en las ultimas 24h (pin verde temporal). El campo "
        "`is_own` indica si la mascota pertenece al usuario autenticado."
    ),
)
async def get_map_pets(
    lat: float = Query(..., ge=-90, le=90, description="Latitud del usuario"),
    lng: float = Query(..., ge=-180, le=180, description="Longitud del usuario"),
    radius: int = Query(5000, ge=100, le=50_000, description="Radio en metros"),
    user_id: str = Depends(get_current_user_id),
):
    try:
        # 1. Obtener mascotas activas con coordenadas conocidas.
        #    LOST/FOUND siempre son relevantes; HOME solo si fue recuperada
        #    en las ultimas 24h (pin verde temporal, ver paso 2).
        response = (
            supabase_admin
            .table("pets")
            .select("id, owner_id, name, breed, photo_url, status, last_seen_lat, last_seen_lng, last_seen_at")
            .in_("status", ["lost", "home"])  # found nunca aparece en mapa
            .eq("is_active", True)
            .not_.is_("last_seen_lat", "null")
            .not_.is_("last_seen_lng", "null")
            .execute()
        )

        if response.data is None:
            raise ChowTrackException(
                status_code=500,
                message="Error al consultar mascotas",
                detail="supabase_null_response",
            )

        # 2. Filtrar por radio (Haversine) y ventana de 24h para HOME
        now = datetime.now(timezone.utc)
        nearby: list[MapPetSchema] = []

        for pet in response.data:
            pet_lat = pet.get("last_seen_lat")
            pet_lng = pet.get("last_seen_lng")

            if pet_lat is None or pet_lng is None:
                continue

            # Mascotas recuperadas (home): visibles 1h tras la recuperacion.
            # Pasado ese tiempo desaparecen del mapa automaticamente.
            if pet["status"] == "home":
                if not _within_last_hour(pet.get("last_seen_at"), now):
                    continue

            distance = _haversine(lat, lng, float(pet_lat), float(pet_lng))

            if distance <= radius:
                nearby.append(
                    MapPetSchema(
                        id=pet["id"],
                        name=pet["name"],
                        status=pet["status"],
                        photo_url=pet.get("photo_url"),
                        breed=pet.get("breed"),
                        lat=float(pet_lat),
                        lng=float(pet_lng),
                        is_own=(pet["owner_id"] == user_id),
                        last_seen_at=pet.get("last_seen_at"),
                    )
                )

        return nearby

    except ChowTrackException:
        raise
    except Exception as e:
        raise ChowTrackException(
            status_code=500,
            message="Error al obtener mascotas cercanas",
            detail=str(e),
        )