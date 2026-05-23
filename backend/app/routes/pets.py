# pyrefly: ignore [missing-import]
from fastapi import APIRouter, Depends, status
from typing import List

from app.core.schemas import PetCreateSchema, PetResponseSchema
from app.core.errors import ChowTrackException
from app.core.dependencies import get_current_user_id
from app.database.supabase_client import supabase_admin


router = APIRouter(prefix="/pets", tags=["Pets"])

@router.post(
    "/",
    response_model=PetResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar mascota",
    description="Crea el perfil de una mascota al completar el wizard. "
                "La foto debe subirse a Supabase Storage antes de llamar este endpoint.",
)
async def create_pet(
    pet_data: PetCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    try:
        # Construir payload con owner_id del JWT 
        insert_payload = {
            "owner_id": user_id,
            "name":     pet_data.name,
            "breed":    pet_data.breed,
            "age_years": pet_data.age_years,
            "photo_url": pet_data.photo_url,
            "notes":    pet_data.notes,
            "status":   "home",
        }

        # Insertar en tabla pets
        response = (
            supabase_admin
            .table("pets")
            .insert(insert_payload)
            .execute()
        )

        if not response.data:
            raise ChowTrackException(
                status_code=500,
                message="No se pudo registrar la mascota",
                detail="supabase_insert_empty_response",
            )

        pet = response.data[0]

        # Actualizar teléfono en profiles si viene del Step 4 
        if pet_data.phone:
            phone_response = (
                supabase_admin
                .table("profiles")
                .update({"phone": pet_data.phone})
                .eq("id", user_id)
                .execute()
            )

            if not phone_response.data:
                print(
                    f"[WARN] No se pudo actualizar teléfono para user_id={user_id}"
                )

        return PetResponseSchema(**pet)

    except ChowTrackException:
        raise
    except Exception as e:
        raise ChowTrackException(
            status_code=500,
            message="Error al registrar la mascota",
            detail=str(e),
        )

@router.get(
    "/",
    response_model=List[PetResponseSchema],
    summary="Mis mascotas",
    description="Devuelve todas las mascotas del usuario, "
                "ordenadas por fecha de registro (más reciente primero).",
)
async def get_my_pets(
    user_id: str = Depends(get_current_user_id),
):
    try:
        response = (
            supabase_admin
            .table("pets")
            .select("*")
            .eq("owner_id", user_id)
            .eq("is_active", True)
            .order("created_at", desc=True)
            .execute()
        )

        if response.data is None:
            raise ChowTrackException(
                status_code=500,
                message="Error al obtener las mascotas",
                detail="supabase_select_null_response",
            )

        return [PetResponseSchema(**pet) for pet in response.data]

    except ChowTrackException:
        raise
    except Exception as e:
        raise ChowTrackException(
            status_code=500,
            message="Error al obtener las mascotas",
            detail=str(e),
        )

@router.get(
    "/{pet_id}",
    response_model=PetResponseSchema,
    summary="Detalle de mascota",
    description="Retorna el detalle de una mascota específica. "
                "Solo el dueño puede consultar sus propias mascotas.",
)
async def get_pet(
    pet_id: str,
    user_id: str = Depends(get_current_user_id),
):
    try:
        response = (
            supabase_admin
            .table("pets")
            .select("*")
            .eq("id", pet_id)
            .eq("owner_id", user_id)   
            .eq("is_active", True)
            .maybe_single()           
            .execute()
        )

        if not response.data:
            raise ChowTrackException(
                status_code=404,
                message="Mascota no encontrada",
                detail="pet_not_found_or_unauthorized",
            )

        return PetResponseSchema(**response.data)

    except ChowTrackException:
        raise
    except Exception as e:
        raise ChowTrackException(
            status_code=500,
            message="Error al obtener la mascota",
            detail=str(e),
        )