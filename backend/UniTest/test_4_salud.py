"""
TIPO 4 — Módulo Salud / Carnet veterinario

  1. Lógica pura (app/services/health_logic.py): vencimientos, renovaciones,
     recordatorios, zona horaria de Bolivia, tipo de archivo.
  2. Validación de schemas (app/core/health_schemas.py).
  3. Endpoints (app/routes/health.py) contra una BD EN MEMORIA que imita
     supabase-py (select/insert/update/delete/upsert + storage).

Patrón usado: AAA (Arrange - Act - Assert).
"""

import base64
import copy
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.core import health_schemas as hs
from app.services import health_logic as hl

USER_ID = "user-123"
PET_ID = "11111111-1111-4111-8111-111111111111"
OTHER_PET_ID = "22222222-2222-4222-8222-222222222222"

TODAY = date(2026, 10, 13)
NOW = datetime(2026, 10, 13, 16, 0, tzinfo=timezone.utc)  # 12:00 en Bolivia


def _vacc(id_, applied, due, vtype="rabies", name="Antirrábica"):
    return {"id": id_, "vaccine_name": name, "vaccine_type": vtype,
            "applied_at": applied, "next_due_at": due, "created_at": applied}


# ════════════════════════════════════════════════════════════════════════════
# 1. LÓGICA PURA
# ════════════════════════════════════════════════════════════════════════════

@pytest.mark.parametrize("due, esperado, dias", [
    (None,         "no_due_date", None),
    ("2026-10-01", "overdue",     -12),
    ("2026-10-13", "due_soon",    0),
    ("2026-11-12", "due_soon",    30),
    ("2026-11-13", "up_to_date",  31),
])
def test_due_status(due, esperado, dias):
    assert hl.due_status(due, TODAY) == (esperado, dias)


def test_hoy_en_bolivia_es_un_dia_antes_a_las_2am_utc():
    # 02:00 UTC del 14 = 22:00 del 13 en Bolivia
    assert hl.today_bolivia(datetime(2026, 10, 14, 2, 0, tzinfo=timezone.utc)) == TODAY


def test_datetime_sin_zona_se_asume_bolivia():
    aware = hl.ensure_aware(datetime(2026, 10, 20, 9, 30))
    assert aware.utcoffset() == timedelta(hours=-4)


def test_vacuna_renovada_queda_superseded_y_no_genera_alerta():
    # Arrange: antirrábica 2025 (vencida) renovada en 2026
    vieja = _vacc("v1", "2025-09-01", "2026-09-01")
    nueva = _vacc("v2", "2026-09-05", "2027-09-05")
    # Act
    anotadas = {v["id"]: v for v in hl.annotate_due([vieja, nueva], hl.vaccine_keys, TODAY)}
    # Assert
    assert anotadas["v1"]["due_status"] == "superseded"
    assert anotadas["v2"]["due_status"] == "up_to_date"
    assert hl.overall_status(list(anotadas.values())) == "up_to_date"


def test_vacunas_other_se_agrupan_por_nombre_sin_tildes_ni_mayusculas():
    a = _vacc("a", "2025-01-01", "2025-06-01", vtype="other", name="Giardia")
    b = _vacc("b", "2026-01-01", "2027-01-01", vtype="other", name="  GIÁRDIA ")
    assert hl.current_record_ids([a, b], hl.vaccine_keys) == {"b"}


def test_desparasitacion_both_solo_renueva_el_aspecto_que_cubre():
    # 'both' antigua sigue vigente para 'external' si después solo se aplicó 'internal'
    both = {"id": "d1", "deworming_type": "both", "applied_at": "2026-05-01", "next_due_at": "2026-08-01"}
    interna = {"id": "d2", "deworming_type": "internal", "applied_at": "2026-09-01", "next_due_at": "2026-12-01"}
    assert hl.current_record_ids([both, interna], hl.deworming_keys) == {"d1", "d2"}


