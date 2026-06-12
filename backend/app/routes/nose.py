# app/routes/nose.py
"""
Endpoints de biometría nasal (Plan C: SIFT + Gemini).

  POST /nose/register   → registra la huella nasal de una mascota
  POST /nose/identify   → identifica un perro encontrado contra la BD
"""

import base64
import httpx
# pyrefly: ignore [missing-import]
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.core.errors import ChowTrackException
from app.core.dependencies import get_current_user_id
from app.database.supabase_client import supabase_admin
from app.services import nose_sift, nose_gemini


router = APIRouter(prefix="/nose", tags=["Nose Biometrics"])


# ── Umbrales de decisión ────────────────────────────────────────────────────
MATCH_THRESHOLD = 0.14   # Calibrado con datos reales:
                         # Mismo perro: 0.1655 | Diferente: 0.1141
                         # Umbral 0.14 discrimina correctamente.


# ════════════════════════════════════════════════════════════════════════════
# SCHEMAS
# ════════════════════════════════════════════════════════════════════════════

class NoseRegisterSchema(BaseModel):
    pet_id: str
    image_base64: str = Field(..., description="Imagen JPEG en base64 (sin prefijo data:)")
    photo_index: int = Field(
        0, ge=0, le=2,
        description="Ángulo de la foto: 0=frontal, 1=izquierda, 2=derecha"
    )


class NoseRegisterResponse(BaseModel):
    success: bool
    quality_score: float
    keypoint_count: int
    pattern: str
    features: list[str]
    message: str


class NoseIdentifySchema(BaseModel):
    image_base64: str


class NoseMatchResult(BaseModel):
    match: bool
    pet_id: str | None = None
    pet_name: str | None = None
    score: float = 0.0
    explanation: str = ""
    message: str = ""


# ════════════════════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════════════════════

def _decode_image(image_base64: str) -> bytes:
    """Decodifica base64 → bytes, tolerando prefijo data:."""
    if "," in image_base64:
        image_base64 = image_base64.split(",", 1)[1]
    try:
        return base64.b64decode(image_base64)
    except Exception:
        raise ChowTrackException(400, "Imagen inválida", "invalid_base64")


def _fetch_image_from_url(url: str) -> bytes | None:
    """Descarga una imagen desde una URL (Supabase Storage)."""
    try:
        resp = httpx.get(url, timeout=10.0)
        if resp.status_code == 200:
            return resp.content
    except Exception:
        pass
    return None


# ════════════════════════════════════════════════════════════════════════════
# POST /nose/register
# ════════════════════════════════════════════════════════════════════════════

@router.post(
    "/register",
    response_model=NoseRegisterResponse,
    summary="Registrar huella nasal",
)
async def register_nose(
    payload: NoseRegisterSchema,
    user_id: str = Depends(get_current_user_id),
):
    image_bytes = _decode_image(payload.image_base64)

    # 1. Verificar que la mascota pertenece al usuario
    pet = (
        supabase_admin
        .table("pets")
        .select("id, owner_id")
        .eq("id", payload.pet_id)
        .eq("owner_id", user_id)
        .maybe_single()
        .execute()
    )
    if not pet.data:
        raise ChowTrackException(404, "Mascota no encontrada", "pet_not_found")

    # 2. Validar con Gemini que sea una nariz de perro
    try:
        analysis = nose_gemini.validate_and_describe(image_bytes)
    except RuntimeError as e:
        raise ChowTrackException(500, "Servicio de IA no configurado", str(e))

    if not analysis["is_dog_nose"]:
        raise ChowTrackException(
            422,
            "La imagen no parece ser una nariz de perro. Intenta de nuevo.",
            "not_a_dog_nose",
        )

    # 3. Extraer keypoints + descriptores SIFT
    kp, descriptors, keypoint_count = nose_sift.extract_full(image_bytes)
    if descriptors is None:
        raise ChowTrackException(
            422,
            "La foto no tiene suficiente detalle. Acércate más a la nariz.",
            "insufficient_keypoints",
        )

    # 4. Subir la foto a Storage
    photo_url = None
    try:
        file_path = f"{payload.pet_id}/nose_{payload.photo_index}.jpg"
        supabase_admin.storage.from_("nose-prints").upload(
            file_path,
            image_bytes,
            {"content-type": "image/jpeg", "upsert": "true"},
        )
        photo_url = supabase_admin.storage.from_("nose-prints").get_public_url(file_path)
    except Exception:
        photo_url = f"{payload.pet_id}/nose_{payload.photo_index}.jpg"

    # 5. Guardar keypoints + descriptores (formato nuevo para RANSAC)
    serialized = nose_sift.serialize_features(kp, descriptors)
    record = {
        "pet_id":           payload.pet_id,
        "photo_index":      payload.photo_index,
        "photo_url":        photo_url or "",
        "sift_descriptors": serialized,
        "keypoint_count":   keypoint_count,
        "quality_score":    round(analysis["quality_score"], 3),
        "gemini_analysis":  {
            "pattern":  analysis["pattern"],
            "features": analysis["features"],
            "notes":    analysis["notes"],
        },
        "model_version":    "sift-gemini-v2-ransac",
    }

    try:
        supabase_admin.table("nose_embeddings").upsert(
            record, on_conflict="pet_id,photo_index"
        ).execute()
    except Exception as e:
        raise ChowTrackException(500, "Error al guardar la huella nasal", str(e))

    angle_label = {0: "frontal", 1: "izquierda", 2: "derecha"}.get(payload.photo_index, "")
    registered = supabase_admin.table("nose_embeddings")\
        .select("photo_index").eq("pet_id", payload.pet_id).execute()
    total = len(registered.data) if registered.data else 1

    return NoseRegisterResponse(
        success=True,
        quality_score=analysis["quality_score"],
        keypoint_count=keypoint_count,
        pattern=analysis["pattern"],
        features=analysis["features"],
        message=f"Foto {angle_label} registrada ({total}/3). "
                + ("¡Registro completo!" if total >= 3 else
                   f"Registra {3 - total} ángulo(s) más para mayor precisión."),
    )


