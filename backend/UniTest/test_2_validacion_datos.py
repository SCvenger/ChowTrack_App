"""
TIPO 2 — Unit tests de VALIDACIÓN DE DATOS (parametrizados)

Probamos los schemas Pydantic de app/core/schemas.py, que son la "puerta
de entrada" del backend: si un dato inválido pasa aquí, llega a la BD.

Técnica: @pytest.mark.parametrize → una sola función de test se ejecuta
con muchos valores (válidos e inválidos), incluyendo valores LÍMITE.
"""

import pytest
from pydantic import ValidationError

from app.core.schemas import (
    PetCreateSchema,
    PetStatusUpdateSchema,
    UserRegisterSchema,
)


# ════════════════════════════════════════════════════════════════════════════
# Teléfono Bolivia (+591) — paso 4 del wizard de registro
# ════════════════════════════════════════════════════════════════════════════

@pytest.mark.parametrize("telefono", [
    "+59171234567",    # Entel / Tigo empieza con 6, 7 u 8
    "+591 71234567",   # con espacio
    "+59161234567",
    "+59181234567",
])
def test_telefono_boliviano_valido(telefono):
    pet = PetCreateSchema(name="Firulais", phone=telefono)
    assert pet.phone == telefono


@pytest.mark.parametrize("telefono", [
    "71234567",        # sin código de país
    "+59151234567",    # empieza con 5 (no es celular)
    "+5917123456",     # 7 dígitos (falta uno)
    "+591712345678",   # 9 dígitos (sobra uno)
    "+54 71234567",    # código de Argentina
    "+591 7123abcd",   # letras
])
def test_telefono_boliviano_invalido(telefono):
    with pytest.raises(ValidationError):
        PetCreateSchema(name="Firulais", phone=telefono)


# ════════════════════════════════════════════════════════════════════════════
# Datos de la mascota — paso 1 del wizard
# ════════════════════════════════════════════════════════════════════════════

@pytest.mark.parametrize("nombre, es_valido", [
    ("A", False),          # límite inferior - 1
    ("Bo", True),          # límite inferior (2)
    ("X" * 50, True),      # límite superior (50)
    ("X" * 51, False),     # límite superior + 1
], ids=["1_caracter", "2_caracteres", "50_caracteres", "51_caracteres"])
def test_longitud_del_nombre(nombre, es_valido):
    if es_valido:
        assert PetCreateSchema(name=nombre).name == nombre
    else:
        with pytest.raises(ValidationError):
            PetCreateSchema(name=nombre)


@pytest.mark.parametrize("edad, es_valido", [
    (-1, False), (0, True), (30, True), (31, False),
])
def test_rango_de_edad(edad, es_valido):
    if es_valido:
        assert PetCreateSchema(name="Luna", age_years=edad).age_years == edad
    else:
        with pytest.raises(ValidationError):
            PetCreateSchema(name="Luna", age_years=edad)


def test_campos_opcionales_pueden_omitirse():
    pet = PetCreateSchema(name="Rocky")
    assert pet.breed is None
    assert pet.age_years is None
    assert pet.phone is None


# ════════════════════════════════════════════════════════════════════════════
# Cambio de estado — botón "PERDÍ A MI MASCOTA"
# ════════════════════════════════════════════════════════════════════════════

@pytest.mark.parametrize("estado", ["home", "lost", "found"])
def test_estados_permitidos(estado):
    assert PetStatusUpdateSchema(status=estado).status == estado


@pytest.mark.parametrize("estado", ["perdido", "LOST", "deleted", ""])
def test_estados_no_permitidos(estado):
    with pytest.raises(ValidationError):
        PetStatusUpdateSchema(status=estado)


@pytest.mark.parametrize("lat, lng", [
    (-90.1, 0), (90.1, 0), (0, -180.1), (0, 180.1),
])
def test_coordenadas_fuera_de_rango_se_rechazan(lat, lng):
    with pytest.raises(ValidationError):
        PetStatusUpdateSchema(status="lost", last_seen_lat=lat, last_seen_lng=lng)


def test_marcar_perdida_con_coordenadas_de_cochabamba():
    payload = PetStatusUpdateSchema(
        status="lost", last_seen_lat=-17.3895, last_seen_lng=-66.1568
    )
    assert payload.last_seen_lat == -17.3895
    assert payload.last_seen_lng == -66.1568


# ════════════════════════════════════════════════════════════════════════════
# Registro de usuario
# ════════════════════════════════════════════════════════════════════════════

def test_registro_valido():
    user = UserRegisterSchema(email="dueno@chowtrack.com", password="123456")
    assert user.email == "dueno@chowtrack.com"


@pytest.mark.parametrize("email, password", [
    ("no-es-un-email", "123456"),     # email mal formado
    ("dueno@chowtrack.com", "12345"), # contraseña de 5 caracteres (mínimo 6)
])
def test_registro_invalido(email, password):
    with pytest.raises(ValidationError):
        UserRegisterSchema(email=email, password=password)
