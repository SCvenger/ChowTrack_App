# Cómo funciona UniTest, explicado con palabras sencillas

Este documento explica **cómo usar las pruebas**, **qué hace cada archivo**,
**cómo trabaja su código por dentro** y **cómo se conectan entre sí**, sin
entrar en tecnicismos. Al final hay una sección con **todos los comandos** y
qué hace cada uno.

**Contenido**
0. La idea en una frase
1. Guía paso a paso para usar las pruebas
2. El recorrido completo por dentro
3. Los archivos de configuración
4. `conftest.py`: el que prepara el escenario
5. Las pruebas, explicadas por dentro
6. `generar_reporte.py`: de las pruebas al PDF
7. Cómo se conecta todo
8. ¿Qué pasa si una prueba falla?
9. Comandos completos

---

## 0. La idea en una frase

> Tenemos un **revisor automático** (pytest) que toma pequeñas partes del
> backend de ChowTrack, les da datos de prueba y comprueba que respondan lo
> que esperamos. Al terminar, **anota todo** en reportes (HTML y PDF).

Una comparación útil: es como un **inspector de calidad en una fábrica**.
No espera a que el auto esté terminado para probarlo. Revisa **cada pieza por
separado** (los frenos, las luces, el motor). Si una pieza falla, se sabe
exactamente cuál fue.

---

## 1. Guía paso a paso para usar las pruebas

Sigue estos pasos en orden. **No necesitas tener el backend encendido, ni
internet, ni una cuenta de Supabase**: las pruebas funcionan solas.

### Paso 1: abrir la terminal

