# app/routes/map.py

# pyrefly: ignore [missing-import]
from fastapi import APIRouter, Depends, Query
from typing import List
from math import radians, cos, sin, asin, sqrt

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
        "radio especificado. El campo `is_own` indica si la mascota pertenece "
        "al usuario autenticado."
    ),
)
async def get_map_pets(
    lat: float = Query(..., ge=-90, le=90, description="Latitud del usuario"),
    lng: float = Query(..., ge=-180, le=180, description="Longitud del usuario"),
    radius: int = Query(5000, ge=100, le=50_000, description="Radio en metros"),
    user_id: str = Depends(get_current_user_id),
):
    try:
        # 1. Obtener todas las mascotas activas con coordenadas conocidas
        #    Solo status LOST o FOUND son relevantes para el mapa público
        response = (
            supabase_admin
            .table("pets")
            .select("id, owner_id, name, breed, photo_url, status, last_seen_lat, last_seen_lng")
            .in_("status", ["lost", "found"])
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

        # 2. Filtrar por radio usando Haversine
        nearby: list[MapPetSchema] = []

        for pet in response.data:
            pet_lat = pet.get("last_seen_lat")
            pet_lng = pet.get("last_seen_lng")

            if pet_lat is None or pet_lng is None:
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