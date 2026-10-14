"""
Unit tests — INICIO DE SESIÓN (POST /auth/login)

Se prueban dos cosas, sin Supabase real ni internet:
  1. Validación de datos (UserLoginSchema).
  2. Lógica del endpoint de login con Supabase FALSO.

El usuario puede entrar con su EMAIL o con su NOMBRE DE USUARIO.
Si usa el nombre de usuario, el backend primero busca su email en `profiles`.

Ejecutar:  pytest test_login.py
"""


import pytest

from app.core.schemas import UserLoginSchema

EMAIL = "maya@gmail.com"

def test_login():
    """Un logeo exitoso"""
    log = UserLoginSchema(identity = EMAIL, password= "misterio619")
    assert log.identity == "maya@gmail.com"
    assert log.password == ""