**Opción A, desde VS Code (recomendada):**
1. Abre la carpeta `ChowTrack_App` en VS Code.
2. En el menú, ve a **Terminal → New Terminal** (o presiona `` Ctrl + ` ``).
3. Abajo se abre una terminal de PowerShell.

**Opción B, desde Windows:**
1. Presiona la tecla Windows, escribe **PowerShell** y ábrelo.

### Paso 2: ir a la carpeta de las pruebas

Escribe esto y presiona Enter:

```powershell
cd C:\Users\leona\Integrador\ChowTrack_App\backend\UniTest
```

Para comprobar que estás en el lugar correcto, escribe `ls`. Deberías ver
archivos como `conftest.py`, `test_1_logica_pura.py` y `generar_reporte.py`.

### Paso 3: preparar el entorno (solo la primera vez)

> **En tu PC esto ya está hecho.** Solo hace falta si usas otra computadora
> o si borraste la carpeta `.venv`.

```powershell
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements-test.txt
```

El primer comando crea un "Python aparte" solo para las pruebas. El segundo
instala ahí las librerías necesarias. Espera a que termine (1 o 2 minutos).

**¿Cómo sé que ya está listo?** Si existe la carpeta `.venv`, ya está hecho
y puedes pasar al paso 4.

### Paso 4: correr las pruebas

```powershell
.venv\Scripts\python -m pytest
```

Verás algo así:

```
test_1_logica_pura.py::test_haversine_mismo_punto_es_cero PASSED      [  1%]
test_1_logica_pura.py::test_haversine_un_grado_de_latitud... PASSED   [  3%]
...
test_3_con_mocks.py::test_mapa_rechaza_coordenadas_invalidas PASSED   [100%]

============================= 66 passed in 1.80s ==============================
```

### Paso 5: entender el resultado

| Lo que ves | Qué significa |
|---|---|
| `PASSED` (verde) | La prueba salió bien: el código hizo lo esperado |
| `FAILED` (rojo) | La prueba encontró un error: el código **no** hizo lo esperado |
| `ERROR` | La prueba ni siquiera pudo empezar (falta algo, error al preparar) |
| `[ 45%]` | Cuánto avance lleva la ejecución |
| `66 passed in 1.80s` | **Resumen final**: 66 pruebas pasaron, en 1,8 segundos |

Si todo dice `passed`, **el backend se comporta como debe** en todo lo que
se probó.

Si algo falla, pytest muestra un bloque como este:

```
    def test_haversine_un_grado_de_latitud_son_111_km():
>       assert distancia == pytest.approx(50_000, abs=500)
E       assert 111194.9 == 50000 ± 500
```

- La línea con `>` es **dónde falló**.
- La línea con `E` (de *Error*) muestra **qué obtuvo** (111194.9) contra **qué esperaba** (50000).

### Paso 6: generar los reportes

```powershell
.venv\Scripts\python generar_reporte.py
```

Esto corre de nuevo todas las pruebas y, al final, muestra:

```
============================================================
Reportes generados en: ...\backend\UniTest\reportes
  - reporte_tests.html
  - cobertura_html/index.html
  - Reporte_QA_ChowTrack.pdf
============================================================
```

### Paso 7: revisar los reportes

```powershell
start reportes\reporte_tests.html
```
Se abre en el navegador. Arriba hay un resumen y abajo una fila por prueba.
**Haz clic en una fila** para ver su detalle. Los botones de arriba (*Passed*,
*Failed*...) filtran la lista.

```powershell
start reportes\cobertura_html\index.html
```
Se abre una tabla con el % de cobertura de cada archivo. **Haz clic en el
nombre de un archivo** para ver su código coloreado:
- **verde**: líneas que las pruebas sí ejecutaron,
- **rojo**: líneas que ninguna prueba recorrió.

```powershell
start reportes\Reporte_QA_ChowTrack.pdf
```
Se abre el PDF de 3 páginas: resumen, resultados por tipo, cobertura y el
detalle de cada prueba.

### Paso 8: entregar

Sube el archivo **`backend\UniTest\reportes\Reporte_QA_ChowTrack.pdf`** a la
plataforma. Para encontrarlo fácil:

```powershell
start reportes
```
Esto abre la carpeta en el Explorador de Windows; desde ahí puedes
arrastrar el PDF al navegador.

### Paso 9 (opcional): agregar una prueba nueva

Si el docente pide más pruebas, así se agrega una:

1. Abre el archivo del tipo que corresponda (por ejemplo `test_2_validacion_datos.py`).
2. Al final del archivo, escribe una función cuyo nombre **empiece con `test_`**:
   ```python
   def test_raza_demasiado_larga_se_rechaza():
       with pytest.raises(ValidationError):
           PetCreateSchema(name="Luna", breed="X" * 51)
   ```
3. Guarda el archivo (`Ctrl + S`).
4. Corre solo esa prueba para verificarla:
   ```powershell
   .venv\Scripts\python -m pytest -k raza_demasiado_larga
   ```
5. Si sale `PASSED`, vuelve a generar los reportes (paso 6). La prueba nueva aparecerá sola en el HTML y el PDF.

> No hace falta registrar la prueba en ningún lado: pytest encuentra
> automáticamente cualquier función que empiece con `test_` dentro de un
> archivo que empiece con `test_`.

### Paso 10 (opcional): que VS Code reconozca pytest

Si VS Code subraya en amarillo `import pytest` con el mensaje *"No se ha
podido resolver la importación"*, no es un error de las pruebas: VS Code está
mirando el Python equivocado. Para arreglarlo:

1. Presiona `Ctrl + Shift + P`.
2. Escribe **Python: Select Interpreter** y presiona Enter.
3. Elige **Enter interpreter path...** y pega:
   `C:\Users\leona\Integrador\ChowTrack_App\backend\UniTest\.venv\Scripts\python.exe`

---

## 2. El recorrido completo por dentro

Cuando ejecutas `generar_reporte.py`, pasa esto:

```
 PASO 1  Tú ejecutas generar_reporte.py
           │
 PASO 2  Este script le pide a pytest (el revisor) que empiece a trabajar
           │
 PASO 3  pytest lee sus "instrucciones de trabajo": pytest.ini y .coveragerc
           │
 PASO 4  pytest abre primero conftest.py, que prepara el escenario:
           │   - le dice dónde está el código del backend
           │   - pone una base de datos FALSA en lugar de Supabase
           │   - deja listas unas "herramientas" que los tests pueden pedir
           │
 PASO 5  pytest busca todos los archivos que empiezan con test_ y los corre:
           │   test_1_logica_pura.py
           │   test_2_validacion_datos.py
           │   test_3_con_mocks.py
           │
 PASO 6  Mientras tanto, un "contador" (pytest-cov) va marcando qué líneas
           │   del backend se ejecutaron
           │
 PASO 7  Al terminar, pytest escribe los resultados en archivos:
           │   reporte_tests.html, resultados.xml, cobertura_html/, cobertura.json
           │
 PASO 8  generar_reporte.py lee esos archivos y arma el PDF final
```

Algo importante: **los tests no cambian nada del código del backend**. Lo
usan tal como está, igual que lo usa la app. Lo único que se reemplaza, y
solo mientras corren las pruebas, es la conexión a la base de datos.

---

## 3. Los archivos de configuración (las "instrucciones de trabajo")

### `pytest.ini`: le dice al revisor cómo trabajar

```ini
[pytest]
testpaths = .
python_files = test_*.py
addopts = -v
filterwarnings =
    ignore:Using `httpx` with `starlette.testclient` is deprecated
```

Línea por línea:
- **`testpaths = .`**: "busca las pruebas en esta misma carpeta".
- **`python_files = test_*.py`**: "solo los archivos cuyo nombre empieza con `test_` son pruebas". Por eso `conftest.py` y `generar_reporte.py` no se ejecutan como pruebas.
- **`addopts = -v`**: "muéstrame el nombre de cada prueba y si pasó o no" (v = *verbose*, detallado).
- **`filterwarnings`**: "no me muestres este aviso". Es un mensaje interno de una librería que no tiene que ver con nuestro código y solo ensucia la pantalla.

### `.coveragerc`: le dice al contador qué archivos vigilar

```ini
[run]
include =
    */app/core/schemas.py
    */app/core/errors.py
    */app/routes/map.py
    */app/routes/pets.py
    */app/services/nose_sift.py
```

La **cobertura** responde a la pregunta: *"de todas las líneas de código,
¿cuántas llegaron a ejecutarse durante las pruebas?"*.

Este archivo dice: **"cuenta solo estos 5 archivos"**, que son los que
nuestras pruebas revisan. Si no lo hiciéramos, también contaría archivos
como el login (`auth.py`), que no tienen pruebas unitarias, y el porcentaje
no reflejaría lo que realmente se probó.

### `requirements-test.txt`: la lista de compras

Lista las librerías que hay que instalar para que todo funcione:
- **Las del backend** (`fastapi`, `pydantic`, `numpy`, `opencv`...), porque las pruebas necesitan poder abrir el código del backend.
- **Las de pruebas:**
  - `pytest`: el revisor.
  - `pytest-html`: el que escribe el reporte bonito en HTML.
  - `pytest-cov`: el contador de líneas (cobertura).
  - `fpdf2`: el que dibuja el PDF.

No están `supabase` ni `google-genai`, porque las pruebas **nunca se conectan
de verdad** a la base de datos ni a la IA.

### `.gitignore`: lo que no se sube a GitHub

Le dice a git que ignore la carpeta `.venv/` (las librerías instaladas, que
pesan mucho y cada quien instala en su PC) y algunos archivos temporales.

---

## 4. `conftest.py`: el que prepara el escenario

pytest abre este archivo **automáticamente y antes que nada**. Nadie tiene
que llamarlo. Es como el **utilero de un teatro**: antes de que salgan los
actores (las pruebas), deja el escenario armado.

Hace tres trabajos.

### Trabajo 1: decir dónde está el backend

```python
BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, BACKEND_DIR)
```

**En palabras simples:** "sube una carpeta desde donde estoy (de `UniTest/` a
`backend/`) y agrégala a la lista de lugares donde Python busca código".

Sin esto, cuando una prueba escribe `from app.routes.map import ...`, Python
respondería "no sé qué es `app`".

### Trabajo 2: poner una base de datos de mentira

```python
fake_db_module = types.ModuleType("app.database.supabase_client")
fake_db_module.supabase_anon = MagicMock(name="supabase_anon")
fake_db_module.supabase_admin = MagicMock(name="supabase_admin")
sys.modules["app.database.supabase_client"] = fake_db_module
```

**El problema:** el archivo real `app/database/supabase_client.py` se
conecta a Supabase **en cuanto alguien lo abre**. Eso necesita internet y
contraseñas, y en una prueba unitaria no queremos nada de eso.

**La solución, en palabras simples:**
1. Creamos un archivo "de cartón" con el mismo nombre (`app.database.supabase_client`).
2. Dentro ponemos dos objetos de mentira (`MagicMock`) con los mismos nombres que usa el backend: `supabase_anon` y `supabase_admin`. Un `MagicMock` acepta cualquier cosa que le pidas y no se queja.
3. Lo guardamos en `sys.modules`, que es como **la libreta donde Python anota los archivos que ya abrió**.

Después, cuando `pets.py` dice *"tráeme `supabase_admin`"*, Python revisa su
libreta, ve que "ya lo tiene abierto" y le entrega **el de cartón**. Nunca
llega a abrir el real.

```
 Normalmente:    pets.py  ──pide──►  supabase_client.py real  ──►  Supabase en internet
 En las pruebas: pets.py  ──pide──►  versión de cartón        ──►  (no pasa nada)
