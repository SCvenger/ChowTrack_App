# UniTest — Pruebas unitarias de ChowTrack (backend)

## ¿Qué es un unit test?

Un **unit test** prueba **una unidad pequeña de código** (una función, un
schema, un endpoint) **de forma aislada**: sin base de datos real, sin internet
y sin depender de otros módulos. Debe ser **rápido** (milisegundos),
**repetible** (siempre da el mismo resultado) e **independiente** (no depende
de otros tests).

Cada test sigue el patrón **AAA**:
1. **Arrange**: preparar los datos
2. **Act**: ejecutar la función
3. **Assert**: verificar el resultado

Framework usado: **pytest**, el estándar de facto en Python.

---

## Los 3 tipos de unit test

### Tipo 1 — Lógica pura (`test_1_logica_pura.py`)
**Qué es:** se prueban funciones que reciben datos y devuelven un resultado,
sin efectos externos. Es el unit test más básico y más común.

**Qué probamos en ChowTrack:**
- `_haversine()` → distancia en metros que decide si una mascota entra en el radio del mapa.
- `_within_last_hour()` → la **regla de 1 hora** del pin verde (`home`).
- `nose_sift` → serialización de huellas nasales y el puntaje de coincidencia contra `MATCH_THRESHOLD = 2.2015`.

**Por qué:** son cálculos donde un error no se ve a simple vista (un pin que
desaparece antes de tiempo, una mascota a 6 km que sí aparece). Se prueban
casos normales, **límites** (justo 1 hora) y entradas inválidas.

### Tipo 2 — Validación de datos, parametrizados (`test_2_validacion_datos.py`)
**Qué es:** se prueban las reglas de entrada (schemas Pydantic) con
`@pytest.mark.parametrize`, que corre **un mismo test con muchos valores**.
Usa la técnica de **valores límite** (mínimo−1, mínimo, máximo, máximo+1).

**Qué probamos en ChowTrack:**
- Teléfono boliviano `+591` (paso 4 del wizard).
- Nombre (2–50 caracteres) y edad (0–30) de la mascota.
- Estados permitidos `home | lost | found` y coordenadas válidas.
- Email y contraseña mínima en el registro.

**Por qué:** los schemas son la puerta de entrada del backend. Si un dato
inválido pasa aquí, termina guardado en Supabase.

### Tipo 3 — Con mocks / dobles de prueba (`test_3_con_mocks.py`)
**Qué es:** cuando el código depende de algo externo (BD, API), se reemplaza
por un **objeto falso (mock)** con datos controlados. Así se prueba solo la
lógica del endpoint, sin tocar la base real.

**Qué probamos en ChowTrack** (Supabase reemplazado por `FakeSupabase` en `conftest.py`):
- `GET /pets/` → la lista **no tiene duplicados** aunque la BD devuelva la misma mascota 3 veces.
- `POST /pets/` → la mascota nace en `home` y el teléfono se guarda en `profiles`.
- `PATCH /pets/{id}/status` → al marcar `lost` se guardan las coordenadas; no se puede modificar una mascota ajena.
- `GET /map/pets` → `lost` siempre visible, `home` solo 1 hora, respeta el radio, marca `is_own`.

**Por qué:** son las funciones de la demo (botón "PERDÍ A MI MASCOTA", mapa,
lista de mascotas). Con mocks las probamos en 2 segundos y sin depender de que
Render o Supabase estén en línea.

---

## Generación de reportes

Un reporte de pruebas deja **evidencia** de qué se probó y con qué resultado.
Generamos dos tipos de información:

| Reporte | Herramienta | Qué muestra |
|---|---|---|
| **Resultados** | `pytest-html` | Cada test: pasó/falló, duración, error si hubo |
| **Cobertura** | `pytest-cov` (coverage.py) | Qué % del código fue ejecutado por los tests, línea por línea |
| **PDF para entregar** | `fpdf2` (`generar_reporte.py`) | Resumen de ambos en un documento |

> **Cobertura**: si es 83 %, significa que el 83 % de las líneas de los
> módulos probados se ejecutaron durante los tests. Las líneas en rojo del
> reporte HTML son las que ningún test recorre.

---

## Cómo ejecutar

Desde `backend/UniTest` (PowerShell):

```powershell
# Solo la primera vez
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements-test.txt

# Correr los tests (rápido, en consola)
.venv\Scripts\python -m pytest

# Correr los tests + generar TODOS los reportes (HTML + PDF)
.venv\Scripts\python generar_reporte.py
```

Resultados en `reportes/`:
- `reporte_tests.html` → abrir en el navegador
- `cobertura_html/index.html` → abrir en el navegador
- `Reporte_QA_ChowTrack.pdf` → **para subir a la plataforma**

## Estructura

```
UniTest/
├── conftest.py               # Configuración común + Supabase falso + fixtures
├── test_1_logica_pura.py     # Tipo 1
├── test_2_validacion_datos.py# Tipo 2
├── test_3_con_mocks.py       # Tipo 3
├── generar_reporte.py        # Corre tests y genera HTML + PDF
├── pytest.ini / .coveragerc  # Configuración de pytest y cobertura
├── requirements-test.txt
└── reportes/                 # Salida generada
```
