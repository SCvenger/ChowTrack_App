# app/routes/health.py
"""
Módulo Salud / Carnet veterinario (lado del dueño).

  /pets/{pet_id}/health/...      → ficha, cartilla e historial (Bearer)
  /health/reminders              → recordatorios de todas mis mascotas (Bearer)
  /health/shared/{token}[/carnet] → carnet de solo lectura para el veterinario
                                    (público, protegido por token temporal)
"""

import base64
import binascii
import secrets
from datetime import datetime, timedelta, timezone
from functools import wraps
from typing import List, Optional
from uuid import UUID, uuid4

# pyrefly: ignore [missing-import]
from fastapi import APIRouter, Depends, Query, Response, status
from fastapi.responses import HTMLResponse

from app.core.config import settings
from app.core.errors import ChowTrackException
from app.core.dependencies import get_current_user_id
from app.core.health_schemas import (
    APPOINTMENT_STATUS_PATTERN,
    AppointmentCreateSchema,
    AppointmentResponseSchema,
    AppointmentUpdateSchema,
    DewormingCreateSchema,
    DewormingResponseSchema,
    DewormingUpdateSchema,
    HealthCardSchema,
    HealthCountsSchema,
    HealthDocumentCreateSchema,
    HealthDocumentResponseSchema,
    HealthDocumentUpdateSchema,
    HealthProfileResponseSchema,
    HealthProfileUpsertSchema,
    HealthReminderSchema,
    HealthShareCreateSchema,
    HealthShareResponseSchema,
    HealthSummarySchema,
    MedicationCreateSchema,
    MedicationResponseSchema,
    MedicationUpdateSchema,
    SharedPetSchema,
    VaccinationCreateSchema,
    VaccinationResponseSchema,
    VaccinationUpdateSchema,
    VetVisitCreateSchema,
    VetVisitResponseSchema,
    VetVisitUpdateSchema,
    WeightLogCreateSchema,
    WeightLogResponseSchema,
    WeightLogUpdateSchema,
)
from app.database.supabase_client import supabase_admin
from app.services import health_logic as hl
from app.services.health_carnet import render_carnet_html


router = APIRouter(prefix="/pets/{pet_id}/health", tags=["Health"])
public_router = APIRouter(prefix="/health", tags=["Health"])


# ── Tablas / Storage ────────────────────────────────────────────────────────
T_PROFILE = "pet_health_profiles"
T_VACCINATIONS = "pet_vaccinations"
T_DEWORMINGS = "pet_dewormings"
T_VISITS = "pet_vet_visits"
T_MEDICATIONS = "pet_medications"
T_WEIGHTS = "pet_weight_logs"
T_APPOINTMENTS = "pet_vet_appointments"
T_DOCUMENTS = "pet_health_documents"
T_SHARES = "pet_health_shares"

HEALTH_BUCKET = "pet-health"          # bucket privado → URLs firmadas
SIGNED_URL_SECONDS = 3600
RECENT_VISITS_IN_CARD = 10


# ════════════════════════════════════════════════════════════════════════════
# HELPERS
# ════════════════════════════════════════════════════════════════════════════

def _guard(message: str):
    """Mismo patrón try/except de pets.py: errores no controlados → 500 con mensaje amigable."""
    def decorator(fn):
        @wraps(fn)
        async def wrapper(*args, **kwargs):
            try:
                return await fn(*args, **kwargs)
            except ChowTrackException:
                raise
            except Exception as e:
                raise ChowTrackException(500, message, str(e))
        return wrapper
    return decorator


def _is_uuid(value: Optional[str]) -> bool:
    try:
        UUID(str(value))
        return True
    except (ValueError, TypeError):
        return False


def _first(response) -> Optional[dict]:
    if response is None or not response.data:
        return None
    data = response.data
    return data[0] if isinstance(data, list) else data


