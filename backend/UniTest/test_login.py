"""
Unit tests — INICIO DE SESIÓN (POST /auth/login)

Se valida el esquema UserLoginSchema sin Supabase real ni internet.
Estas pruebas no ejecutan el endpoint de inicio de sesión.

Ejecutar:  pytest test_login.py
"""


import pytest

from app.core.schemas import UserLoginSchema

EMAIL = "maya@gmail.com"

def test_login_schema_conserva_las_credenciales_validas():
    """El esquema conserva la identidad y la contraseña recibidas."""
    log = UserLoginSchema(identity=EMAIL, password="misterio619")
    assert log.identity == EMAIL
    assert log.password == "misterio619"


def test_login_schema_rechaza_contrasena_vacia():
    """Una contraseña vacía no cumple el contrato del esquema."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        UserLoginSchema(identity=EMAIL, password="")


