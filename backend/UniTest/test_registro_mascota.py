"""
Unit tests — REGISTRO DE MASCOTAS (POST /pets/)

Se prueban dos cosas, sin BD real ni internet:
  1. Validación de datos (PetCreateSchema): qué acepta y qué rechaza.
  2. Lógica del endpoint con Supabase FALSO (ver conftest.py).

Ejecutar:  pytest test_registro_mascota.py
"""

import pytest
from pydantic import ValidationError

from app.core.schemas import PetCreateSchema
from app.core.schemas import UserLoginSchema
from app.routes import pets as pets_routes
from conftest import USER_ID


# ════════════════════════════════════════════════════════════════════════════
# 1. Validación de datos
# ════════════════════════════════════════════════════════════════════════════

def test_datos_validos_se_aceptan():
    """Una mascota con datos correctos se acepta sin errores."""
    pet =PetCreateSchema(name="Maya", breed="Mestiza", age_years=3, phone="+59171234567")
    assert pet.name == "Maya"
    assert pet.age_years == 3
    assert pet.phone == "+59171234567"

# ════════════════════════════════════════════════════════════════════════════
# 2. Endpoint POST /pets/ (con Supabase falso)
# ════════════════════════════════════════════════════════════════════════════

def _fila_creada(**extra):
    """Fila que devolvería Supabase tras el INSERT."""
    return {"id": "pet-1", "owner_id": USER_ID, "name": "Maya", "status": "home", **extra}


def test_registro_exitoso_devuelve_201_y_estado_home(client, fake_supabase, monkeypatch):
    """La mascota se guarda a nombre del dueño y en estado 'home'."""
    # Arrange
    db = fake_supabase({"pets": [_fila_creada()]})
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    # Act
    resp = client.post("/pets/", json={"name": "Maya"})

    # Assert: respuesta al usuario
    assert resp.status_code == 201, "El registro debía responder 201 (creado)"
    assert resp.json()["status"] == "home"
    # Assert: lo que realmente se envió a la BD
    guardado = db.inserts[0]
    assert guardado["status"] == "home", "La mascota nueva debe guardarse en estado 'home'"
    assert guardado["owner_id"] == USER_ID, "La mascota debe guardarse a nombre del usuario logueado"


def test_registro_con_telefono_lo_guarda_en_el_perfil(client, fake_supabase, monkeypatch):
    """El teléfono del paso 4 del wizard se guarda en el perfil del dueño."""
    db = fake_supabase({"pets": [_fila_creada()], "profiles": [{"id": USER_ID}]})
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    client.post("/pets/", json={"name": "Maya", "phone": "+59171234567"})

    assert {"phone": "+59171234567"} in db.updates, "El teléfono no se guardó en el perfil"


def test_registro_sin_telefono_no_toca_el_perfil(client, fake_supabase, monkeypatch):
    """Si se omite el teléfono, el perfil del dueño no se modifica."""
    db = fake_supabase({"pets": [_fila_creada()]})
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    client.post("/pets/", json={"name": "Maya"})

    assert db.updates == [], "Sin teléfono no se debía modificar el perfil"


def test_datos_invalidos_devuelven_422(client, fake_supabase, monkeypatch):
    """Un nombre de 1 letra se rechaza con 422 sin llegar a la BD."""
    db = fake_supabase({"pets": [_fila_creada()]})
    monkeypatch.setattr(pets_routes, "supabase_admin", db)
    resp = client.post("/pets/", json={"name": "M"})
    assert resp.status_code == 422, "Un dato inválido debía rechazarse con 422"
    assert db.inserts == [], "Un dato inválido no debía llegar a la BD"


def test_si_la_bd_no_inserta_devuelve_500(client, fake_supabase, monkeypatch):
    """Si la BD no guarda la mascota, se responde un error controlado (500)."""
    monkeypatch.setattr(pets_routes, "supabase_admin", fake_supabase({"pets": []}))
    resp = client.post("/pets/", json={"name": "Maya"})
    assert resp.status_code == 500, "Si la BD falla se esperaba un error 500"
    assert resp.json()["error"] == "No se pudo registrar la mascota"