def _db_error(e: Exception, message: str) -> ChowTrackException:
    """Traduce errores de Postgres (CHECK, NOT NULL, FK, UNIQUE) a respuestas 4xx."""
    text = str(e)
    if any(code in text for code in ("23514", "23502", "22007", "22008", "22P02", "22003")):
        return ChowTrackException(422, "Algún dato no es válido. Revisa el formulario.", text)
    if "23503" in text:
        return ChowTrackException(422, "El registro relacionado no existe.", text)
    if "23505" in text:
        return ChowTrackException(409, "El registro ya existe.", text)
    return ChowTrackException(500, message, text)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _get_owned_pet(pet_id: str, user_id: str) -> dict:
    if not _is_uuid(pet_id):
        raise ChowTrackException(404, "Mascota no encontrada", "pet_not_found")
    pet = _first(
        supabase_admin
        .table("pets")
        .select("id, name, breed, age_years, photo_url")
        .eq("id", pet_id)
        .eq("owner_id", user_id)
        .eq("is_active", True)
        .limit(1)
        .execute()
    )
    if not pet:
        raise ChowTrackException(404, "Mascota no encontrada", "pet_not_found")
    return pet


def _list_rows(table: str, pet_id: str, order_col: str, desc: bool = True, limit: Optional[int] = None) -> list[dict]:
    query = supabase_admin.table(table).select("*").eq("pet_id", pet_id).order(order_col, desc=desc)
    if limit:
        query = query.limit(limit)
    return query.execute().data or []


def _insert_row(table: str, pet_id: str, data: dict) -> dict:
    try:
        response = supabase_admin.table(table).insert({**data, "pet_id": pet_id}).execute()
    except Exception as e:
        raise _db_error(e, "No se pudo guardar el registro")
    if not response.data:
        raise ChowTrackException(500, "No se pudo guardar el registro", "supabase_insert_empty")
    return response.data[0]


def _update_row(table: str, pet_id: str, record_id: str, data: dict) -> dict:
    if not _is_uuid(record_id):
        raise ChowTrackException(404, "Registro no encontrado", "record_not_found")
    if not data:
        raise ChowTrackException(400, "No hay cambios para guardar", "empty_update")
    try:
        response = (
            supabase_admin.table(table).update(data)
            .eq("id", record_id).eq("pet_id", pet_id).execute()
        )
    except Exception as e:
        raise _db_error(e, "No se pudo actualizar el registro")
    if not response.data:
        raise ChowTrackException(404, "Registro no encontrado", "record_not_found")
    return response.data[0]


def _delete_row(table: str, pet_id: str, record_id: str) -> dict:
    if not _is_uuid(record_id):
        raise ChowTrackException(404, "Registro no encontrado", "record_not_found")
    response = (
        supabase_admin.table(table).delete()
        .eq("id", record_id).eq("pet_id", pet_id).execute()
    )
    if not response.data:
        raise ChowTrackException(404, "Registro no encontrado", "record_not_found")
    return response.data[0]


def _pick(rows: list[dict], record_id: str) -> dict:
    for row in rows:
        if row["id"] == record_id:
            return row
    raise ChowTrackException(404, "Registro no encontrado", "record_not_found")


# ── Construcción de respuestas ──────────────────────────────────────────────

def _profile(pet_id: str, today) -> HealthProfileResponseSchema:
    row = _first(supabase_admin.table(T_PROFILE).select("*").eq("pet_id", pet_id).limit(1).execute())
    if not row:
        return HealthProfileResponseSchema(pet_id=pet_id)
    return HealthProfileResponseSchema(
        **row,
        age_months=hl.age_in_months(row.get("birth_date"), today),
        is_registered=True,
    )


def _vaccinations(pet_id: str, today) -> list[dict]:
    return hl.annotate_due(_list_rows(T_VACCINATIONS, pet_id, "applied_at"), hl.vaccine_keys, today)


def _dewormings(pet_id: str, today) -> list[dict]:
    return hl.annotate_due(_list_rows(T_DEWORMINGS, pet_id, "applied_at"), hl.deworming_keys, today)


def _medication(row: dict, today) -> MedicationResponseSchema:
    return MedicationResponseSchema(
        **row, is_active=hl.medication_is_active(row.get("start_date"), row.get("end_date"), today),
    )


def _check_visit(pet_id: str, visit_id: Optional[str]) -> None:
    if visit_id is None:
        return
    exists = _is_uuid(visit_id) and _first(
        supabase_admin.table(T_VISITS).select("id")
        .eq("id", visit_id).eq("pet_id", pet_id).limit(1).execute()
    )
    if not exists:
        raise ChowTrackException(422, "La consulta indicada no existe para esta mascota", "visit_not_found")