```

### Trabajo 3: dejar listas las herramientas (fixtures)

Una **fixture** es una herramienta que una prueba puede pedir **solo
escribiendo su nombre entre los paréntesis**. pytest ve el nombre, prepara
la herramienta y se la entrega.

```python
def test_algo(client, fake_supabase):   # ← pytest ve estos nombres y los entrega
```

Aquí se definen dos herramientas.

#### Herramienta `fake_supabase`: una base de datos falsa que sí responde

El `MagicMock` del trabajo 2 evita la conexión, pero no devuelve datos
útiles. Para las pruebas del tipo 3 necesitamos una base de datos falsa que
**responda lo que nosotros queramos**. Para eso hay dos clases:

**`FakeSupabase`, la base de datos de mentira:**

```python
class FakeSupabase:
    def __init__(self, tables: dict):
        self.tables = tables
        self.updates: list[dict] = []

    def table(self, name):
        return FakeQuery(self.tables.get(name), self.updates)
```

- Al crearla le damos un diccionario con "lo que tiene cada tabla". Por ejemplo, `{"pets": [...], "my_pets": [...]}`.
- `self.updates` es un **cuaderno vacío** donde se anotará todo lo que el backend intente guardar.
- Cuando el backend pide una tabla (`.table("pets")`), le devuelve una consulta (`FakeQuery`) que ya trae los datos de esa tabla.

**`FakeQuery`, la consulta de mentira:**

El backend consulta Supabase encadenando pasos, así:

```python
supabase_admin.table("pets").select("*").eq("id", x).eq("owner_id", y).execute()
```

`FakeQuery` imita esto con un truco:

```python
def __getattr__(self, _name):
    return lambda *args, **kwargs: self