def test_estado_global_toma_el_peor():
    registros = [{"due_status": "up_to_date"}, {"due_status": "overdue"}, {"due_status": "superseded"}]
    assert hl.overall_status(registros) == "overdue"
    assert hl.overall_status([]) == "no_records"
    assert hl.overall_status([{"due_status": "no_due_date"}]) == "up_to_date"


@pytest.mark.parametrize("inicio, fin, activo", [
    ("2026-10-01", None,         True),
    ("2026-10-01", "2026-10-13", True),
    ("2026-10-01", "2026-10-12", False),
    ("2026-10-20", None,         False),  # aún no empieza
])
def test_medicamento_activo(inicio, fin, activo):
    assert hl.medication_is_active(inicio, fin, TODAY) is activo


def test_recordatorios_incluyen_vencidos_proximos_y_citas():
    pet = {"id": PET_ID, "name": "Maya"}
    vacunas = hl.annotate_due([
        _vacc("v1", "2025-10-01", "2026-10-01"),                                   # vencida
        _vacc("v2", "2026-01-01", "2027-01-01", vtype="polyvalent", name="Séxtuple"),  # lejana
    ], hl.vaccine_keys, TODAY)
    citas = [
        {"id": "c1", "status": "scheduled", "reason": "Control", "scheduled_at": "2026-10-20T10:00:00-04:00"},
        {"id": "c2", "status": "cancelled", "reason": "X", "scheduled_at": "2026-10-15T10:00:00-04:00"},
    ]

    recordatorios = hl.build_reminders(pet, vacunas, [], citas, NOW)

    assert [r["record_id"] for r in recordatorios] == ["v1", "c1"]
    assert recordatorios[0]["is_overdue"] is True and recordatorios[0]["days_left"] == -12
    assert recordatorios[1]["kind"] == "appointment" and recordatorios[1]["days_left"] == 7


def test_edad_en_meses():
    assert hl.age_in_months("2024-10-14", TODAY) == 23
    assert hl.age_in_months("2024-10-13", TODAY) == 24
    assert hl.age_in_months(None, TODAY) is None


@pytest.mark.parametrize("contenido, esperado", [
    (b"\xff\xd8\xff\xe0resto", ("image/jpeg", "jpg")),
    (b"\x89PNG\r\n\x1a\nresto", ("image/png", "png")),
    (b"%PDF-1.7 resto", ("application/pdf", "pdf")),
    (b"<html>no</html>", None),
])
def test_detecta_tipo_por_firma(contenido, esperado):
    assert hl.detect_file_type(contenido) == esperado


# ════════════════════════════════════════════════════════════════════════════
# 2. SCHEMAS
# ════════════════════════════════════════════════════════════════════════════

def test_vacuna_no_puede_aplicarse_en_el_futuro():
    with pytest.raises(ValidationError):
        hs.VaccinationCreateSchema(vaccine_name="Antirrábica", applied_at=date.today() + timedelta(days=5))


def test_refuerzo_debe_ser_posterior_a_la_aplicacion():
    with pytest.raises(ValidationError):
        hs.VaccinationCreateSchema(vaccine_name="Antirrábica", applied_at="2026-01-10", next_due_at="2026-01-01")


def test_patch_no_acepta_null_en_campos_obligatorios():
    with pytest.raises(ValidationError):
        hs.VaccinationUpdateSchema(vaccine_name=None)
    # Un opcional sí puede limpiarse con null
    assert hs.VaccinationUpdateSchema(next_due_at=None).model_dump(exclude_unset=True) == {"next_due_at": None}


def test_tipo_de_vacuna_invalido():
    with pytest.raises(ValidationError):
        hs.VaccinationCreateSchema(vaccine_name="X1", vaccine_type="covid", applied_at="2026-01-01")


def test_alergias_se_limpian_y_deduplican():
    perfil = hs.HealthProfileUpsertSchema(allergies=[" Pollo ", "pollo", "", "Penicilina"])
    assert perfil.allergies == ["Pollo", "Penicilina"]