def _signed_url(path: str, seconds: int = SIGNED_URL_SECONDS) -> Optional[str]:
    try:
        result = supabase_admin.storage.from_(HEALTH_BUCKET).create_signed_url(path, seconds)
        return result.get("signedURL") or result.get("signedUrl")
    except Exception:
        return None


def _document(row: dict, seconds: int = SIGNED_URL_SECONDS) -> HealthDocumentResponseSchema:
    return HealthDocumentResponseSchema(**row, url=_signed_url(row["file_path"], seconds))


def _decode_file(file_base64: str) -> bytes:
    if "," in file_base64[:100]:
        file_base64 = file_base64.split(",", 1)[1]
    file_base64 = "".join(file_base64.split())
    if len(file_base64) * 3 // 4 > hl.MAX_DOCUMENT_BYTES + 3:
        raise ChowTrackException(413, "El archivo supera el máximo de 5 MB", "file_too_large")
    try:
        return base64.b64decode(file_base64, validate=True)
    except (binascii.Error, ValueError):
        raise ChowTrackException(400, "Archivo inválido", "invalid_base64")


def _share(row: dict, now: datetime) -> HealthShareResponseSchema:
    expires = hl.parse_datetime(row.get("expires_at"))
    token = row["token"]
    return HealthShareResponseSchema(
        **row,
        share_url=f"{settings.PUBLIC_BASE_URL}/health/shared/{token}",
        carnet_url=f"{settings.PUBLIC_BASE_URL}/health/shared/{token}/carnet",
        is_active=row.get("revoked_at") is None and expires is not None and expires > now,
    )


def _build_card(pet: dict, now: datetime, expires_at: Optional[str] = None) -> HealthCardSchema:
    today = hl.today_bolivia(now)
    vaccinations = _vaccinations(pet["id"], today)
    dewormings = _dewormings(pet["id"], today)
    medications = [_medication(m, today) for m in _list_rows(T_MEDICATIONS, pet["id"], "start_date")]
    weights = _list_rows(T_WEIGHTS, pet["id"], "measured_at", limit=1)

    # Los documentos del carnet compartido no deben sobrevivir al enlace
    doc_seconds = SIGNED_URL_SECONDS
    if expires_at:
        expires = hl.parse_datetime(expires_at)
        if expires:
            doc_seconds = max(60, min(SIGNED_URL_SECONDS, int((expires - now).total_seconds())))

    return HealthCardSchema(
        pet=SharedPetSchema(**pet),
        profile=_profile(pet["id"], today),
        vaccination_status=hl.overall_status(vaccinations),
        deworming_status=hl.overall_status(dewormings),
        latest_weight=WeightLogResponseSchema(**weights[0]) if weights else None,
        vaccinations=[VaccinationResponseSchema(**v) for v in vaccinations],
        dewormings=[DewormingResponseSchema(**d) for d in dewormings],
        active_medications=[m for m in medications if m.is_active],
        recent_visits=[
            VetVisitResponseSchema(**v)
            for v in _list_rows(T_VISITS, pet["id"], "visit_date", limit=RECENT_VISITS_IN_CARD)
        ],
        documents=[_document(d, doc_seconds) for d in _list_rows(T_DOCUMENTS, pet["id"], "created_at")],
        generated_at=now.isoformat(),
        expires_at=expires_at,
    )


def _no_content() -> Response:
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ════════════════════════════════════════════════════════════════════════════
# RESUMEN Y CARNET
# ════════════════════════════════════════════════════════════════════════════

