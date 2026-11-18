# Pruebas de ChowTrack: cómo ejecutarlas y qué verifican

Última verificación: 18 de noviembre de 2026. Resultado: **112/112 en backend** y **22/22 en frontend**.

Todos los comandos son de **PowerShell** y parten de la raíz del proyecto
(`C:\Users\leona\Integrador\ChowTrack_App`). No hace falta internet, Supabase real
ni el emulador: las pruebas usan dobles (*mocks*) de la base de datos.

---

## 1. Comandos

### 1.1 Backend (pytest)

**Opción A: todos los reportes en un paso (la más simple para entregar)**

```powershell
cd backend\UniTest
.venv\Scripts\python.exe generar_reporte.py
```

**Opción B: los mismos comandos que usa el `Jenkinsfile`**

```powershell
cd backend\UniTest
New-Item -ItemType Directory -Force ..\..\.ci-reports\backend | Out-Null
.venv\Scripts\python.exe -m pytest -p no:cacheprovider `
  --junitxml=..\..\.ci-reports\backend\resultados.xml `
  --html=..\..\.ci-reports\backend\index.html --self-contained-html `
  --cov --cov-config=.coveragerc `
  --cov-report=html:..\..\.ci-reports\backend\cobertura --cov-report=term
```

**Opción C: solo ver el resultado en consola**

```powershell
cd backend\UniTest
.venv\Scripts\python.exe -m pytest                       # todas
.venv\Scripts\python.exe -m pytest test_login.py         # un archivo
.venv\Scripts\python.exe -m pytest -k "mapa"             # por nombre
```

> Si `.venv` no existe:
> `python -m venv .venv` y luego `.venv\Scripts\python.exe -m pip install -r requirements-test.txt`.

### 1.2 Frontend (flutter test)

```powershell
cd frontend
flutter test --no-pub                                    # solo consola
```

Con reporte guardado en archivo:

```powershell
cd frontend
New-Item -ItemType Directory -Force ..\.ci-reports\frontend | Out-Null
flutter test --no-pub --file-reporter json:..\.ci-reports\frontend\resultados.json |
  Tee-Object ..\.ci-reports\frontend\consola.txt
```

> Si es la primera vez o cambió `pubspec.yaml`, ejecuta antes `flutter pub get`.

---

## 2. Dónde quedan los reportes

| Reporte | Ubicación | Qué contiene | Lo genera |
|---|---|---|---|
| HTML de pruebas | `.ci-reports\backend\index.html` | Cada prueba con su resultado y duración | Opción B |
| JUnit XML | `.ci-reports\backend\resultados.xml` | Formato estándar que leen Jenkins y otras herramientas de CI | Opción B |
| Cobertura HTML | `.ci-reports\backend\cobertura\index.html` | % de líneas cubiertas, archivo por archivo | Opción B |
| HTML de pruebas | `backend\UniTest\reportes\reporte_tests.html` | Igual que el anterior | Opción A |
| Cobertura HTML | `backend\UniTest\reportes\cobertura_html\index.html` | Igual que el anterior | Opción A |
| **PDF de QA** | `backend\UniTest\reportes\Reporte_QA_ChowTrack.pdf` | Resumen por tipo de prueba, para entregar | Opción A |
| PDF de login | `backend\UniTest\reportes\login\Reporte_Login_<fecha>.pdf` | Detalle de `test_login.py` | Cualquier ejecución de pytest |
| PDF de registro | `backend\UniTest\reportes\registro_mascotas\Reporte_Registro_Mascotas_<fecha>.pdf` | Detalle de `test_registro_mascota.py` | Cualquier ejecución de pytest |
| JSON frontend | `.ci-reports\frontend\resultados.json` | Un evento por prueba (inicio, fin, resultado) | Comando con `--file-reporter` |
| Consola frontend | `.ci-reports\frontend\consola.txt` | La salida tal como se ve en la terminal | Comando con `Tee-Object` |

Para abrir un reporte: `start .ci-reports\backend\index.html`.

