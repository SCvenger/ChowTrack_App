# app/core/health_schemas.py
"""
Schemas del módulo Salud / Carnet veterinario (lado del dueño).

Convenciones (mismas que app/core/schemas.py):
  - Enums como `str` + `Field(pattern=...)`.
  - Entradas de fecha tipadas (`date` / `datetime`) para validarlas;
    las respuestas devuelven fechas como `str` ISO, tal como llegan de Supabase.
  - *CreateSchema → POST, *UpdateSchema → PATCH (todos los campos opcionales).
"""

# pyrefly: ignore [missing-import]
from pydantic import AfterValidator, BaseModel, Field, field_validator, model_validator
from datetime import date, datetime
from typing import Annotated, ClassVar, Optional

from app.services.health_logic import ensure_aware, today_bolivia


# ── Patrones compartidos ────────────────────────────────────────────────────
SEX_PATTERN = "^(male|female|unknown)$"
VACCINE_TYPE_PATTERN = "^(rabies|polyvalent|leptospirosis|bordetella|other)$"
DEWORMING_TYPE_PATTERN = "^(internal|external|both)$"
APPOINTMENT_STATUS_PATTERN = "^(scheduled|completed|cancelled)$"
DOC_TYPE_PATTERN = "^(vaccine_certificate|lab_result|xray|prescription|other)$"
VET_PHONE_PATTERN = r"^\+?\d[\d\s-]{6,19}$"

# Estado de vencimiento de un registro (vacuna / desparasitación)
#   up_to_date | due_soon | overdue | no_due_date | superseded
# Estado global de la cartilla
#   up_to_date | due_soon | overdue | no_records


def _not_future(value: date) -> date:
    if value > today_bolivia():
        raise ValueError("La fecha no puede estar en el futuro")
    return value


# Fecha que no puede ser posterior a "hoy" en Bolivia (aplicación, consulta, pesaje...)
PastDate = Annotated[date, AfterValidator(_not_future)]


class _PartialUpdate(BaseModel):
    """
    Base para PATCH: un campo NOT NULL en BD no puede enviarse como null.
    Las subclases declaran cuáles en `_non_nullable`.
    """
    _non_nullable: ClassVar[tuple[str, ...]] = ()

    @model_validator(mode="after")
    def _check_non_nullable(self):
        for name in self._non_nullable:
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError(f"'{name}' no puede ser null")
        return self


# ══════════════════════════════════════════════════════════
# PERFIL DE SALUD (1:1 con la mascota)
# ══════════════════════════════════════════════════════════

class HealthProfileUpsertSchema(BaseModel):
    """PUT: reemplaza la ficha completa."""
    sex: str = Field("unknown", pattern=SEX_PATTERN)
    birth_date: Optional[PastDate] = None
    color: Optional[str] = Field(None, max_length=50)
    is_sterilized: bool = False
    microchip_id: Optional[str] = Field(None, max_length=30)
    blood_type: Optional[str] = Field(None, max_length=20)
    allergies: list[str] = Field(default_factory=list, max_length=20)
    chronic_conditions: list[str] = Field(default_factory=list, max_length=20)
    diet_notes: Optional[str] = Field(None, max_length=500)
    vet_name: Optional[str] = Field(None, max_length=80)
    vet_clinic: Optional[str] = Field(None, max_length=100)
    vet_phone: Optional[str] = Field(None, pattern=VET_PHONE_PATTERN)


    @field_validator("allergies", "chronic_conditions")
    @classmethod
    def _clean_list(cls, items: list[str]) -> list[str]:
        seen: set[str] = set()
        clean: list[str] = []
        for item in items:
            value = item.strip()
            if not value:
                continue
            if len(value) > 50:
                raise ValueError("Cada elemento debe tener máximo 50 caracteres")
            if value.lower() not in seen:
                seen.add(value.lower())
                clean.append(value)
        return clean


class HealthProfileResponseSchema(BaseModel):
    pet_id: str
    sex: str = "unknown"
    birth_date: Optional[str] = None
    age_months: Optional[int] = None
    color: Optional[str] = None
    is_sterilized: bool = False
    microchip_id: Optional[str] = None
    blood_type: Optional[str] = None
    allergies: list[str] = []
    chronic_conditions: list[str] = []
    diet_notes: Optional[str] = None
    vet_name: Optional[str] = None
    vet_clinic: Optional[str] = None
    vet_phone: Optional[str] = None
    is_registered: bool = False  # False → aún no se guardó la ficha (valores por defecto)
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


# ══════════════════════════════════════════════════════════
# CARTILLA DE VACUNACIÓN
# ══════════════════════════════════════════════════════════

