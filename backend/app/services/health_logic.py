# app/services/health_logic.py
"""
Lógica pura del módulo Salud (sin BD ni red → testeable en UniTest/).

  - Fechas en hora de Bolivia (UTC-4 fijo, sin horario de verano).
  - Estado de vencimiento de vacunas / desparasitaciones.
  - "Registro vigente": solo la última aplicación de cada vacuna (o de cada
    tipo de desparasitación) genera recordatorio; las anteriores quedan
    como `superseded` (renovadas).
  - Recordatorios y detección de tipo de archivo por firma (magic bytes).
"""

import unicodedata
from datetime import date, datetime, timedelta, timezone
from typing import Callable, Iterable, Optional


BOLIVIA_TZ = timezone(timedelta(hours=-4), name="BOT")
DUE_SOON_DAYS = 30

# Desparasitación "both" cubre ambos aspectos
DEWORMING_ASPECTS: dict[str, tuple[str, ...]] = {
    "internal": ("internal",),
    "external": ("external",),
    "both":     ("internal", "external"),
}

DEWORMING_LABELS: dict[str, str] = {
    "internal": "interna",
    "external": "externa",
    "both":     "interna y externa",
}

# Orden de gravedad para el estado global de la cartilla
_SEVERITY = {"overdue": 3, "due_soon": 2, "up_to_date": 1, "no_due_date": 1}


# ── Fechas ──────────────────────────────────────────────────────────────────

def today_bolivia(now: Optional[datetime] = None) -> date:
    now = now or datetime.now(timezone.utc)
    return now.astimezone(BOLIVIA_TZ).date()


def ensure_aware(value: datetime) -> datetime:
    """Datetime sin zona horaria → se interpreta como hora de Bolivia."""
    if value.tzinfo is None:
        return value.replace(tzinfo=BOLIVIA_TZ)
    return value


def parse_date(value: str | date | None) -> Optional[date]:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def parse_datetime(value: str | datetime | None) -> Optional[datetime]:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return ensure_aware(value)
    try:
        return ensure_aware(datetime.fromisoformat(str(value).replace("Z", "+00:00")))
    except ValueError:
        return None


def age_in_months(birth_date: str | date | None, today: date) -> Optional[int]:
    born = parse_date(birth_date)
    if born is None or born > today:
        return None
    months = (today.year - born.year) * 12 + (today.month - born.month)
    if today.day < born.day:
        months -= 1
    return max(months, 0)


# ── Vencimientos ────────────────────────────────────────────────────────────

def due_status(
    next_due: str | date | None,
    today: date,
    soon_days: int = DUE_SOON_DAYS,
) -> tuple[str, Optional[int]]:
    """→ (estado, días restantes). Días negativos = vencido."""
    due = parse_date(next_due)
    if due is None:
        return "no_due_date", None
    days = (due - today).days
    if days < 0:
        return "overdue", days
    if days <= soon_days:
        return "due_soon", days
    return "up_to_date", days


def _normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text or "")
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return " ".join(text.lower().split())


def vaccine_keys(record: dict) -> tuple[str, ...]:
    """Una antirrábica renueva a otra antirrábica; las 'other' se agrupan por nombre."""
    vtype = record.get("vaccine_type") or "other"
    if vtype != "other":
        return (vtype,)
    return (f"other:{_normalize(record.get('vaccine_name', ''))}",)


def deworming_keys(record: dict) -> tuple[str, ...]:
    return DEWORMING_ASPECTS.get(record.get("deworming_type") or "internal", ("internal",))


def current_record_ids(
    records: Iterable[dict],
    keys_fn: Callable[[dict], tuple[str, ...]],
) -> set[str]:
    """IDs de los registros vigentes: el más reciente (applied_at) por cada clave."""
    latest: dict[str, dict] = {}
    for rec in records:
        sort_key = (parse_date(rec.get("applied_at")) or date.min, rec.get("created_at") or "")
        for key in keys_fn(rec):
            prev = latest.get(key)
            if prev is None or sort_key > prev["_sort"]:
                latest[key] = {"_sort": sort_key, "id": rec["id"]}
    return {item["id"] for item in latest.values()}