```

**En palabras simples:** "no importa qué paso me pidas (`select`, `eq`,
`order`, `maybe_single`...), digo que sí y me devuelvo a mí mismo". Así la
cadena de pasos nunca se rompe, sea larga o corta.

Hay tres pasos con comportamiento especial:
- **`execute()`**: es el paso final. Entrega los datos que el test configuró, envueltos igual que lo hace Supabase (en `.data`).
- **`update(payload)`**: cuando el backend intenta guardar algo, **lo anota en el cuaderno** (`updates`). Así la prueba puede revisar después *qué* se intentó guardar.
- **`not_`**: el mapa usa `.not_.is_(...)` sin paréntesis después de `not_`. Por eso `not_` se define como la misma consulta.

#### Herramienta `client`: un navegador de mentira

```python
app = FastAPI()
app.add_exception_handler(ChowTrackException, global_exception_handler)
app.include_router(pets_routes.router)
app.include_router(map_routes.router)
app.dependency_overrides[get_current_user_id] = lambda: USER_ID
return TestClient(app)
```

Línea por línea, en palabras simples:
1. **`FastAPI()`**: arma una mini versión del backend, vacía.
2. **`add_exception_handler`**: le enseña a responder los errores igual que el backend real (con `{"success": false, "error": ...}`).
3. **`include_router(...)`**: le agrega solo las rutas de **mascotas** y **mapa**, que son las que vamos a probar.
4. **`dependency_overrides`**: normalmente cada ruta pide "¿quién es el usuario?" y lo averigua revisando el token con Supabase. Aquí le decimos: **"no revises nada, el usuario siempre es `user-123`"**. Es como entrar con un pase VIP de prueba.
5. **`TestClient(app)`**: entrega un "navegador de mentira" que puede hacer peticiones (`client.get(...)`, `client.post(...)`, `client.patch(...)`) **sin encender ningún servidor**. La petición va directo al código, en memoria.

---

## 5. Las pruebas, explicadas por dentro

Todas siguen la misma receta de 3 pasos, llamada **AAA**:

| Paso | Nombre | En palabras simples |
|---|---|---|
| 1 | **Arrange** (preparar) | Junto los ingredientes: datos de ejemplo |
| 2 | **Act** (actuar) | Llamo a la función que quiero probar |
| 3 | **Assert** (afirmar) | Compruebo que el resultado sea el esperado |

La palabra **`assert`** significa *"aseguro que esto es verdad"*. Si no lo
es, la prueba **falla** y pytest muestra qué esperaba y qué obtuvo.

---

### 5.1 `test_1_logica_pura.py`: probar cálculos

**Qué son:** funciones que reciben números o textos y devuelven un resultado,
como una calculadora. No usan base de datos ni internet, así que no necesitan
herramientas especiales.

#### Ejemplo A: la distancia entre dos puntos (`_haversine`)

En el backend, esta función calcula **cuántos metros hay entre el usuario y
una mascota**. El mapa la usa para decidir si la mascota está dentro del
radio de 5 km.

```python
def test_haversine_un_grado_de_latitud_son_111_km():
    lat2 = COCHA_LAT + 1                                           # preparar
    distancia = _haversine(COCHA_LAT, COCHA_LNG, lat2, COCHA_LNG)  # actuar
    assert distancia == pytest.approx(111_195, abs=500)            # afirmar
```

**En palabras simples:** "si me muevo 1 grado hacia el norte desde la plaza
de Cochabamba, la función debería decir unos 111 km". Es un dato de geografía
conocido.

`pytest.approx(111_195, abs=500)` significa *"aproximadamente 111.195 metros,
con 500 metros de margen"*. Se usa porque los cálculos con decimales nunca
dan un número exacto.

Las otras pruebas de distancia comprueban que:
- de un punto al mismo punto hay **0 metros**,
- la distancia **de A a B es igual que de B a A**,
- una mascota a ~1 km **sí entra** en el radio de 5 km.

#### Ejemplo B: la regla de 1 hora del pin verde (`_within_last_hour`)

En el backend, cuando una mascota vuelve a casa (`home`), su pin verde
aparece en el mapa **solo durante 1 hora**. Esta función responde
*"¿esta fecha fue hace menos de 1 hora?"*.

```python
NOW = datetime(2026, 10, 7, 12, 0, 0, tzinfo=timezone.utc)

def test_hace_10_minutos_esta_dentro_de_la_hora():
    ts = (NOW - timedelta(minutes=10)).isoformat()
    assert _within_last_hour(ts, NOW) is True
```

**En palabras simples:** "si son las 12:00 y la mascota volvió a las 11:50,
¿el pin debe verse? Sí".

**¿Por qué usamos una hora fija (`NOW`) y no la hora real?** Porque así la
prueba da **siempre el mismo resultado**, la corras hoy o dentro de un año.

Se prueban los casos clave:
- **hace 10 minutos** → se muestra,
- **hace 2 horas** → ya no se muestra,
- **justo 1 hora** → se muestra (es el límite, y los límites son donde más errores aparecen),
- **fecha con "Z" al final** (el formato en que la entrega Supabase) → la entiende,
- **fecha sin zona horaria** → la trata como hora UTC.

Además, `@pytest.mark.parametrize` repite **una misma prueba** con 4 datos
basura (`None`, vacío, `"no-es-fecha"`, `"2026-99-99"`) para comprobar que la
función **no se rompe** y responde `False`.

#### Ejemplo C: la huella nasal (`nose_sift`)

```python
def test_serializar_y_deserializar_huella_no_pierde_datos():
    rng = np.random.default_rng(42)
    keypoints = rng.random((50, 2), dtype=np.float32)
    descriptores = rng.random((50, 128), dtype=np.float32)

    texto = nose_sift.serialize_features(keypoints, descriptores)
    kp2, des2 = nose_sift.deserialize_features(texto)

    np.testing.assert_array_equal(kp2, keypoints)
    np.testing.assert_array_equal(des2, descriptores)