class VaccinationCreateSchema(BaseModel):
    vaccine_name: str = Field(..., min_length=2, max_length=80)
    vaccine_type: str = Field("other", pattern=VACCINE_TYPE_PATTERN)
    dose_number: Optional[int] = Field(None, ge=1, le=20)
    applied_at: PastDate
    next_due_at: Optional[date] = None
    batch_number: Optional[str] = Field(None, max_length=50)
    vet_name: Optional[str] = Field(None, max_length=80)
    clinic_name: Optional[str] = Field(None, max_length=100)
    notes: Optional[str] = Field(None, max_length=500)


    @model_validator(mode="after")
    def _due_after_applied(self):
        if self.next_due_at and self.next_due_at < self.applied_at:
            raise ValueError("next_due_at debe ser posterior a applied_at")
        return self


class VaccinationUpdateSchema(_PartialUpdate):
    _non_nullable: ClassVar[tuple[str, ...]] = ("vaccine_name", "vaccine_type", "applied_at")

    vaccine_name: Optional[str] = Field(None, min_length=2, max_length=80)
    vaccine_type: Optional[str] = Field(None, pattern=VACCINE_TYPE_PATTERN)
    dose_number: Optional[int] = Field(None, ge=1, le=20)
    applied_at: Optional[PastDate] = None
    next_due_at: Optional[date] = None
    batch_number: Optional[str] = Field(None, max_length=50)
    vet_name: Optional[str] = Field(None, max_length=80)
    clinic_name: Optional[str] = Field(None, max_length=100)
    notes: Optional[str] = Field(None, max_length=500)


    @model_validator(mode="after")
    def _due_after_applied(self):
        if self.applied_at and self.next_due_at and self.next_due_at < self.applied_at:
            raise ValueError("next_due_at debe ser posterior a applied_at")
        return self


class VaccinationResponseSchema(BaseModel):
    id: str
    pet_id: str
    vaccine_name: str
    vaccine_type: str = "other"
    dose_number: Optional[int] = None
    applied_at: str
    next_due_at: Optional[str] = None
    batch_number: Optional[str] = None
    vet_name: Optional[str] = None
    clinic_name: Optional[str] = None
    notes: Optional[str] = None
    due_status: str = "no_due_date"
    days_until_due: Optional[int] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


# ══════════════════════════════════════════════════════════
# DESPARASITACIONES
# ══════════════════════════════════════════════════════════

class DewormingCreateSchema(BaseModel):
    product_name: str = Field(..., min_length=2, max_length=80)
    deworming_type: str = Field("internal", pattern=DEWORMING_TYPE_PATTERN)
    applied_at: PastDate
    next_due_at: Optional[date] = None
    weight_kg: Optional[float] = Field(None, gt=0, le=150)
    notes: Optional[str] = Field(None, max_length=500)


    @model_validator(mode="after")
    def _due_after_applied(self):
        if self.next_due_at and self.next_due_at < self.applied_at:
            raise ValueError("next_due_at debe ser posterior a applied_at")
        return self


class DewormingUpdateSchema(_PartialUpdate):
    _non_nullable: ClassVar[tuple[str, ...]] = ("product_name", "deworming_type", "applied_at")

    product_name: Optional[str] = Field(None, min_length=2, max_length=80)
    deworming_type: Optional[str] = Field(None, pattern=DEWORMING_TYPE_PATTERN)
    applied_at: Optional[PastDate] = None
    next_due_at: Optional[date] = None
    weight_kg: Optional[float] = Field(None, gt=0, le=150)
    notes: Optional[str] = Field(None, max_length=500)


    @model_validator(mode="after")
    def _due_after_applied(self):
        if self.applied_at and self.next_due_at and self.next_due_at < self.applied_at:
            raise ValueError("next_due_at debe ser posterior a applied_at")
        return self


class DewormingResponseSchema(BaseModel):
    id: str
    pet_id: str
    product_name: str
    deworming_type: str = "internal"
    applied_at: str
    next_due_at: Optional[str] = None
    weight_kg: Optional[float] = None
    notes: Optional[str] = None
    due_status: str = "no_due_date"
    days_until_due: Optional[int] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


# ══════════════════════════════════════════════════════════
# HISTORIAL CLÍNICO (CONSULTAS)
# ══════════════════════════════════════════════════════════

class VetVisitCreateSchema(BaseModel):
    visit_date: PastDate
    reason: str = Field(..., min_length=2, max_length=200)
    diagnosis: Optional[str] = Field(None, max_length=1000)
    treatment: Optional[str] = Field(None, max_length=1000)
    vet_name: Optional[str] = Field(None, max_length=80)
    clinic_name: Optional[str] = Field(None, max_length=100)
    weight_kg: Optional[float] = Field(None, gt=0, le=150)
    temperature_c: Optional[float] = Field(None, ge=30, le=45)
    cost_bob: Optional[float] = Field(None, ge=0)
    notes: Optional[str] = Field(None, max_length=500)