def test_cita_sin_zona_horaria_se_guarda_con_offset_bolivia():
    cita = hs.AppointmentCreateSchema(scheduled_at="2026-10-20T10:00:00", reason="Vacuna")
    assert cita.model_dump(mode="json")["scheduled_at"] == "2026-10-20T10:00:00-04:00"


# ════════════════════════════════════════════════════════════════════════════
# 3. ENDPOINTS (BD en memoria)
# ════════════════════════════════════════════════════════════════════════════

# DEFAULT de columnas que Postgres rellena y el payload no envía
TABLE_DEFAULTS = {
    "pet_vet_appointments": {"status": "scheduled"},
}


class MemQuery:
    """Imita la API encadenable de supabase-py sobre listas de dicts."""

    def __init__(self, db: dict, table: str):
        self.db, self.table = db, table
        self.op, self.payload, self.conflict = "select", None, None
        self.filters, self._order, self._limit = [], None, None

    def select(self, *_args, **_kwargs):
        self.op = "select"
        return self

    def insert(self, data):
        self.op, self.payload = "insert", data
        return self

    def upsert(self, data, on_conflict=None):
        self.op, self.payload, self.conflict = "upsert", data, on_conflict
        return self

    def update(self, data):
        self.op, self.payload = "update", data
        return self

    def delete(self):
        self.op = "delete"
        return self

    def eq(self, col, val):
        self.filters.append(lambda r: r.get(col) == val)
        return self

    def in_(self, col, vals):
        self.filters.append(lambda r: r.get(col) in vals)
        return self

    def order(self, col, desc=False):
        self._order = (col, desc)
        return self

    def limit(self, n):
        self._limit = n
        return self

    def _match(self, rows):
        return [r for r in rows if all(f(r) for f in self.filters)]

    def execute(self):
        rows = self.db.setdefault(self.table, [])
        stamp = datetime.now(timezone.utc).isoformat()

        if self.op == "insert":
            row = {"id": str(uuid4()), "created_at": stamp, "updated_at": stamp,
                   "revoked_at": None, "last_accessed_at": None,
                   **TABLE_DEFAULTS.get(self.table, {}), **self.payload}
            rows.append(row)
            return SimpleNamespace(data=[copy.deepcopy(row)])

        if self.op == "upsert":
            key = self.conflict
            existing = next((r for r in rows if r.get(key) == self.payload[key]), None)
            if existing:
                existing.update(self.payload, updated_at=stamp)
                return SimpleNamespace(data=[copy.deepcopy(existing)])
            row = {"created_at": stamp, "updated_at": stamp, **self.payload}
            rows.append(row)
            return SimpleNamespace(data=[copy.deepcopy(row)])

        matched = self._match(rows)
        if self.op == "update":
            for r in matched:
                r.update(self.payload, updated_at=stamp)
        elif self.op == "delete":
            for r in matched:
                rows.remove(r)
        else:
            if self._order:
                col, desc = self._order
                matched = sorted(matched, key=lambda r: str(r.get(col) or ""), reverse=desc)
            if self._limit:
                matched = matched[: self._limit]
        return SimpleNamespace(data=copy.deepcopy(matched))


class MemBucket:
    def __init__(self, files: dict):
        self.files = files

    def upload(self, path, data, _options):
        self.files[path] = data

    def remove(self, paths):
        for p in paths:
            self.files.pop(p, None)

    def create_signed_url(self, path, seconds):
        return {"signedURL": f"https://signed.test/{path}?expires={seconds}"}


class MemSupabase:
    def __init__(self):
        self.db = {"pets": [
            {"id": PET_ID, "owner_id": USER_ID, "name": "Maya", "breed": "Mestiza",
             "age_years": 3, "photo_url": None, "is_active": True},
            {"id": OTHER_PET_ID, "owner_id": "otro-usuario", "name": "Rex", "breed": None,
             "age_years": 5, "photo_url": None, "is_active": True},
        ]}
        self.files: dict[str, bytes] = {}
        self.storage = SimpleNamespace(from_=lambda _name: MemBucket(self.files))

    def table(self, name):
        return MemQuery(self.db, name)