```

**En palabras simples:** la huella nasal son muchos números. Para guardarla
en la base de datos, el backend la **convierte en texto** y, al leerla, la
**vuelve a convertir en números**. Esta prueba verifica que en esa ida y
vuelta **no se pierda ni cambie ningún número**, porque si eso pasara, las
huellas guardadas no coincidirían nunca.

`default_rng(42)` genera números "al azar", pero siempre los mismos (el 42
es como una semilla). Así la prueba es repetible.

La última prueba, `test_misma_huella_supera_umbral_y_distinta_no`, simula:
- **la misma nariz fotografiada un poco movida** → el puntaje debe superar `2.2015` (es un match),
- **una nariz totalmente distinta** → el puntaje debe quedar por debajo (no es un match).

Es una versión en miniatura de lo que hace la biometría real.

---

### 5.2 `test_2_validacion_datos.py`: probar los filtros de entrada

**Qué son:** los *schemas* del backend (`app/core/schemas.py`) son como el
**guardia de la puerta**: revisan cada dato que llega desde la app y
rechazan los que no cumplen las reglas. Estas pruebas comprueban que el
guardia deje pasar los datos correctos y **detenga los incorrectos**.

#### La herramienta clave: `@pytest.mark.parametrize`

En vez de escribir 6 pruebas casi iguales, se escribe **una sola** y se le
pasa una lista de datos. pytest la repite con cada uno:

```python
@pytest.mark.parametrize("telefono", [
    "71234567",        # sin código de país
    "+59151234567",    # empieza con 5 (no es celular)
    "+5917123456",     # le falta un dígito
    ...
])
def test_telefono_boliviano_invalido(telefono):
    with pytest.raises(ValidationError):
        PetCreateSchema(name="Firulais", phone=telefono)
```

**En palabras simples:** "intenta registrar a Firulais con cada uno de estos
teléfonos malos. **Espero que el guardia lo rechace** (`ValidationError`)".

`with pytest.raises(...)` funciona al revés de lo normal: la prueba **pasa
si el error ocurre** y **falla si el dato malo logra entrar**.

#### Valores límite

```python
@pytest.mark.parametrize("nombre, es_valido", [
    ("A", False),          # 1 letra    → muy corto
    ("Bo", True),          # 2 letras   → el mínimo permitido
    ("X" * 50, True),      # 50 letras  → el máximo permitido
    ("X" * 51, False),     # 51 letras  → se pasa por uno
], ids=["1_caracter", "2_caracteres", "50_caracteres", "51_caracteres"])
```

**En palabras simples:** si la regla dice "entre 2 y 50 letras", los errores
de programación casi siempre están **justo en los bordes** (por ejemplo, poner
`<` en vez de `<=`). Por eso se prueba el valor justo debajo, justo en el
borde y justo encima. Se hace lo mismo con la edad (-1, 0, 30, 31).

`ids=[...]` solo pone **nombres legibles** a cada caso en el reporte, para
que no aparezca `XXXXXXXXXX...`.

#### Qué más se revisa
- **Estados:** solo se aceptan `home`, `lost` y `found`. `"perdido"`, `"LOST"` (en mayúsculas) o un texto vacío se rechazan.
- **Coordenadas:** la latitud debe estar entre -90 y 90 y la longitud entre -180 y 180. Fuera de eso no existe ese lugar en la Tierra.
- **Registro:** el email debe tener formato de email y la contraseña al menos 6 caracteres.

---

### 5.3 `test_3_con_mocks.py`: probar las rutas con una base de datos falsa

**Qué son:** aquí se prueban las rutas completas del backend (lo que la app
llama por internet), como `GET /pets/` o `PATCH /pets/{id}/status`. Esas
rutas **hablan con Supabase**, así que usamos la base de datos de mentira
del `conftest.py`.

**Un "mock"** es un **doble de acción**: en las escenas peligrosas de una
película, no actúa la estrella sino un doble que se ve igual. Aquí, en vez de
la base de datos real, actúa un doble que responde lo que le indicamos.

#### Ejemplo completo: el botón "PERDÍ A MI MASCOTA"

```python
def test_marcar_como_perdida_guarda_coordenadas(client, fake_supabase, monkeypatch):
    db = fake_supabase({
        "pets": {"id": "p1"},
        "my_pets": _pet("p1", status="lost",
                        last_seen_lat=-17.3895, last_seen_lng=-66.1568),
    })
    monkeypatch.setattr(pets_routes, "supabase_admin", db)

    resp = client.patch("/pets/p1/status", json={
        "status": "lost", "last_seen_lat": -17.3895, "last_seen_lng": -66.1568,
    })

    assert resp.status_code == 200
    assert resp.json()["status"] == "lost"
    enviado = db.updates[0]
    assert enviado["status"] == "lost"
    assert enviado["last_seen_lat"] == -17.3895
    assert enviado["last_seen_lng"] == -66.1568
    assert "last_seen_at" in enviado
