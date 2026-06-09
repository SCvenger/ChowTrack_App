# app/routes/pets.py — AÑADIR al final del archivo existente

# pyrefly: ignore [missing-import]
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, status
from typing import List

from app.core.schemas import (
    PetCreateSchema,
    PetResponseSchema,
    PetStatusUpdateSchema,
)
from app.core.errors import ChowTrackException
from app.core.dependencies import get_current_user_id
from app.database.supabase_client import supabase_admin


router = APIRouter(prefix="/pets", tags=["Pets"])


# ══════════════════════════════════════════════════════════
# POST /pets/  (sin cambios)
# ══════════════════════════════════════════════════════════

@router.post(
    "/",
    response_model=PetResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar mascota",
)
async def create_pet(
    pet_data: PetCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    try:
        insert_payload = {
            "owner_id":  user_id,
            "name":      pet_data.name,
            "breed":     pet_data.breed,
            "age_years": pet_data.age_years,
            "photo_url": pet_data.photo_url,
            "notes":     pet_data.notes,
            "status":    "home",
        }

        response = (
            supabase_admin.table("pets").insert(insert_payload).execute()
        )

        if not response.data:
            raise ChowTrackException(500, "No se pudo registrar la mascota", "supabase_insert_empty")

        pet = response.data[0]

        if pet_data.phone:
            supabase_admin.table("profiles").update({"phone": pet_data.phone}).eq("id", user_id).execute()

        return PetResponseSchema(**pet)

    except ChowTrackException:
        raise
    except Exception as e:
        raise ChowTrackException(500, "Error al registrar la mascota", str(e))


# ══════════════════════════════════════════════════════════
# GET /pets/  (sin cambios)
# ══════════════════════════════════════════════════════════

@router.get("/", response_model=List[PetResponseSchema], summary="Mis mascotas")
async def get_my_pets(user_id: str = Depends(get_current_user_id)):
    try:
        response = (
            supabase_admin
            .table("my_pets")          # usa la vista actualizada con has_nose_scan
            .select("*")
            .eq("owner_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )

        if response.data is None:
            raise ChowTrackException(500, "Error al obtener las mascotas", "supabase_null")

        return [PetResponseSchema(**pet) for pet in response.data]

    except ChowTrackException:
        raise
    except Exception as e:
        raise ChowTrackException(500, "Error al obtener las mascotas", str(e))


# ══════════════════════════════════════════════════════════
# GET /pets/{pet_id}  (sin cambios)
# ══════════════════════════════════════════════════════════

@router.get("/{pet_id}", response_model=PetResponseSchema, summary="Detalle de mascota")
async def get_pet(pet_id: str, user_id: str = Depends(get_current_user_id)):
    try:
        response = (
            supabase_admin
            .table("my_pets")
            .select("*")
            .eq("id", pet_id)
            .eq("owner_id", user_id)
            .maybe_single()
            .execute()
        )

        if not response.data:
            raise ChowTrackException(404, "Mascota no encontrada", "pet_not_found")

        return PetResponseSchema(**response.data)

    except ChowTrackException:
        raise
    except Exception as e:
        raise ChowTrackException(500, "Error al obtener la mascota", str(e))


# ══════════════════════════════════════════════════════════
# PATCH /pets/{pet_id}/status  ← NUEVO
# Cambia estado y guarda coordenadas cuando status == 'lost'
# ══════════════════════════════════════════════════════════

@router.patch(
    "/{pet_id}/status",
    response_model=PetResponseSchema,
    summary="Actualizar estado de mascota",
    description=(
        "Cambia el status (home | lost | found). "
        "Cuando status == 'lost', guarda last_seen_lat/lng/at "
        "para que la mascota aparezca en el mapa de otros usuarios."
    ),
)
async def update_pet_status(
    pet_id: str,
    payload: PetStatusUpdateSchema,
    user_id: str = Depends(get_current_user_id),
):
    try:
        # 1. Verificar que la mascota pertenece al usuario
        existing = (
            supabase_admin
            .table("pets")
            .select("id")
            .eq("id", pet_id)
            .eq("owner_id", user_id)
            .eq("is_active", True)
            .maybe_single()
            .execute()
        )

        if not existing.data:
            raise ChowTrackException(404, "Mascota no encontrada", "pet_not_found")

        # 2. Construir payload de actualización
        update_data: dict = {"status": payload.status}

        if payload.status == "lost" and payload.last_seen_lat is not None:
            update_data.update({
                "last_seen_lat": payload.last_seen_lat,
                "last_seen_lng": payload.last_seen_lng,
                "last_seen_at":  datetime.now(timezone.utc).isoformat(),
            })

        if payload.notes is not None:
            update_data["notes"] = payload.notes

        # 3. Actualizar
        supabase_admin.table("pets").update(update_data).eq("id", pet_id).execute()

        # 4. Devolver mascota actualizada desde la vista
        updated = (
            supabase_admin
            .table("my_pets")
            .select("*")
            .eq("id", pet_id)
            .single()
            .execute()
        )

        return PetResponseSchema(**updated.data)

    except ChowTrackException:
        raise
    except Exception as e:
        raise ChowTrackException(500, "Error al actualizar el estado", str(e))