@pytest.fixture
def mem_db(monkeypatch):
    from app.routes import health as health_routes
    db = MemSupabase()
    monkeypatch.setattr(health_routes, "supabase_admin", db)
    return db


@pytest.fixture
def api(mem_db):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    from app.core.dependencies import get_current_user_id
    from app.core.errors import ChowTrackException, global_exception_handler
    from app.routes import health as health_routes

    app = FastAPI()
    app.add_exception_handler(ChowTrackException, global_exception_handler)
    app.include_router(health_routes.router)
    app.include_router(health_routes.public_router)
    app.dependency_overrides[get_current_user_id] = lambda: USER_ID
    return TestClient(app)


BASE = f"/pets/{PET_ID}/health"


def test_mascota_de_otro_usuario_da_404(api):
    r = api.get(f"/pets/{OTHER_PET_ID}/health/vaccinations")
    assert r.status_code == 404
    assert r.json()["detail"] == "pet_not_found"


def test_pet_id_invalido_da_404_no_500(api):
    assert api.get("/pets/no-es-uuid/health").status_code == 404


def test_crud_vacuna_con_estado_de_vencimiento(api):
    hoy = hl.today_bolivia()
    # Crear vacuna con refuerzo en 10 días → due_soon
    r = api.post(f"{BASE}/vaccinations", json={
        "vaccine_name": "Antirrábica", "vaccine_type": "rabies",
        "applied_at": str(hoy - timedelta(days=355)), "next_due_at": str(hoy + timedelta(days=10)),
    })
    assert r.status_code == 201, r.text
    vacuna = r.json()
    assert vacuna["due_status"] == "due_soon" and vacuna["days_until_due"] == 10

    # Renovarla → la anterior pasa a superseded
    api.post(f"{BASE}/vaccinations", json={
        "vaccine_name": "Antirrábica", "vaccine_type": "rabies",
        "applied_at": str(hoy), "next_due_at": str(hoy + timedelta(days=365)),
    })
    lista = {v["id"]: v for v in api.get(f"{BASE}/vaccinations").json()}
    assert lista[vacuna["id"]]["due_status"] == "superseded"

    # Editar y borrar
    r = api.patch(f"{BASE}/vaccinations/{vacuna['id']}", json={"batch_number": "L-123"})
    assert r.status_code == 200 and r.json()["batch_number"] == "L-123"
    assert api.delete(f"{BASE}/vaccinations/{vacuna['id']}").status_code == 204
    assert api.delete(f"{BASE}/vaccinations/{vacuna['id']}").status_code == 404


def test_patch_vacio_da_400(api):
    vid = api.post(f"{BASE}/vaccinations", json={"vaccine_name": "Séxtuple", "applied_at": "2026-01-01"}).json()["id"]
    r = api.patch(f"{BASE}/vaccinations/{vid}", json={})
    assert r.status_code == 400 and r.json()["detail"] == "empty_update"


def test_perfil_por_defecto_y_upsert(api):
    vacio = api.get(f"{BASE}/profile").json()
    assert vacio["is_registered"] is False and vacio["sex"] == "unknown"

    r = api.put(f"{BASE}/profile", json={"sex": "female", "birth_date": "2023-05-10", "allergies": ["Pollo"]})
    assert r.status_code == 200, r.text
    assert r.json()["is_registered"] is True and r.json()["age_months"] is not None


def test_medicamento_con_consulta_de_otra_mascota_da_422(api):
    r = api.post(f"{BASE}/medications", json={
        "name": "Amoxicilina", "start_date": "2026-10-01", "visit_id": str(uuid4()),
    })
    assert r.status_code == 422 and r.json()["detail"] == "visit_not_found"