```

**Qué pasa, paso a paso:**

1. **pytest entrega las herramientas.** Ve `client`, `fake_supabase` y `monkeypatch` entre los paréntesis y las prepara. Las dos primeras vienen de `conftest.py`; `monkeypatch` viene incluida en pytest.

2. **Se arma la base de datos falsa** con dos tablas:
   - en `pets` hay una mascota `p1` (así el backend creerá que es del usuario),
   - en `my_pets` está cómo queda la mascota después del cambio.

3. **Se hace el cambiazo con `monkeypatch`.** Dentro de `pets.py`, la variable `supabase_admin` ahora apunta a **nuestra base de datos falsa**. `monkeypatch` es como un **cambio temporal**: cuando la prueba termina, deja todo como estaba, así una prueba no afecta a la siguiente.

4. **Se aprieta el botón.** `client.patch(...)` hace lo mismo que hace la app cuando el usuario toca "PERDÍ A MI MASCOTA": envía el nuevo estado y la ubicación GPS.

5. **El backend real hace su trabajo** sin saber que la base de datos es falsa:
   - revisa que los datos sean válidos (el guardia del punto 5.2),
   - pregunta quién es el usuario (respuesta: `user-123`, gracias al pase VIP),
   - pregunta si la mascota es suya (la base falsa dice que sí),
   - **guarda** el estado y las coordenadas (la base falsa **lo anota en el cuaderno**),
   - devuelve la mascota actualizada.

6. **Se revisan los resultados:**
   - la respuesta fue `200` (todo bien),
   - la mascota ahora dice `lost`,
   - **se abre el cuaderno** (`db.updates[0]`) para comprobar que el backend intentó guardar exactamente esas coordenadas y la hora (`last_seen_at`).

Este último punto es lo más valioso: **no solo vemos qué respondió el
backend, sino qué intentó guardar en la base de datos**.

#### Las demás pruebas de este archivo

| Prueba | Qué simula | Qué comprueba |
|---|---|---|
| `test_lista_de_mascotas_sin_duplicados` | La base devuelve la misma mascota 3 veces (por sus 3 fotos nasales) | La app recibe **una sola vez** cada mascota |
| `test_lista_vacia_si_el_usuario_no_tiene_mascotas` | Usuario nuevo sin mascotas | Responde una lista vacía, sin errores |
| `test_mascota_inexistente_devuelve_404` | Se pide una mascota que no existe | Responde 404 "Mascota no encontrada" |
| `test_crear_mascota_inicia_en_home_y_guarda_telefono` | Último paso del wizard de registro | La mascota nace "en casa" y el teléfono se guarda en el perfil |
| `test_crear_mascota_falla_si_la_bd_no_inserta` | La base de datos no guarda nada | Responde 500 con un mensaje claro |
| `test_volver_a_home_sella_hora_y_conserva_coordenadas` | El dueño encuentra a su mascota | Guarda la hora (para el pin verde de 1 hora) y **no borra** la última ubicación |
| `test_no_puede_cambiar_estado_de_mascota_ajena` | Alguien intenta marcar como perdida una mascota que no es suya | Responde 404 y **el cuaderno queda vacío**: nunca se intentó guardar nada |
| `test_estado_invalido_es_rechazado_antes_de_llegar_a_la_bd` | Se envía el estado "robado" | Responde 422 y la base de datos ni se toca |

#### Las pruebas del mapa y la herramienta `mapa`

Dentro de este archivo hay una herramienta propia:

```python
@pytest.fixture
def mapa(client, fake_supabase, monkeypatch):
    def _consultar(filas):
        monkeypatch.setattr(map_routes, "supabase_admin", fake_supabase({"pets": filas}))
        resp = client.get("/map/pets", params=COCHA)
        assert resp.status_code == 200
        return resp.json()
    return _consultar
```

**En palabras simples:** es un **atajo**. Le das una lista de mascotas y él
solo arma la base de datos falsa, hace el cambiazo, abre el mapa centrado en
Cochabamba con radio de 5 km y te devuelve **qué mascotas aparecieron**.

Así cada prueba del mapa ocupa pocas líneas:

```python
def test_mapa_oculta_home_recuperada_hace_mas_de_1_hora(mapa):
    visibles = mapa([_map_pet("vieja", "home", minutos=90)])
    assert visibles == []