def annotate_due(
    records: list[dict],
    keys_fn: Callable[[dict], tuple[str, ...]],
    today: date,
) -> list[dict]:
    """Copia de los registros con `due_status` y `days_until_due`."""
    current = current_record_ids(records, keys_fn)
    annotated: list[dict] = []
    for rec in records:
        row = dict(rec)
        if rec["id"] not in current:
            row["due_status"], row["days_until_due"] = "superseded", None
        else:
            row["due_status"], row["days_until_due"] = due_status(rec.get("next_due_at"), today)
        annotated.append(row)
    return annotated


def overall_status(annotated: list[dict]) -> str:
    """Estado global: el peor entre los registros vigentes."""
    if not annotated:
        return "no_records"
    worst = "up_to_date"
    for rec in annotated:
        status = rec.get("due_status")
        if status in _SEVERITY and _SEVERITY[status] > _SEVERITY[worst]:
            worst = status
    return "up_to_date" if worst == "no_due_date" else worst


def medication_is_active(start: str | date | None, end: str | date | None, today: date) -> bool:
    start_d = parse_date(start)
    end_d = parse_date(end)
    if start_d is None or start_d > today:
        return False
    return end_d is None or end_d >= today


# ── Recordatorios ───────────────────────────────────────────────────────────

def build_reminders(
    pet: dict,
    vaccinations: list[dict],
    dewormings: list[dict],
    appointments: list[dict],
    now: datetime,
    window_days: int = DUE_SOON_DAYS,
) -> list[dict]:
    """
    Recordatorios de UNA mascota: vencidos + los que vencen en `window_days`.
    `vaccinations` / `dewormings` deben venir ya anotados con annotate_due().
    """
    today = today_bolivia(now)
    reminders: list[dict] = []

    for rec in vaccinations:
        days = rec.get("days_until_due")
        if rec.get("due_status") in ("overdue", "due_soon", "up_to_date") and days is not None and days <= window_days:
            reminders.append({
                "pet_id": pet["id"], "pet_name": pet["name"], "kind": "vaccination",
                "record_id": rec["id"], "title": f"Vacuna {rec['vaccine_name']}",
                "due_date": str(parse_date(rec["next_due_at"])),
                "days_left": days, "is_overdue": days < 0,
            })

    for rec in dewormings:
        days = rec.get("days_until_due")
        if rec.get("due_status") in ("overdue", "due_soon", "up_to_date") and days is not None and days <= window_days:
            label = DEWORMING_LABELS.get(rec.get("deworming_type") or "internal", "")
            reminders.append({
                "pet_id": pet["id"], "pet_name": pet["name"], "kind": "deworming",
                "record_id": rec["id"], "title": f"Desparasitación {label} ({rec['product_name']})",
                "due_date": str(parse_date(rec["next_due_at"])),
                "days_left": days, "is_overdue": days < 0,
            })

    for appt in appointments:
        if appt.get("status") != "scheduled":
            continue
        when = parse_datetime(appt.get("scheduled_at"))
        if when is None:
            continue
        days = (when.astimezone(BOLIVIA_TZ).date() - today).days
        if days <= window_days:
            reminders.append({
                "pet_id": pet["id"], "pet_name": pet["name"], "kind": "appointment",
                "record_id": appt["id"], "title": f"Cita: {appt['reason']}",
                "due_date": when.isoformat(),
                # Cita pasada sin marcar completada/cancelada → pendiente de actualizar
                "days_left": days, "is_overdue": when < now,
            })

    reminders.sort(key=lambda r: (r["days_left"], r["due_date"]))
    return reminders


def next_appointment(appointments: list[dict], now: datetime) -> Optional[dict]:
    upcoming = [
        a for a in appointments
        if a.get("status") == "scheduled"
        and (when := parse_datetime(a.get("scheduled_at"))) is not None
        and when >= now
    ]
    return min(upcoming, key=lambda a: parse_datetime(a["scheduled_at"])) if upcoming else None


# ── Archivos ────────────────────────────────────────────────────────────────

MAX_DOCUMENT_BYTES = 5 * 1024 * 1024

def detect_file_type(data: bytes) -> Optional[tuple[str, str]]:
    """→ (mime_type, extensión) por firma del archivo, o None si no es permitido."""
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg", "jpg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png", "png"
    if data.startswith(b"%PDF-"):
        return "application/pdf", "pdf"
    return None
