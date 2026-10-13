"""
TIPO 3 — Unit tests con MOCKS (dobles de prueba)

Los endpoints de pets y map dependen de Supabase. En un unit test NO queremos
la BD real (lenta, cambia, necesita internet), así que la reemplazamos por un
cliente FALSO (FakeSupabase, definido en conftest.py) con datos controlados.

Así probamos SOLO la lógica del endpoint:
  - ¿deduplica la lista de mascotas?
  - ¿guarda las coordenadas al marcar 'lost'?
  - ¿el mapa oculta 'home' después de 1 hora y respeta el radio?

Herramientas: monkeypatch (pytest) + TestClient (FastAPI) + dependency_overrides.
"""

from datetime import datetime, timedelta, timezone

import pytest

from app.routes import map as map_routes
from app.routes import pets as pets_routes
from conftest import USER_ID


def _pet(pet_id, status="home", **extra):
    """Fila de ejemplo tal como la devuelve la vista my_pets."""
    return {"id": pet_id, "owner_id": USER_ID, "name": f"Pet {pet_id}",
            "status": status, **extra}


# ════════════════════════════════════════════════════════════════════════════
# GET /pets/  — lista "Mis mascotas"
# ════════════════════════════════════════════════════════════════════════════

def test_lista_de_mascotas_sin_duplicados(client, fake_supabase, monkeypatch):
    # Arrange: la BD devuelve la misma mascota 3 veces (3 fotos nasales)
    db = fake_supabase({"my_pets": [_pet("p1"), _pet("p1"), _pet("p1"), _pet("p2")]})
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    # Act
    resp = client.get("/pets/")

    # Assert
    assert resp.status_code == 200
    ids = [p["id"] for p in resp.json()]
    assert ids == ["p1", "p2"]


def test_lista_vacia_si_el_usuario_no_tiene_mascotas(client, fake_supabase, monkeypatch):
    monkeypatch.setattr(pets_routes, "supabase_admin", fake_supabase({"my_pets": []}))
    resp = client.get("/pets/")
    assert resp.status_code == 200
    assert resp.json() == []


def test_mascota_inexistente_devuelve_404(client, fake_supabase, monkeypatch):
    monkeypatch.setattr(pets_routes, "supabase_admin", fake_supabase({"my_pets": None}))
    resp = client.get("/pets/no-existe")
    assert resp.status_code == 404
    assert resp.json()["error"] == "Mascota no encontrada"


# ════════════════════════════════════════════════════════════════════════════
# POST /pets/  — paso 5 del wizard (guardar)
# ════════════════════════════════════════════════════════════════════════════

def test_crear_mascota_inicia_en_home_y_guarda_telefono(client, fake_supabase, monkeypatch):
    db = fake_supabase({"pets": [_pet("nueva")], "profiles": [{"id": USER_ID}]})
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    resp = client.post("/pets/", json={"name": "Firulais", "phone": "+59171234567"})

    assert resp.status_code == 201
    assert resp.json()["status"] == "home"
    assert {"phone": "+59171234567"} in db.updates   # teléfono → profiles


def test_crear_mascota_falla_si_la_bd_no_inserta(client, fake_supabase, monkeypatch):
    monkeypatch.setattr(pets_routes, "supabase_admin", fake_supabase({"pets": []}))
    resp = client.post("/pets/", json={"name": "Firulais"})
    assert resp.status_code == 500
    assert resp.json()["error"] == "No se pudo registrar la mascota"


# ════════════════════════════════════════════════════════════════════════════
# PATCH /pets/{id}/status  — botón "PERDÍ A MI MASCOTA"
# ════════════════════════════════════════════════════════════════════════════

def test_marcar_como_perdida_guarda_coordenadas(client, fake_supabase, monkeypatch):
    db = fake_supabase({
        "pets": {"id": "p1"},                      # la mascota es del usuario
        "my_pets": _pet("p1", status="lost",
                        last_seen_lat=-17.3895, last_seen_lng=-66.1568),
    })
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    resp = client.patch("/pets/p1/status", json={
        "status": "lost", "last_seen_lat": -17.3895, "last_seen_lng": -66.1568,
    })

    assert resp.status_code == 200
    assert resp.json()["status"] == "lost"
    # Verificamos QUÉ se envió a la BD
    enviado = db.updates[0]
    assert enviado["status"] == "lost"
    assert enviado["last_seen_lat"] == -17.3895
    assert enviado["last_seen_lng"] == -66.1568
    assert "last_seen_at" in enviado