class VetVisitUpdateSchema(_PartialUpdate):
    _non_nullable: ClassVar[tuple[str, ...]] = ("visit_date", "reason")

    visit_date: Optional[PastDate] = None
    reason: Optional[str] = Field(None, min_length=2, max_length=200)
    diagnosis: Optional[str] = Field(None, max_length=1000)
    treatment: Optional[str] = Field(None, max_length=1000)
    vet_name: Optional[str] = Field(None, max_length=80)
    clinic_name: Optional[str] = Field(None, max_length=100)
    weight_kg: Optional[float] = Field(None, gt=0, le=150)
    temperature_c: Optional[float] = Field(None, ge=30, le=45)
    cost_bob: Optional[float] = Field(None, ge=0)
    notes: Optional[str] = Field(None, max_length=500)



class VetVisitResponseSchema(BaseModel):
    id: str
    pet_id: str
    visit_date: str
    reason: str
    diagnosis: Optional[str] = None
    treatment: Optional[str] = None
    vet_name: Optional[str] = None
    clinic_name: Optional[str] = None
    weight_kg: Optional[float] = None
    temperature_c: Optional[float] = None
    cost_bob: Optional[float] = None
    notes: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


# ══════════════════════════════════════════════════════════
# MEDICAMENTOS / TRATAMIENTOS
# ══════════════════════════════════════════════════════════

class MedicationCreateSchema(BaseModel):
    name: str = Field(..., min_length=2, max_length=80)
    dosage: Optional[str] = Field(None, max_length=80)
    frequency: Optional[str] = Field(None, max_length=80)
    start_date: date
    end_date: Optional[date] = None
    prescribed_by: Optional[str] = Field(None, max_length=80)
    visit_id: Optional[str] = None  # consulta donde se recetó (misma mascota)
    notes: Optional[str] = Field(None, max_length=500)

    @model_validator(mode="after")
    def _end_after_start(self):
        if self.end_date and self.end_date < self.start_date:
            raise ValueError("end_date debe ser posterior a start_date")
        return self


class MedicationUpdateSchema(_PartialUpdate):
    _non_nullable: ClassVar[tuple[str, ...]] = ("name", "start_date")

    name: Optional[str] = Field(None, min_length=2, max_length=80)
    dosage: Optional[str] = Field(None, max_length=80)
    frequency: Optional[str] = Field(None, max_length=80)
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    prescribed_by: Optional[str] = Field(None, max_length=80)
    visit_id: Optional[str] = None
    notes: Optional[str] = Field(None, max_length=500)

    @model_validator(mode="after")
    def _end_after_start(self):
        if self.start_date and self.end_date and self.end_date < self.start_date:
            raise ValueError("end_date debe ser posterior a start_date")
        return self


class MedicationResponseSchema(BaseModel):
    id: str
    pet_id: str
    visit_id: Optional[str] = None
    name: str
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    start_date: str
    end_date: Optional[str] = None
    prescribed_by: Optional[str] = None
    notes: Optional[str] = None
    is_active: bool = False
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


# ══════════════════════════════════════════════════════════
# CONTROL DE PESO
# ══════════════════════════════════════════════════════════

class WeightLogCreateSchema(BaseModel):
    weight_kg: float = Field(..., gt=0, le=150)
    measured_at: PastDate
    notes: Optional[str] = Field(None, max_length=200)



class WeightLogUpdateSchema(_PartialUpdate):
    _non_nullable: ClassVar[tuple[str, ...]] = ("weight_kg", "measured_at")

    weight_kg: Optional[float] = Field(None, gt=0, le=150)
    measured_at: Optional[PastDate] = None
    notes: Optional[str] = Field(None, max_length=200)



class WeightLogResponseSchema(BaseModel):
    id: str
    pet_id: str
    weight_kg: float
    measured_at: str
    notes: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


# ══════════════════════════════════════════════════════════
# CITAS VETERINARIAS
# ══════════════════════════════════════════════════════════

class AppointmentCreateSchema(BaseModel):
    scheduled_at: datetime  # sin zona horaria → se asume hora de Bolivia (UTC-4)
    reason: str = Field(..., min_length=2, max_length=200)
    vet_name: Optional[str] = Field(None, max_length=80)
    clinic_name: Optional[str] = Field(None, max_length=100)
    address: Optional[str] = Field(None, max_length=200)
    notes: Optional[str] = Field(None, max_length=500)

    @field_validator("scheduled_at")
    @classmethod
    def _aware(cls, value: datetime) -> datetime:
        return ensure_aware(value)