```

*"Si una mascota volvió a casa hace 90 minutos, el mapa debe salir vacío."*

La función auxiliar `_map_pet(...)` crea una mascota de ejemplo. Por
defecto la pone en la plaza de Cochabamba, a nombre de nuestro usuario y con
la hora actual, y se pueden cambiar esos datos (`minutos=90`, `lat=...`,
`owner="otro-usuario"`).

Lo que se comprueba del mapa:
- una mascota **perdida** aparece siempre, aunque lleve 3 días perdida,
- una mascota que **volvió a casa hace 20 min** aparece (pin verde),
- una que **volvió hace 90 min** ya no aparece,
- una mascota en **Quillacollo** (~13 km) **no aparece** con un radio de 5 km,
- el campo `is_own` marca correctamente **cuál es mía y cuál es de otro**,
- coordenadas imposibles (latitud 200) se rechazan con un 422.

---

## 6. `generar_reporte.py`: de las pruebas al PDF

Este script hace **tres trabajos en orden**.

### Trabajo 1: `ejecutar_tests()`, correr las pruebas pidiendo reportes

Llama a pytest como si lo escribieras tú en la terminal, pero agregando
opciones para que **deje todo por escrito**:

| Opción | Qué le pide a pytest |
|---|---|
| `--html=reportes/reporte_tests.html` | Escribe una página web con el resultado de cada prueba |
| `--self-contained-html` | Que esa página sea **un solo archivo** (fácil de enviar) |
| `--junitxml=reportes/resultados.xml` | Una lista ordenada de resultados que otro programa pueda leer |
| `--cov` | Enciende el contador de líneas |
| `--cov-config=.coveragerc` | Usa las reglas de `.coveragerc` (solo los 5 archivos) |
| `--cov-report=html:...` | Escribe la cobertura como página web |
| `--cov-report=json:...` | Escribe la cobertura como datos para el PDF |
| `--cov-report=term` | Muestra la tabla de cobertura en la terminal |

### Trabajo 2: `leer_resultados()`, leer lo que escribió pytest

- Abre `resultados.xml` y recorre cada prueba. Por cada una arma una ficha con su archivo, su nombre, cuánto tardó y su estado. Si dentro encuentra una marca de falla, la ficha dice **FALLÓ**; si no, dice **PASÓ**.
- Abre `cobertura.json` y obtiene el porcentaje total y el de cada archivo.

### Trabajo 3: `generar_pdf()`, dibujar el PDF

Usa la librería **fpdf2**, que funciona como **dibujar en una hoja**: "pon
este texto aquí, con esta letra, en este color; ahora dibuja una celda;
ahora salta de línea".

La clase `PDF` define elementos que se repiten:
- **`header`**: el texto gris arriba a la derecha de cada página.
- **`footer`**: "Página X/Y" abajo.
- **`titulo`**: títulos azules con una línea debajo.
- **`fila_dato`**: una fila "Etiqueta: valor" (por ejemplo, "Total de tests: 66").
- **`tabla`**: dibuja una tabla celda por celda, con colores (verde para PASÓ, rojo para FALLÓ).

Después arma las secciones:
1. **Resumen**: cuenta cuántas pruebas pasaron y cuántas fallaron. Si ninguna falló escribe **APROBADO** en verde; si alguna falló, **CON FALLAS** en rojo.
2. **Resultados por tipo**: agrupa las pruebas por archivo usando el diccionario `TIPOS`, que traduce `test_1_logica_pura` a "Tipo 1 - Lógica pura".
3. **Cobertura por módulo**: un archivo por fila, en verde si tiene 70 % o más y en rojo si tiene menos.
4. **Detalle de cada test**: la lista completa, prueba por prueba.
5. **Detalle de fallos**: **solo aparece si algo falló** y muestra el mensaje de error.

Dos funciones pequeñas de ayuda:
- **`txt()`**: las letras básicas del PDF no saben dibujar ciertos símbolos (como emojis). Esta función los reemplaza para que el PDF no falle.
- **`corto()`**: si el nombre de una prueba es muy largo, lo recorta y agrega "..." para que quepa en la tabla.

Al final, el script **termina con el mismo resultado que pytest**: "todo
bien" si todo pasó y "hubo problemas" si algo falló.

---

## 7. Cómo se conecta todo (resumen)

| Archivo | ¿Quién lo usa? | ¿Qué usa él? |
|---|---|---|
| `pytest.ini` | pytest, al arrancar | — |
| `.coveragerc` | el contador de cobertura | — |
| `conftest.py` | pytest, automáticamente y antes que todo | el backend (`app/...`) |
| `test_1_logica_pura.py` | pytest | `map.py` y `nose_sift.py` del backend |
| `test_2_validacion_datos.py` | pytest | `schemas.py` del backend |
| `test_3_con_mocks.py` | pytest | las herramientas de `conftest.py` + `pets.py` y `map.py` |
| `generar_reporte.py` | tú | pytest → `resultados.xml` + `cobertura.json` → PDF |

---

## 8. ¿Qué pasa si una prueba falla?

Para probarlo, cambia un número en una prueba (por ejemplo, `111_195` por
`50_000` en `test_1_logica_pura.py`) y vuelve a correr todo:

1. En la terminal la prueba aparece en **rojo** con el mensaje *"esperaba 50000, obtuve 111195"*.
2. En `reporte_tests.html` aparece en rojo y, al hacer clic, se ve el detalle.
3. El PDF dice **CON FALLAS** en el resumen y agrega la sección **5. Detalle de fallos**.

> Esto sirve como demostración en la revisión: muestra que las pruebas
> **realmente detectan errores** y no pasan siempre. **Recuerda devolver el
> número original después** y volver a generar los reportes antes de entregar.

---

## 9. Comandos completos

> Todos se ejecutan en **PowerShell**, dentro de la carpeta `backend\UniTest`.

### 9.1 Ir a la carpeta

```powershell
cd C:\Users\leona\Integrador\ChowTrack_App\backend\UniTest
```
Te mueve a la carpeta de las pruebas. Todos los comandos siguientes asumen
que estás aquí.

### 9.2 Preparar el entorno (solo la primera vez)

```powershell
python -m venv .venv
```
Crea un **entorno virtual**: una carpeta `.venv` con un Python propio y
aislado, para que las librerías de las pruebas no se mezclen con las de tu
computadora. *(Ya está creado; solo hace falta si borras `.venv` o usas otra PC.)*

```powershell
.venv\Scripts\python -m pip install -r requirements-test.txt
```
Instala dentro del entorno virtual todas las librerías de la "lista de
compras". Tarda uno o dos minutos la primera vez.

### 9.3 Activar el entorno (opcional, para escribir menos)

```powershell
.venv\Scripts\Activate.ps1
```
"Enciende" el entorno virtual. Verás `(.venv)` al inicio de la línea. A
partir de ahí puedes escribir solo `python` o `pytest`, en vez de
`.venv\Scripts\python -m pytest`.

> Si PowerShell responde *"la ejecución de scripts está deshabilitada"*,
> ejecuta una vez: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
> y responde `S`.

```powershell
deactivate
```
"Apaga" el entorno virtual cuando termines.

> En los comandos de abajo se muestra la forma larga
> (`.venv\Scripts\python -m pytest`), que funciona **siempre**, esté activado
> o no el entorno. Si lo activaste, puedes escribir solo `pytest ...`.

### 9.4 Correr las pruebas

```powershell
.venv\Scripts\python -m pytest
```
Corre **todas** las pruebas y muestra cada una con PASSED o FAILED.

```powershell
.venv\Scripts\python -m pytest -q
```
Igual, pero en modo **resumido** (q = *quiet*, silencioso): solo puntitos y el total.

```powershell
.venv\Scripts\python -m pytest test_1_logica_pura.py
```
Corre **un solo archivo**. Útil para mostrar un tipo de prueba a la vez.

```powershell
.venv\Scripts\python -m pytest test_3_con_mocks.py::test_marcar_como_perdida_guarda_coordenadas
```
Corre **una sola prueba**: el nombre del archivo, `::` y el nombre de la prueba.

```powershell
.venv\Scripts\python -m pytest -k mapa
```
Corre solo las pruebas cuyo nombre **contiene la palabra** "mapa"
(k = *keyword*, palabra clave). Prueba también `-k telefono` o `-k haversine`.

```powershell
.venv\Scripts\python -m pytest -x
```
**Se detiene en la primera falla** (x = salir). Útil cuando algo se rompió y
quieres ir directo al primer problema.

```powershell
.venv\Scripts\python -m pytest --lf
```
Vuelve a correr **solo las pruebas que fallaron la última vez** (lf = *last failed*).

```powershell
.venv\Scripts\python -m pytest --durations=5
```
Al final muestra **las 5 pruebas más lentas**.

### 9.5 Cobertura en la terminal (sin generar archivos)

```powershell
.venv\Scripts\python -m pytest --cov --cov-config=.coveragerc --cov-report=term-missing
```
Corre las pruebas y muestra una tabla con el **% de cobertura de cada
archivo**. La columna `Missing` indica **qué números de línea** no se
probaron.

### 9.6 Generar todos los reportes (HTML + PDF)

```powershell
.venv\Scripts\python generar_reporte.py
```
**El comando principal para la entrega.** Corre todas las pruebas y crea en
`reportes\`:
- `reporte_tests.html`: resultado de cada prueba,
- `cobertura_html\index.html`: cobertura línea por línea,
- `Reporte_QA_ChowTrack.pdf`: el resumen para subir a la plataforma,
- `resultados.xml` y `cobertura.json`: los datos crudos que usa el PDF.

### 9.7 Abrir los reportes

```powershell
start reportes\reporte_tests.html
```
Abre el reporte de pruebas en tu navegador.

```powershell
start reportes\cobertura_html\index.html
```
Abre el reporte de cobertura. Haz clic en un archivo para ver **sus líneas
en verde** (probadas) y **en rojo** (no probadas).

```powershell
start reportes\Reporte_QA_ChowTrack.pdf
```
Abre el PDF con tu lector de PDF.

```powershell
start reportes
```
Abre la carpeta de reportes en el Explorador de Windows.

### 9.8 Limpieza (opcional)

```powershell
Remove-Item -Recurse -Force reportes, .pytest_cache, .coverage -ErrorAction SilentlyContinue
```
Borra los reportes y archivos temporales para empezar de cero. Se vuelven a
crear al correr `generar_reporte.py`.

### 9.9 Guion sugerido para la revisión

```powershell
cd C:\Users\leona\Integrador\ChowTrack_App\backend\UniTest
.venv\Scripts\python -m pytest test_1_logica_pura.py       # mostrar Tipo 1
.venv\Scripts\python -m pytest test_2_validacion_datos.py  # mostrar Tipo 2
.venv\Scripts\python -m pytest test_3_con_mocks.py         # mostrar Tipo 3
.venv\Scripts\python generar_reporte.py                    # generar reportes
start reportes\reporte_tests.html                          # mostrar HTML
start reportes\cobertura_html\index.html                   # mostrar cobertura
start reportes\Reporte_QA_ChowTrack.pdf                    # mostrar PDF
```