def test_volver_a_home_sella_hora_y_conserva_coordenadas(client, fake_supabase, monkeypatch):
    db = fake_supabase({"pets": {"id": "p1"}, "my_pets": _pet("p1", status="home")})
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    resp = client.patch("/pets/p1/status", json={"status": "home"})

    assert resp.status_code == 200
    enviado = db.updates[0]
    assert enviado["status"] == "home"
    assert "last_seen_at" in enviado          # inicia la ventana de 1 hora
    assert "last_seen_lat" not in enviado     # no borra la última ubicación


def test_no_puede_cambiar_estado_de_mascota_ajena(client, fake_supabase, monkeypatch):
    db = fake_supabase({"pets": None})        # no pertenece al usuario
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    resp = client.patch("/pets/ajena/status", json={"status": "lost"})

    assert resp.status_code == 404
    assert db.updates == []                   # nunca se llegó a actualizar


def test_estado_invalido_es_rechazado_antes_de_llegar_a_la_bd(client, fake_supabase, monkeypatch):
    db = fake_supabase({"pets": {"id": "p1"}})
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    resp = client.patch("/pets/p1/status", json={"status": "robado"})

    assert resp.status_code == 422
    assert db.updates == []


# ════════════════════════════════════════════════════════════════════════════
# GET /map/pets  — marcadores del mapa
# ════════════════════════════════════════════════════════════════════════════

COCHA = {"lat": -17.3895, "lng": -66.1568, "radius": 5000}


def _map_pet(pet_id, status, lat=-17.3895, lng=-66.1568, minutos=0, owner=USER_ID):
    hace = datetime.now(timezone.utc) - timedelta(minutes=minutos)
    return {"id": pet_id, "owner_id": owner, "name": pet_id, "status": status,
            "last_seen_lat": lat, "last_seen_lng": lng,
            "last_seen_at": hace.isoformat()}


@pytest.fixture
def mapa(client, fake_supabase, monkeypatch):
    """Configura la BD falsa del mapa y devuelve los ids visibles."""
    def _consultar(filas):
        monkeypatch.setattr(map_routes, "supabase_admin", fake_supabase({"pets": filas}))
        resp = client.get("/map/pets", params=COCHA)
        assert resp.status_code == 200
        return resp.json()
    return _consultar


def test_mapa_muestra_perdidas_aunque_sean_antiguas(mapa):
    visibles = mapa([_map_pet("perdida", "lost", minutos=60 * 24 * 3)])
    assert [p["id"] for p in visibles] == ["perdida"]


def test_mapa_muestra_home_recuperada_hace_menos_de_1_hora(mapa):
    visibles = mapa([_map_pet("recuperada", "home", minutos=20)])
    assert [p["id"] for p in visibles] == ["recuperada"]


def test_mapa_oculta_home_recuperada_hace_mas_de_1_hora(mapa):
    visibles = mapa([_map_pet("vieja", "home", minutos=90)])
    assert visibles == []


def test_mapa_excluye_mascotas_fuera_del_radio(mapa):
    # Quillacollo está a ~13 km de la plaza → fuera de 5 km
    visibles = mapa([
        _map_pet("cerca", "lost"),
        _map_pet("lejos", "lost", lat=-17.3920, lng=-66.2780),
    ])
    assert [p["id"] for p in visibles] == ["cerca"]


def test_mapa_marca_si_la_mascota_es_propia(mapa):
    visibles = mapa([
        _map_pet("mia", "lost"),
        _map_pet("de_otro", "lost", owner="otro-usuario"),
    ])
    por_id = {p["id"]: p["is_own"] for p in visibles}
    assert por_id == {"mia": True, "de_otro": False}


def test_mapa_rechaza_coordenadas_invalidas(client):
    resp = client.get("/map/pets", params={"lat": 200, "lng": 0})
    assert resp.status_code == 422