class AppointmentUpdateSchema(_PartialUpdate):
    _non_nullable: ClassVar[tuple[str, ...]] = ("scheduled_at", "reason", "status")

    scheduled_at: Optional[datetime] = None
    reason: Optional[str] = Field(None, min_length=2, max_length=200)
    vet_name: Optional[str] = Field(None, max_length=80)
    clinic_name: Optional[str] = Field(None, max_length=100)
    address: Optional[str] = Field(None, max_length=200)
    status: Optional[str] = Field(None, pattern=APPOINTMENT_STATUS_PATTERN)
    notes: Optional[str] = Field(None, max_length=500)

    @field_validator("scheduled_at")
    @classmethod
    def _aware(cls, value: Optional[datetime]) -> Optional[datetime]:
        return ensure_aware(value) if value else value


class AppointmentResponseSchema(BaseModel):
    id: str
    pet_id: str
    scheduled_at: str
    reason: str
    vet_name: Optional[str] = None
    clinic_name: Optional[str] = None
    address: Optional[str] = None
    status: str = "scheduled"
    notes: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


# ══════════════════════════════════════════════════════════
# DOCUMENTOS CLÍNICOS
# ══════════════════════════════════════════════════════════

class HealthDocumentCreateSchema(BaseModel):
    title: str = Field(..., min_length=2, max_length=100)
    doc_type: str = Field("other", pattern=DOC_TYPE_PATTERN)
    issued_at: Optional[PastDate] = None
    notes: Optional[str] = Field(None, max_length=500)
    file_base64: str = Field(..., description="JPEG, PNG o PDF en base64 (acepta prefijo data:). Máx 5 MB.")



class HealthDocumentUpdateSchema(_PartialUpdate):
    """Solo metadatos; para cambiar el archivo se borra y se sube otro."""
    _non_nullable: ClassVar[tuple[str, ...]] = ("title", "doc_type")

    title: Optional[str] = Field(None, min_length=2, max_length=100)
    doc_type: Optional[str] = Field(None, pattern=DOC_TYPE_PATTERN)
    issued_at: Optional[PastDate] = None
    notes: Optional[str] = Field(None, max_length=500)



class HealthDocumentResponseSchema(BaseModel):
    id: str
    pet_id: str
    title: str
    doc_type: str = "other"
    mime_type: str
    size_bytes: int
    issued_at: Optional[str] = None
    notes: Optional[str] = None
    url: Optional[str] = None  # URL firmada temporal (1 h) — no guardarla
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


# ══════════════════════════════════════════════════════════
# RESUMEN, RECORDATORIOS Y CARNET COMPARTIDO
# ══════════════════════════════════════════════════════════

class HealthReminderSchema(BaseModel):
    pet_id: str
    pet_name: str
    kind: str          # vaccination | deworming | appointment
    record_id: str
    title: str
    due_date: str      # fecha ISO (cita: datetime ISO)
    days_left: int     # negativo = vencido
    is_overdue: bool


class HealthCountsSchema(BaseModel):
    vaccinations: int = 0
    dewormings: int = 0
    visits: int = 0
    medications_active: int = 0
    documents: int = 0


class HealthSummarySchema(BaseModel):
    pet_id: str
    pet_name: str
    photo_url: Optional[str] = None
    profile: HealthProfileResponseSchema
    vaccination_status: str = "no_records"
    deworming_status: str = "no_records"
    latest_weight: Optional[WeightLogResponseSchema] = None
    next_appointment: Optional[AppointmentResponseSchema] = None
    active_medications: list[MedicationResponseSchema] = []
    reminders: list[HealthReminderSchema] = []
    counts: HealthCountsSchema


class SharedPetSchema(BaseModel):
    name: str
    breed: Optional[str] = None
    age_years: Optional[int] = None
    photo_url: Optional[str] = None


class HealthCardSchema(BaseModel):
    """Carnet completo de solo lectura (lo ve el veterinario vía enlace/QR)."""
    pet: SharedPetSchema
    profile: HealthProfileResponseSchema
    vaccination_status: str = "no_records"
    deworming_status: str = "no_records"
    latest_weight: Optional[WeightLogResponseSchema] = None
    vaccinations: list[VaccinationResponseSchema] = []
    dewormings: list[DewormingResponseSchema] = []
    active_medications: list[MedicationResponseSchema] = []
    recent_visits: list[VetVisitResponseSchema] = []
    documents: list[HealthDocumentResponseSchema] = []
    generated_at: str
    expires_at: Optional[str] = None


class HealthShareCreateSchema(BaseModel):
    expires_in_hours: int = Field(24, ge=1, le=168)


class HealthShareResponseSchema(BaseModel):
    id: str
    pet_id: str
    token: str
    share_url: str    # JSON (para apps)
    carnet_url: str   # HTML imprimible (para codificar en el QR)
    expires_at: str
    revoked_at: Optional[str] = None
    last_accessed_at: Optional[str] = None
    is_active: bool
    created_at: Optional[str] = None