@router.get("", response_model=HealthSummarySchema, summary="Resumen de salud de la mascota")
@_guard("Error al obtener el resumen de salud")
async def get_health_summary(pet_id: str, user_id: str = Depends(get_current_user_id)):
    pet = _get_owned_pet(pet_id, user_id)
    now = _now()
    today = hl.today_bolivia(now)

    vaccinations = _vaccinations(pet_id, today)
    dewormings = _dewormings(pet_id, today)
    appointments = _list_rows(T_APPOINTMENTS, pet_id, "scheduled_at", desc=False)
    medications = [_medication(m, today) for m in _list_rows(T_MEDICATIONS, pet_id, "start_date")]
    weights = _list_rows(T_WEIGHTS, pet_id, "measured_at", limit=1)
    visits = supabase_admin.table(T_VISITS).select("id").eq("pet_id", pet_id).execute().data or []
    documents = supabase_admin.table(T_DOCUMENTS).select("id").eq("pet_id", pet_id).execute().data or []
    active = [m for m in medications if m.is_active]
    upcoming = hl.next_appointment(appointments, now)

    return HealthSummarySchema(
        pet_id=pet["id"],
        pet_name=pet["name"],
        photo_url=pet.get("photo_url"),
        profile=_profile(pet_id, today),
        vaccination_status=hl.overall_status(vaccinations),
        deworming_status=hl.overall_status(dewormings),
        latest_weight=WeightLogResponseSchema(**weights[0]) if weights else None,
        next_appointment=AppointmentResponseSchema(**upcoming) if upcoming else None,
        active_medications=active,
        reminders=[
            HealthReminderSchema(**r)
            for r in hl.build_reminders(pet, vaccinations, dewormings, appointments, now)
        ],
        counts=HealthCountsSchema(
            vaccinations=len(vaccinations),
            dewormings=len(dewormings),
            visits=len(visits),
            medications_active=len(active),
            documents=len(documents),
        ),
    )


@router.get("/card", response_model=HealthCardSchema, summary="Carnet completo (vista previa del dueño)")
@_guard("Error al generar el carnet")
async def get_health_card(pet_id: str, user_id: str = Depends(get_current_user_id)):
    pet = _get_owned_pet(pet_id, user_id)
    return _build_card(pet, _now())


# ════════════════════════════════════════════════════════════════════════════
# PERFIL DE SALUD
# ════════════════════════════════════════════════════════════════════════════