# ════════════════════════════════════════════════════════════════════════════
# POST /nose/identify
# ════════════════════════════════════════════════════════════════════════════

@router.post(
    "/identify",
    response_model=NoseMatchResult,
    summary="Identificar perro por huella nasal",
)
async def identify_nose(
    payload: NoseIdentifySchema,
    user_id: str = Depends(get_current_user_id),
):
    image_bytes = _decode_image(payload.image_base64)

    # 1. Validar que sea nariz de perro
    try:
        analysis = nose_gemini.validate_and_describe(image_bytes)
    except RuntimeError as e:
        raise ChowTrackException(500, "Servicio de IA no configurado", str(e))

    if not analysis["is_dog_nose"]:
        return NoseMatchResult(
            match=False,
            message="La imagen no parece ser una nariz de perro.",
        )

    # 2. Extraer keypoints + descriptores de la foto nueva
    kp_query, des_query, kp_count = nose_sift.extract_full(image_bytes)
    if des_query is None:
        return NoseMatchResult(
            match=False,
            message="La foto no tiene suficiente detalle. Acércate más.",
        )

    # 3. Traer todos los registros
    records = (
        supabase_admin
        .table("nose_embeddings")
        .select("pet_id, sift_descriptors, photo_url")
        .not_.is_("sift_descriptors", "null")
        .execute()
    )

    if not records.data:
        return NoseMatchResult(
            match=False,
            message="No hay mascotas registradas con huella nasal aún.",
        )

    # 4. Comparar con verificación geométrica RANSAC
    #    Agrupa por pet_id, toma el mejor score entre los 3 ángulos
    pet_best: dict[str, dict] = {}

    for rec in records.data:
        try:
            kp_train, des_train = nose_sift.deserialize_features(rec["sift_descriptors"])
        except Exception:
            # Registro en formato viejo (solo descriptores) → matching simple
            try:
                des_train = nose_sift.deserialize_descriptors(rec["sift_descriptors"])
                simple = nose_sift.match_descriptors(des_query, des_train)
                pid = rec["pet_id"]
                if pid not in pet_best or simple["score"] > pet_best[pid]["score"]:
                    pet_best[pid] = {"score": simple["score"], "photo_url": rec.get("photo_url")}
            except Exception:
                pass
            continue

        result = nose_sift.match_with_geometry(
            kp_query, des_query, kp_train, des_train
        )
        pid = rec["pet_id"]

        if pid not in pet_best or result["score"] > pet_best[pid]["score"]:
            pet_best[pid] = {
                "score":     result["score"],
                "photo_url": rec.get("photo_url"),
                "inliers":   result.get("inliers", 0),
            }

    if not pet_best:
        return NoseMatchResult(
            match=False,
            message="No hay mascotas registradas con huella nasal aún.",
        )

    # 5. Mejor mascota global
    best_pet_id = max(pet_best, key=lambda k: pet_best[k]["score"])
    best_score = pet_best[best_pet_id]["score"]
    best_photo_url = pet_best[best_pet_id]["photo_url"]

    # 6. Decisión por umbral
    if best_score < MATCH_THRESHOLD:
        return NoseMatchResult(
            match=False,
            score=best_score,
            message="No coincide con ninguna mascota registrada.",
        )

    # 7. Obtener datos de la mascota encontrada
    pet = (
        supabase_admin
        .table("pets")
        .select("id, name")
        .eq("id", best_pet_id)
        .maybe_single()
        .execute()
    )
    pet_name = pet.data.get("name") if pet.data else "Desconocido"

    # 8. Explicación con Gemini
    explanation = "Coincidencia por características nasales."
    if best_photo_url:
        registered_bytes = _fetch_image_from_url(best_photo_url)
        if registered_bytes:
            try:
                explanation = nose_gemini.explain_match(image_bytes, registered_bytes)
            except Exception:
                pass

    return NoseMatchResult(
        match=True,
        pet_id=best_pet_id,
        pet_name=pet_name,
        score=best_score,
        explanation=explanation,
        message="¡Hemos encontrado una coincidencia!",
    )