`.ci-reports\` y los PDF con fecha **no se suben a Git**; se generan de nuevo en cada ejecución.

---

## 3. Qué se prueba y por qué

### 3.1 Backend: 112 pruebas en 4 niveles

Las pruebas siguen una progresión: primero la lógica sin dependencias, luego la
validación de datos de entrada y por último los endpoints completos con la base
de datos simulada. Si falla una prueba de nivel bajo, el problema está en la
regla de negocio; si solo falla una de nivel alto, está en la integración.

#### `test_1_logica_pura.py`: 17 pruebas de lógica pura

Funciones que no dependen de red ni base de datos.

| Qué se prueba | Por qué importa |
|---|---|
| **Distancia Haversine** (4): mismo punto = 0, 1° de latitud ≈ 111 km, simetría y mascota dentro de 5 km | Decide qué mascotas perdidas aparecen en el mapa (`radius=5000`). Un error aquí muestra u oculta mascotas equivocadas. |
| **Regla de 1 hora** (9): 10 min sí se muestra, 2 h no, exactamente 1 h es el límite; formato `Z` de Supabase, fecha sin zona = UTC, 4 fechas inválidas devuelven `false` | Implementa la regla del pin verde: una mascota que vuelve a `home` se ve solo durante 1 hora. Supabase devuelve fechas en varios formatos y ninguno debe romper el mapa. |
| **Matching biométrico SIFT** (4): serializar/deserializar la huella sin pérdida, sin descriptores da lista vacía, pocos *matches* dan score 0, misma huella supera el umbral y una distinta no | Es el núcleo de la identificación por nariz. Comprueba que `MATCH_THRESHOLD = 2.2015` separa a la misma mascota de otra distinta. |

#### `test_2_validacion_datos.py`: 34 pruebas de validación

Los esquemas Pydantic son la primera barrera contra datos incorrectos.

| Qué se prueba | Por qué importa |
|---|---|
| Teléfono boliviano: 4 válidos y 6 inválidos | El paso 4 del wizard exige el formato `+591 XXXXXXXX`; un número mal guardado impide contactar al dueño. |
| Nombre (4) y edad (4) en sus límites | Valores de frontera: el mínimo, el máximo y uno fuera de rango por cada lado. |
| Campos opcionales (1) | Raza, foto, etc. pueden omitirse sin error. |
| Estados permitidos (3) y no permitidos (4) | Solo existen `home`, `lost` y `found`; cualquier otro valor se rechaza antes de llegar a la BD. |
| Coordenadas fuera de rango (4) y marcar perdida en Cochabamba (1) | Latitud ∈ [-90, 90], longitud ∈ [-180, 180]. Usa las coordenadas reales de la demo. |
| Registro de usuario: 1 válido y 2 inválidos | Correo y contraseña mal formados no llegan a crear cuentas. |

#### `test_3_con_mocks.py`: 15 pruebas de endpoints con Supabase simulado

Se llama a los endpoints reales de FastAPI con `TestClient`. Supabase se reemplaza
por un doble en memoria (`conftest.py`) que devuelve datos controlados.

| Qué se prueba | Por qué importa |
|---|---|
| `GET /pets/` sin duplicados y lista vacía | Regla crítica del SDD: una fila por mascota aunque tenga 3 huellas nasales. |
| `GET /pets/{id}` inexistente da 404 | Error claro en vez de un fallo interno. |
| `POST /pets/` empieza en `home` y guarda el teléfono; si la BD no inserta, error controlado | Flujo del wizard de registro. |
| `PATCH /pets/{id}/status`: a `lost` guarda coordenadas; a `home` registra la hora y conserva la posición | Es el botón **"PERDÍ A MI MASCOTA"** y el regreso a casa (pin verde). |
| No se puede cambiar el estado de una mascota ajena | Seguridad: un usuario no puede marcar como perdida la mascota de otro. |
| Estado inválido se rechaza antes de la BD | No hay escrituras con datos basura. |
| `GET /map/pets`: perdidas siempre visibles, `home` reciente visible, `home` antigua oculta, fuera del radio excluida, marca si es propia y rechaza coordenadas inválidas | Todas las reglas de marcadores del mapa (sección 2.2 del SDD), comprobadas de punta a punta. |

#### `test_4_salud.py`: 38 pruebas del módulo Salud / carnet veterinario

| Qué se prueba | Por qué importa |
|---|---|
| Estado de vencimiento (5) y "hoy" en hora de Bolivia (2) | A las 2:00 UTC en Bolivia todavía es el día anterior; sin esto, las alertas de vacunas saldrían un día antes. |
| Vacuna renovada sin alerta, agrupación sin tildes ni mayúsculas, desparasitación interna/externa, estado global = el peor | Reglas para que los recordatorios no se dupliquen ni se contradigan. |
| Medicamento activo (4), recordatorios, edad en meses | Cálculos que se muestran en el resumen de salud. |
| Detección de tipo de archivo por firma (4) y formato no permitido = 415 | Valida el archivo por su contenido y no por la extensión, que se puede falsificar. |
| Fechas imposibles: vacuna en el futuro, refuerzo antes de la aplicación | Coherencia de los datos médicos. |
| Mascota de otro usuario = 404, `pet_id` inválido = 404 y no 500 | Seguridad y manejo correcto de errores. |
| CRUD de vacunas, perfil por defecto/upsert, PATCH vacío = 400, consulta de otra mascota = 422 | Contrato de la API del módulo. |
| Documento PNG con URL firmada; carnet compartido público, revocado y expirado; token inexistente = 404 | El enlace público del carnet debe dejar de funcionar al revocarse o expirar. |

#### `test_login.py`: 2 pruebas

| Qué se prueba | Por qué importa |
|---|---|
| El esquema conserva identidad y contraseña válidas | Se corrigió: antes esperaba una contraseña vacía y fallaba siempre. |
| Contraseña vacía genera `ValidationError` | Un login sin contraseña se rechaza en la validación. |

> Estas pruebas validan el **esquema** `UserLoginSchema`, no el endpoint completo de login.

#### `test_registro_mascota.py`: 6 pruebas

| Qué se prueba | Por qué importa |
|---|---|
| Datos válidos se aceptan; registro exitoso = **201** con estado `home` | Camino feliz del wizard. |
| Con teléfono lo guarda en el perfil; sin teléfono no toca el perfil | Paso 4 del wizard: no sobrescribir un teléfono ya registrado. |
| Datos inválidos = **422**; la BD no inserta = **500** | Respuestas de error correctas para cada caso. |

#### Cobertura: 83 %

Se mide solo sobre los 5 módulos que prueban estos tests (`.coveragerc`):
`schemas.py` 100 %, `map.py` 88 %, `pets.py` 81 %, `errors.py` 73 % y `nose_sift.py` 65 %.
Lo que falta en `nose_sift.py` es sobre todo carga de imágenes reales y casos de
error de OpenCV, que se verifican con los scripts de `backend/tests/`
(`registro.py`, `coincidencia.py`).

### 3.2 Frontend: 22 pruebas en 4 archivos

#### `health_module_test.dart`: 10 pruebas

| Qué se prueba | Por qué importa |
|---|---|
| `HealthFormat` (5): fechas sin corrimiento por zona horaria, días restantes, decimales con coma, fecha-hora con zona para la API, edad desde meses | Que la app muestre en formato boliviano lo mismo que calcula el backend. |
| Contratos JSON (2): `HealthSummary` y `HealthShare` | La app interpreta exactamente el JSON que envía el backend; si cambia un campo, la prueba lo detecta. |
| `HealthFormView` (3): al crear valida obligatorios y envía solo lo llenado; sin obligatorio no envía; al editar envía solo lo que cambió | Comportamiento real del formulario: evita peticiones incompletas o que borren datos. |

#### `ux_fixes_test.dart`: 9 pruebas

| Qué se prueba | Por qué importa |
|---|---|
| Validador de teléfono (3): acepta `+591 …`, acepta 8 dígitos o vacío y rechaza inválidos | Debe coincidir con la validación del backend. |
| Contraste WCAG AA ≥ 4.5:1 (5): verde, rojo, ámbar, azul y blanco sobre verde | Accesibilidad: los textos de estado (Protegido/Alerta, perdida) deben leerse bien. |
| Indicador de progreso anuncia "Paso X de Y" | Accesibilidad del wizard para lectores de pantalla. |

#### `pet_detail_view_test.dart`: 2 pruebas

| Qué se prueba | Por qué importa |
|---|---|
| `PetDetailView` en estado `home` y `lost` muestra encabezado, datos y acción | La pantalla de detalle se dibuja bien en los dos estados que controla el usuario. |

#### `widget_test.dart`: 1 prueba

| Qué se prueba | Por qué importa |
|---|---|
| La pantalla de acceso muestra "Bienvenido de vuelta", el botón "Iniciar sesión" y 2 campos | Reemplaza la prueba del contador que trae la plantilla de Flutter, que no tenía relación con ChowTrack. Es la primera pantalla de la demo. |

---

## 4. Límites

- Son **pruebas unitarias y de componentes**: no tocan la base de datos real,
  la red ni Gemini. Una prueba aprobada no garantiza que producción
  (`chowtrack.onrender.com`) esté funcionando.
- La validación con fotos reales de narices se hace aparte con
  `backend/tests/registro.py` y `coincidencia.py`.
- Las pruebas Flutter en Jenkins quedan en la consola; aún no se publica un reporte
  estructurado del frontend en Jenkins.

---

## 5. Ejecutar en Jenkins

El trabajo **`ChowTrack`** (Pipeline, `https://github.com/SCvenger/ChowTrack_App.git`,
rama `*/main`, `Jenkinsfile`) ejecuta lo mismo que la sección 1, en este orden:
preparar el entorno Python, pruebas backend, `flutter pub get` y pruebas frontend.

1. Abrir `http://localhost:8080/job/ChowTrack/` e iniciar sesión.
2. Pulsar **Construir ahora** (*Build Now*). Dura unos 5 minutos.
3. Revisar los resultados de la ejecución:

| Reporte | URL |
|---|---|
| Consola completa | `http://localhost:8080/job/ChowTrack/lastBuild/console` |
| Resultados JUnit (112) | `http://localhost:8080/job/ChowTrack/lastBuild/testReport/` |
| HTML de pruebas backend | `http://localhost:8080/job/ChowTrack/lastBuild/Pruebas_20backend/` |
| Cobertura backend | `http://localhost:8080/job/ChowTrack/lastBuild/Cobertura_20backend/` |
| Artefactos archivados | `http://localhost:8080/job/ChowTrack/lastBuild/artifact/` |

Jenkins necesita **más de 1 GiB libre** en el disco C:. Si no lo tiene, desconecta
el nodo `principal` y la ejecución queda en "Esperando por un ejecutor".

**Ejecución #2 (18/11/2026): SUCCESS en 5,2 min.** 112 pruebas de backend aprobadas
(JUnit), 22 de frontend aprobadas (consola) y reportes HTML y de cobertura publicados.