@router.get("/profile", response_model=HealthProfileResponseSchema, summary="Ficha de salud")
@_guard("Error al obtener la ficha de salud")
async def get_health_profile(pet_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    return _profile(pet_id, hl.today_bolivia())


@router.put("/profile", response_model=HealthProfileResponseSchema, summary="Crear/reemplazar ficha de salud")
@_guard("Error al guardar la ficha de salud")
async def upsert_health_profile(
    pet_id: str,
    payload: HealthProfileUpsertSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    try:
        supabase_admin.table(T_PROFILE).upsert(
            {**payload.model_dump(mode="json"), "pet_id": pet_id}, on_conflict="pet_id"
        ).execute()
    except Exception as e:
        raise _db_error(e, "Error al guardar la ficha de salud")
    return _profile(pet_id, hl.today_bolivia())


# ════════════════════════════════════════════════════════════════════════════
# CARTILLA DE VACUNACIÓN
# ════════════════════════════════════════════════════════════════════════════

@router.get("/vaccinations", response_model=List[VaccinationResponseSchema], summary="Cartilla de vacunación")
@_guard("Error al obtener las vacunas")
async def list_vaccinations(pet_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    return [VaccinationResponseSchema(**v) for v in _vaccinations(pet_id, hl.today_bolivia())]


@router.post(
    "/vaccinations",
    response_model=VaccinationResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar vacuna",
)
@_guard("Error al registrar la vacuna")
async def create_vaccination(
    pet_id: str,
    payload: VaccinationCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    row = _insert_row(T_VACCINATIONS, pet_id, payload.model_dump(mode="json"))
    return VaccinationResponseSchema(**_pick(_vaccinations(pet_id, hl.today_bolivia()), row["id"]))


@router.patch("/vaccinations/{record_id}", response_model=VaccinationResponseSchema, summary="Editar vacuna")
@_guard("Error al actualizar la vacuna")
async def update_vaccination(
    pet_id: str,
    record_id: str,
    payload: VaccinationUpdateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    _update_row(T_VACCINATIONS, pet_id, record_id, payload.model_dump(mode="json", exclude_unset=True))
    return VaccinationResponseSchema(**_pick(_vaccinations(pet_id, hl.today_bolivia()), record_id))


@router.delete("/vaccinations/{record_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar vacuna")
@_guard("Error al eliminar la vacuna")
async def delete_vaccination(pet_id: str, record_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    _delete_row(T_VACCINATIONS, pet_id, record_id)
    return _no_content()


# ════════════════════════════════════════════════════════════════════════════
# DESPARASITACIONES
# ════════════════════════════════════════════════════════════════════════════

@router.get("/dewormings", response_model=List[DewormingResponseSchema], summary="Desparasitaciones")
@_guard("Error al obtener las desparasitaciones")
async def list_dewormings(pet_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    return [DewormingResponseSchema(**d) for d in _dewormings(pet_id, hl.today_bolivia())]


@router.post(
    "/dewormings",
    response_model=DewormingResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar desparasitación",
)
@_guard("Error al registrar la desparasitación")
async def create_deworming(
    pet_id: str,
    payload: DewormingCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    row = _insert_row(T_DEWORMINGS, pet_id, payload.model_dump(mode="json"))
    return DewormingResponseSchema(**_pick(_dewormings(pet_id, hl.today_bolivia()), row["id"]))


@router.patch("/dewormings/{record_id}", response_model=DewormingResponseSchema, summary="Editar desparasitación")
@_guard("Error al actualizar la desparasitación")
async def update_deworming(
    pet_id: str,
    record_id: str,
    payload: DewormingUpdateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    _update_row(T_DEWORMINGS, pet_id, record_id, payload.model_dump(mode="json", exclude_unset=True))
    return DewormingResponseSchema(**_pick(_dewormings(pet_id, hl.today_bolivia()), record_id))


@router.delete("/dewormings/{record_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar desparasitación")
@_guard("Error al eliminar la desparasitación")
async def delete_deworming(pet_id: str, record_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    _delete_row(T_DEWORMINGS, pet_id, record_id)
    return _no_content()


# ════════════════════════════════════════════════════════════════════════════
# HISTORIAL CLÍNICO (CONSULTAS)
# ════════════════════════════════════════════════════════════════════════════

@router.get("/visits", response_model=List[VetVisitResponseSchema], summary="Historial de consultas")
@_guard("Error al obtener el historial clínico")
async def list_visits(pet_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    return [VetVisitResponseSchema(**v) for v in _list_rows(T_VISITS, pet_id, "visit_date")]


@router.post(
    "/visits",
    response_model=VetVisitResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar consulta",
)
@_guard("Error al registrar la consulta")
async def create_visit(
    pet_id: str,
    payload: VetVisitCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    return VetVisitResponseSchema(**_insert_row(T_VISITS, pet_id, payload.model_dump(mode="json")))


@router.patch("/visits/{record_id}", response_model=VetVisitResponseSchema, summary="Editar consulta")
@_guard("Error al actualizar la consulta")
async def update_visit(
    pet_id: str,
    record_id: str,
    payload: VetVisitUpdateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    row = _update_row(T_VISITS, pet_id, record_id, payload.model_dump(mode="json", exclude_unset=True))
    return VetVisitResponseSchema(**row)


@router.delete("/visits/{record_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar consulta")
@_guard("Error al eliminar la consulta")
async def delete_visit(pet_id: str, record_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    _delete_row(T_VISITS, pet_id, record_id)  # medicamentos vinculados quedan con visit_id = NULL
    return _no_content()


# ════════════════════════════════════════════════════════════════════════════
# MEDICAMENTOS / TRATAMIENTOS
# ════════════════════════════════════════════════════════════════════════════

@router.get("/medications", response_model=List[MedicationResponseSchema], summary="Medicamentos")
@_guard("Error al obtener los medicamentos")
async def list_medications(
    pet_id: str,
    active_only: bool = Query(False, description="Solo tratamientos en curso"),
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    today = hl.today_bolivia()
    items = [_medication(m, today) for m in _list_rows(T_MEDICATIONS, pet_id, "start_date")]
    return [m for m in items if m.is_active] if active_only else items


@router.post(
    "/medications",
    response_model=MedicationResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar medicamento",
)
@_guard("Error al registrar el medicamento")
async def create_medication(
    pet_id: str,
    payload: MedicationCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    _check_visit(pet_id, payload.visit_id)
    row = _insert_row(T_MEDICATIONS, pet_id, payload.model_dump(mode="json"))
    return _medication(row, hl.today_bolivia())


@router.patch("/medications/{record_id}", response_model=MedicationResponseSchema, summary="Editar medicamento")
@_guard("Error al actualizar el medicamento")
async def update_medication(
    pet_id: str,
    record_id: str,
    payload: MedicationUpdateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    _check_visit(pet_id, payload.visit_id)
    row = _update_row(T_MEDICATIONS, pet_id, record_id, payload.model_dump(mode="json", exclude_unset=True))
    return _medication(row, hl.today_bolivia())


@router.delete("/medications/{record_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar medicamento")
@_guard("Error al eliminar el medicamento")
async def delete_medication(pet_id: str, record_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    _delete_row(T_MEDICATIONS, pet_id, record_id)
    return _no_content()


# ════════════════════════════════════════════════════════════════════════════
# CONTROL DE PESO
# ════════════════════════════════════════════════════════════════════════════

@router.get("/weights", response_model=List[WeightLogResponseSchema], summary="Historial de peso")
@_guard("Error al obtener el historial de peso")
async def list_weights(pet_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    return [WeightLogResponseSchema(**w) for w in _list_rows(T_WEIGHTS, pet_id, "measured_at")]


@router.post(
    "/weights",
    response_model=WeightLogResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar peso",
)
@_guard("Error al registrar el peso")
async def create_weight(
    pet_id: str,
    payload: WeightLogCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    return WeightLogResponseSchema(**_insert_row(T_WEIGHTS, pet_id, payload.model_dump(mode="json")))


@router.patch("/weights/{record_id}", response_model=WeightLogResponseSchema, summary="Editar peso")
@_guard("Error al actualizar el peso")
async def update_weight(
    pet_id: str,
    record_id: str,
    payload: WeightLogUpdateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    row = _update_row(T_WEIGHTS, pet_id, record_id, payload.model_dump(mode="json", exclude_unset=True))
    return WeightLogResponseSchema(**row)


@router.delete("/weights/{record_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar peso")
@_guard("Error al eliminar el registro de peso")
async def delete_weight(pet_id: str, record_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    _delete_row(T_WEIGHTS, pet_id, record_id)
    return _no_content()


# ════════════════════════════════════════════════════════════════════════════
# CITAS VETERINARIAS
# ════════════════════════════════════════════════════════════════════════════

@router.get("/appointments", response_model=List[AppointmentResponseSchema], summary="Citas veterinarias")
@_guard("Error al obtener las citas")
async def list_appointments(
    pet_id: str,
    status_filter: Optional[str] = Query(None, alias="status", pattern=APPOINTMENT_STATUS_PATTERN),
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    rows = _list_rows(T_APPOINTMENTS, pet_id, "scheduled_at", desc=False)
    if status_filter:
        rows = [r for r in rows if r.get("status") == status_filter]
    return [AppointmentResponseSchema(**r) for r in rows]


@router.post(
    "/appointments",
    response_model=AppointmentResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Agendar cita",
)
@_guard("Error al agendar la cita")
async def create_appointment(
    pet_id: str,
    payload: AppointmentCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    return AppointmentResponseSchema(**_insert_row(T_APPOINTMENTS, pet_id, payload.model_dump(mode="json")))


@router.patch(
    "/appointments/{record_id}",
    response_model=AppointmentResponseSchema,
    summary="Editar / completar / cancelar cita",
)
@_guard("Error al actualizar la cita")
async def update_appointment(
    pet_id: str,
    record_id: str,
    payload: AppointmentUpdateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    row = _update_row(T_APPOINTMENTS, pet_id, record_id, payload.model_dump(mode="json", exclude_unset=True))
    return AppointmentResponseSchema(**row)


@router.delete("/appointments/{record_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar cita")
@_guard("Error al eliminar la cita")
async def delete_appointment(pet_id: str, record_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    _delete_row(T_APPOINTMENTS, pet_id, record_id)
    return _no_content()


# ════════════════════════════════════════════════════════════════════════════
# DOCUMENTOS CLÍNICOS
# ════════════════════════════════════════════════════════════════════════════

@router.get("/documents", response_model=List[HealthDocumentResponseSchema], summary="Documentos clínicos")
@_guard("Error al obtener los documentos")
async def list_documents(pet_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    return [_document(d) for d in _list_rows(T_DOCUMENTS, pet_id, "created_at")]


@router.post(
    "/documents",
    response_model=HealthDocumentResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Subir documento (JPG, PNG o PDF · máx 5 MB)",
)
@_guard("Error al subir el documento")
async def create_document(
    pet_id: str,
    payload: HealthDocumentCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)

    raw = _decode_file(payload.file_base64)
    if not raw:
        raise ChowTrackException(400, "Archivo vacío", "empty_file")
    if len(raw) > hl.MAX_DOCUMENT_BYTES:
        raise ChowTrackException(413, "El archivo supera el máximo de 5 MB", "file_too_large")
    file_type = hl.detect_file_type(raw)
    if not file_type:
        raise ChowTrackException(415, "Formato no permitido. Usa JPG, PNG o PDF.", "unsupported_file_type")
    mime_type, extension = file_type

    file_path = f"{pet_id}/{uuid4().hex}.{extension}"
    bucket = supabase_admin.storage.from_(HEALTH_BUCKET)
    try:
        bucket.upload(file_path, raw, {"content-type": mime_type, "upsert": "false"})
    except Exception as e:
        raise ChowTrackException(502, "No se pudo subir el archivo", str(e))

    try:
        row = _insert_row(T_DOCUMENTS, pet_id, {
            **payload.model_dump(mode="json", exclude={"file_base64"}),
            "file_path":  file_path,
            "mime_type":  mime_type,
            "size_bytes": len(raw),
        })
    except Exception:
        try:
            bucket.remove([file_path])  # no dejar archivos huérfanos
        except Exception:
            pass
        raise

    return _document(row)


@router.patch("/documents/{record_id}", response_model=HealthDocumentResponseSchema, summary="Editar datos del documento")
@_guard("Error al actualizar el documento")
async def update_document(
    pet_id: str,
    record_id: str,
    payload: HealthDocumentUpdateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    row = _update_row(T_DOCUMENTS, pet_id, record_id, payload.model_dump(mode="json", exclude_unset=True))
    return _document(row)


@router.delete("/documents/{record_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar documento")
@_guard("Error al eliminar el documento")
async def delete_document(pet_id: str, record_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    row = _delete_row(T_DOCUMENTS, pet_id, record_id)
    try:
        supabase_admin.storage.from_(HEALTH_BUCKET).remove([row["file_path"]])
    except Exception:
        pass  # el registro ya no existe; el archivo queda inaccesible (bucket privado)
    return _no_content()


# ════════════════════════════════════════════════════════════════════════════
# COMPARTIR CARNET CON EL VETERINARIO (QR / enlace temporal)
# ════════════════════════════════════════════════════════════════════════════

@router.get("/shares", response_model=List[HealthShareResponseSchema], summary="Enlaces compartidos")
@_guard("Error al obtener los enlaces")
async def list_shares(pet_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    now = _now()
    return [_share(s, now) for s in _list_rows(T_SHARES, pet_id, "created_at", limit=20)]


@router.post(
    "/shares",
    response_model=HealthShareResponseSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Generar enlace temporal del carnet",
    description="Devuelve `carnet_url` para codificar en un QR. El veterinario lo abre sin cuenta.",
)
@_guard("Error al generar el enlace")
async def create_share(
    pet_id: str,
    payload: HealthShareCreateSchema,
    user_id: str = Depends(get_current_user_id),
):
    _get_owned_pet(pet_id, user_id)
    now = _now()
    row = _insert_row(T_SHARES, pet_id, {
        "token":      secrets.token_urlsafe(32),
        "expires_at": (now + timedelta(hours=payload.expires_in_hours)).isoformat(),
    })
    return _share(row, now)


@router.delete("/shares/{share_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Revocar enlace")
@_guard("Error al revocar el enlace")
async def revoke_share(pet_id: str, share_id: str, user_id: str = Depends(get_current_user_id)):
    _get_owned_pet(pet_id, user_id)
    if not _is_uuid(share_id):
        raise ChowTrackException(404, "Enlace no encontrado", "share_not_found")
    share = _first(
        supabase_admin.table(T_SHARES).select("id, revoked_at")
        .eq("id", share_id).eq("pet_id", pet_id).limit(1).execute()
    )
    if not share:
        raise ChowTrackException(404, "Enlace no encontrado", "share_not_found")
    if share.get("revoked_at") is None:
        supabase_admin.table(T_SHARES).update({"revoked_at": _now().isoformat()}).eq("id", share_id).execute()
    return _no_content()


# ════════════════════════════════════════════════════════════════════════════
# /health — RECORDATORIOS (Bearer) Y CARNET PÚBLICO (token)
# ════════════════════════════════════════════════════════════════════════════

@public_router.get(
    "/reminders",
    response_model=List[HealthReminderSchema],
    summary="Recordatorios de todas mis mascotas",
    description="Vacunas/desparasitaciones vencidas o por vencer y citas agendadas dentro de `days` días.",
)
@_guard("Error al obtener los recordatorios")
async def get_reminders(
    days: int = Query(30, ge=1, le=365),
    user_id: str = Depends(get_current_user_id),
):
    pets = (
        supabase_admin.table("pets").select("id, name")
        .eq("owner_id", user_id).eq("is_active", True).execute()
    ).data or []
    if not pets:
        return []

    ids = [p["id"] for p in pets]
    now = _now()
    today = hl.today_bolivia(now)

    def _by_pet(table: str) -> dict[str, list[dict]]:
        grouped: dict[str, list[dict]] = {pid: [] for pid in ids}
        for row in supabase_admin.table(table).select("*").in_("pet_id", ids).execute().data or []:
            grouped.setdefault(row["pet_id"], []).append(row)
        return grouped

    vaccinations = _by_pet(T_VACCINATIONS)
    dewormings = _by_pet(T_DEWORMINGS)
    appointments = _by_pet(T_APPOINTMENTS)

    reminders: list[dict] = []
    for pet in pets:
        reminders += hl.build_reminders(
            pet,
            hl.annotate_due(vaccinations[pet["id"]], hl.vaccine_keys, today),
            hl.annotate_due(dewormings[pet["id"]], hl.deworming_keys, today),
            appointments[pet["id"]],
            now,
            window_days=days,
        )
    reminders.sort(key=lambda r: (r["days_left"], r["due_date"]))
    return [HealthReminderSchema(**r) for r in reminders]


_SHARE_HEADERS = {
    "Cache-Control": "no-store",
    "X-Robots-Tag": "noindex, nofollow",
    "Referrer-Policy": "no-referrer",
}


def _resolve_share(token: str) -> tuple[dict, dict, datetime]:
    """Token válido (no revocado ni expirado) → (share, pet, now). Si no, 404 genérico."""
    not_found = ChowTrackException(404, "Enlace inválido o expirado", "share_not_found")
    if not (24 <= len(token) <= 128):
        raise not_found

    share = _first(supabase_admin.table(T_SHARES).select("*").eq("token", token).limit(1).execute())
    now = _now()
    expires = hl.parse_datetime(share.get("expires_at")) if share else None
    if not share or share.get("revoked_at") is not None or expires is None or expires <= now:
        raise not_found

    pet = _first(
        supabase_admin.table("pets").select("id, name, breed, age_years, photo_url")
        .eq("id", share["pet_id"]).eq("is_active", True).limit(1).execute()
    )
    if not pet:
        raise not_found

    try:
        supabase_admin.table(T_SHARES).update({"last_accessed_at": now.isoformat()}).eq("id", share["id"]).execute()
    except Exception:
        pass
    return share, pet, now


@public_router.get(
    "/shared/{token}",
    response_model=HealthCardSchema,
    summary="Carnet compartido (JSON, público)",
)
@_guard("Error al obtener el carnet")
async def get_shared_card(token: str, response: Response):
    share, pet, now = _resolve_share(token)
    response.headers.update(_SHARE_HEADERS)
    return _build_card(pet, now, expires_at=share["expires_at"])


@public_router.get(
    "/shared/{token}/carnet",
    response_class=HTMLResponse,
    summary="Carnet compartido (HTML imprimible, público)",
)
async def get_shared_card_html(token: str):
    try:
        share, pet, now = _resolve_share(token)
        html = render_carnet_html(_build_card(pet, now, expires_at=share["expires_at"]))
        return HTMLResponse(html, headers=_SHARE_HEADERS)
    except ChowTrackException as e:
        code, message = e.status_code, e.message
    except Exception:
        code, message = 500, "No se pudo generar el carnet. Intenta nuevamente."
    return HTMLResponse(
        "<!doctype html><html lang='es'><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width, initial-scale=1'><title>ChowTrack</title></head>"
        "<body style='font-family:system-ui;text-align:center;padding:48px 16px;color:#737784'>"
        f"<h1 style='color:#0047AB'>ChowTrack</h1><p>{message}</p></body></html>",
        status_code=code,
        headers=_SHARE_HEADERS,
    )
