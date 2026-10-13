"""
conftest.py — Configuración compartida por todos los tests.

pytest carga este archivo ANTES que los tests. Aquí hacemos 3 cosas:
  1. Agregar la carpeta backend/ al path para poder hacer `import app...`
  2. Reemplazar el cliente real de Supabase por uno FALSO, para que los
     unit tests nunca toquen la base de datos real ni internet.
  3. Definir "fixtures" reutilizables (objetos que los tests piden por nombre).
"""

import os
import sys
import types
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

# ── 1. Path hacia backend/ ──────────────────────────────────────────────────
BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, BACKEND_DIR)

# ── 2. Supabase falso ───────────────────────────────────────────────────────
# El módulo real (app/database/supabase_client.py) se conecta a Supabase al
# importarse. Lo sustituimos en sys.modules por un módulo con MagicMocks.
fake_db_module = types.ModuleType("app.database.supabase_client")
fake_db_module.supabase_anon = MagicMock(name="supabase_anon")
fake_db_module.supabase_admin = MagicMock(name="supabase_admin")
sys.modules["app.database.supabase_client"] = fake_db_module


# ── 3. Fixtures ─────────────────────────────────────────────────────────────

class FakeQuery:
    """
    Imita la API encadenable de supabase-py:
        supabase.table("pets").select("*").eq("id", x).execute()
    Cualquier método devuelve la misma consulta y execute() devuelve `data`.
    Además guarda los payloads de update() para poder verificarlos.
    """

    def __init__(self, data, log):
        self._data = data
        self._log = log
        self.not_ = self  # para soportar .not_.is_(...)

    def update(self, payload):
        self._log.append(payload)
        return self

    def execute(self):
        return SimpleNamespace(data=self._data)

    def __getattr__(self, _name):
        return lambda *args, **kwargs: self


class FakeSupabase:
    """Cliente falso: cada tabla devuelve los datos que el test configure."""

    def __init__(self, tables: dict):
        self.tables = tables
        self.updates: list[dict] = []

    def table(self, name):
        return FakeQuery(self.tables.get(name), self.updates)


@pytest.fixture
def fake_supabase():
    """Fábrica: fake_supabase({'pets': [...]}) → FakeSupabase."""
    return FakeSupabase


USER_ID = "user-123"


@pytest.fixture
def client():
    """
    TestClient de FastAPI con solo los routers de pets y map.
    La autenticación se reemplaza (dependency_overrides) por un usuario fijo.
    """
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    from app.core.dependencies import get_current_user_id
    from app.core.errors import ChowTrackException, global_exception_handler
    from app.routes import map as map_routes
    from app.routes import pets as pets_routes

    app = FastAPI()
    app.add_exception_handler(ChowTrackException, global_exception_handler)
    app.include_router(pets_routes.router)
    app.include_router(map_routes.router)
    app.dependency_overrides[get_current_user_id] = lambda: USER_ID
    return TestClient(app)