def test_resumen_con_recordatorios_y_contadores(api):
    hoy = hl.today_bolivia()
    api.post(f"{BASE}/vaccinations", json={
        "vaccine_name": "Antirrábica", "vaccine_type": "rabies",
        "applied_at": str(hoy - timedelta(days=400)), "next_due_at": str(hoy - timedelta(days=35)),
    })
    api.post(f"{BASE}/weights", json={"weight_kg": 12.5, "measured_at": str(hoy)})
    api.post(f"{BASE}/medications", json={"name": "Omeprazol", "start_date": str(hoy)})
    api.post(f"{BASE}/appointments", json={
        "scheduled_at": (datetime.now(timezone.utc) + timedelta(days=2)).isoformat(), "reason": "Refuerzo",
    })

    resumen = api.get(BASE).json()

    assert resumen["vaccination_status"] == "overdue"
    assert resumen["latest_weight"]["weight_kg"] == 12.5
    assert resumen["next_appointment"]["reason"] == "Refuerzo"
    assert resumen["counts"]["medications_active"] == 1
    assert [r["kind"] for r in resumen["reminders"]] == ["vaccination", "appointment"]

    # Recordatorios globales (todas mis mascotas)
    globales = api.get("/health/reminders").json()
    assert len(globales) == 2 and globales[0]["is_overdue"] is True


def test_documento_formato_no_permitido_da_415(api):
    archivo = base64.b64encode(b"<html>malicioso</html>").decode()
    r = api.post(f"{BASE}/documents", json={"title": "Análisis", "file_base64": archivo})
    assert r.status_code == 415


def test_documento_png_se_sube_y_devuelve_url_firmada(api, mem_db):
    archivo = "data:image/png;base64," + base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"0" * 100).decode()
    r = api.post(f"{BASE}/documents", json={"title": "Carnet físico", "doc_type": "vaccine_certificate",
                                            "file_base64": archivo})
    assert r.status_code == 201, r.text
    doc = r.json()
    assert doc["mime_type"] == "image/png" and doc["url"].startswith("https://signed.test/")
    assert len(mem_db.files) == 1

    assert api.delete(f"{BASE}/documents/{doc['id']}").status_code == 204
    assert mem_db.files == {}


def test_compartir_carnet_publico_revocar_y_expirar(api, mem_db):
    api.put(f"{BASE}/profile", json={"allergies": ["<script>alert(1)</script>"]})
    share = api.post(f"{BASE}/shares", json={"expires_in_hours": 2}).json()
    assert share["is_active"] is True and share["carnet_url"].endswith("/carnet")

    # El veterinario (sin token Bearer) abre el carnet
    publico = api.get(f"/health/shared/{share['token']}")
    assert publico.status_code == 200
    assert publico.json()["pet"]["name"] == "Maya"
    assert "owner_id" not in publico.json()["pet"]

    html = api.get(f"/health/shared/{share['token']}/carnet")
    assert html.status_code == 200 and "text/html" in html.headers["content-type"]
    assert "<script>alert(1)</script>" not in html.text  # datos escapados
    assert "&lt;script&gt;" in html.text

    # Revocar → 404
    assert api.delete(f"{BASE}/shares/{share['id']}").status_code == 204
    assert api.get(f"/health/shared/{share['token']}").status_code == 404
    assert api.get(f"/health/shared/{share['token']}/carnet").status_code == 404

    # Expirado → 404
    nuevo = api.post(f"{BASE}/shares", json={}).json()
    for row in mem_db.db["pet_health_shares"]:
        if row["id"] == nuevo["id"]:
            row["expires_at"] = (datetime.now(timezone.utc) - timedelta(minutes=1)).isoformat()
    assert api.get(f"/health/shared/{nuevo['token']}").status_code == 404


def test_token_inexistente_da_404(api):
    assert api.get("/health/shared/" + "x" * 43).status_code == 404
