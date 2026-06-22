# CLAUDE.md — ChowTrack System Design Document (SDD)
# Uso exclusivo de Claude Code para análisis, diagnóstico y corrección del proyecto.

---

## 🗂️ ESTRUCTURA DEL PROYECTO

```
ChowTrack_App/
└── chowtrack/
    ├── frontend/          ← Flutter app
    │   ├── lib/           ← Código Dart (RAÍZ PRINCIPAL)
    │   │   ├── main.dart
    │   │   ├── core/
    │   │   │   ├── config/api_config.dart
    │   │   │   ├── services/token_storage.dart
    │   │   │   └── theme/app_theme.dart
    │   │   └── features/
    │   │       ├── auth/
    │   │       ├── home/
    │   │       ├── map/
    │   │       ├── pets/
    │   │       ├── petRegistration/
    │   │       ├── profile/
    │   │       └── navigation/
    │   ├── android/
    │   └── pubspec.yaml
    └── backend/           ← FastAPI
        └── app/           ← Código Python (RAÍZ BACKEND)
            ├── main.py
            ├── core/
            │   ├── config.py
            │   ├── dependencies.py
            │   └── errors.py
            ├── routes/
            │   ├── auth.py
            │   ├── pets.py
            │   ├── map.py
            │   └── nose.py
            └── services/
                ├── nose_sift.py
                └── nose_gemini.py
```

---

## ⚙️ STACK TÉCNICO

### Frontend
- **Flutter SDK:** ^3.11.5 (Flutter 3.41.9, Dart 3.x)
- **Estado:** Provider + ChangeNotifier
- **HTTP:** dio o http package
- **Mapa:** flutter_map + Stadia Maps
- **GPS:** geolocator
- **Auth/DB:** supabase_flutter ^2.12.4

### Backend
- **Framework:** FastAPI + Python 3.11
- **Auth:** JWT propio (NO Supabase Auth directo)
- **BD:** Supabase PostgreSQL (via supabase-py)
- **IA:** google-genai==2.8.0 + opencv-python-headless
- **Deploy:** Render (chowtrack.onrender.com)

---

## 🚨 REGLAS CRÍTICAS — LEER ANTES DE TOCAR CUALQUIER ARCHIVO

### Flutter
```dart
// ❌ INCORRECTO — deprecado en Flutter 3.11.5
color.withOpacity(0.5)

// ✅ CORRECTO
color.withValues(alpha: 0.5)

// ❌ INCORRECTO — causa conflicto con latlong2
import 'package:latlong2/latlong.dart'; // Path colisiona

// ✅ CORRECTO
import 'package:latlong2/latlong.dart' hide Path;

// ❌ INCORRECTO — deprecado
onPopInvoked: (didPop) {}

// ✅ CORRECTO
onPopInvokedWithResult: (didPop, result) {}

// Dart 3.x: usar _ para parámetros no usados
// ❌ (didPop, result) {}
// ✅ (_, __) {}
```

### Backend
```python
# Auth: SIEMPRE usar HTTPBearer, nunca Header(...)
# ❌ INCORRECTO
async def endpoint(authorization: str = Header(...)):

# ✅ CORRECTO
from fastapi.security import HTTPBearer
bearer = HTTPBearer()
async def endpoint(credentials = Depends(bearer)):
```

### Base de datos
- Tabla de usuarios: `public.profiles` (NO `public.users`)
- Vista mascotas: `public.my_pets` (usa EXISTS, no LEFT JOIN)
- Nose embeddings: tabla `public.nose_embeddings` con `(pet_id, photo_index) UNIQUE`

---

## 🎯 FUNCIONES CRÍTICAS PARA LA DEFENSA

### PRIORIDAD 1 — HOME (`lib/features/home/`)

#### 1.1 Banner GPS — Estado del sistema
**Debe funcionar:**
- `Protegido` (verde) cuando GPS activo
- `Alerta` (naranja/rojo) cuando GPS inactivo
- **Cambio en tiempo real** sin reiniciar la app
- Se actualiza al volver de ajustes del sistema (`WidgetsBindingObserver`)

**Implementación correcta:**
```dart
// En PetsMapController o HomeController
Geolocator.getServiceStatusStream().listen((status) {
  _isGpsActive = status == ServiceStatus.enabled;
  notifyListeners();
});
```

**Verificar:** `_initFuture ??=` protege contra doble inicialización (IndexedStack monta todo a la vez)

#### 1.2 Botón "PERDÍ A MI MASCOTA"
**Flujo completo:**
1. Usuario toca el botón
2. Bottom sheet lista sus mascotas activas (estado `home`)
3. **Nav bar se oculta mientras el sheet está abierto** (si no, tapa las opciones)
4. Usuario selecciona mascota
5. App llama `PATCH /pets/{pet_id}/status` con:
   ```json
   {
     "status": "lost",
     "last_seen_lat": -17.3895,
     "last_seen_lng": -66.1568
   }
   ```
6. Backend actualiza BD + retorna mascota actualizada
7. App muestra snackbar roja: "Mascota marcada como perdida"
8. **Mapa se actualiza inmediatamente** con pin rojo

**Estados válidos que el USUARIO controla:**
- `home` → `lost` (perdió a su mascota)
- `lost` → `home` (la encontró él mismo)
- `found` → **SOLO el sistema lo asigna** (via match biométrico, futuro)

#### 1.3 Preview del mapa en Home
- Muestra un fragmento del mapa con el pin rojo de la mascota marcada como perdida
- No es interactivo (solo visual)
- Se actualiza tras `loadPetsNearby()` post-acción

---

### PRIORIDAD 2 — MAP (`lib/features/map/`)

#### 2.1 Ubicación del usuario
- Punto azul en la posición actual
- Se centra en la ubicación al abrir la pantalla
- Fallback a Cochabamba `-17.3895, -66.1568` si no hay GPS

**Tile URL de Stadia Maps:**
```dart
'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}@2x.png?api_key=${ApiConfig.stadiaApiKey}'
```

#### 2.2 Marcadores de mascotas perdidas
**Endpoint:** `GET /map/pets?lat=X&lng=Y&radius=5000`

**Lógica de marcadores por estado:**
```
lost  → marcador ROJO  (activo, en búsqueda)
home  → marcador VERDE (encontrado por el dueño, visible 1 hora desde updated_at)
found → NO aparece en mapa (es estado interno, genera notificación al dueño)
```

**Regla de 1 hora para marcador verde:**
```dart
// Mostrar en mapa si:
// - status == 'lost' → siempre
// - status == 'home' Y updated_at < hace 1 hora → mostrar verde
// - status == 'home' Y updated_at > hace 1 hora → NO mostrar
// - status == 'found' → NUNCA mostrar en mapa

bool shouldShowOnMap(MapPetSchema pet) {
  if (pet.status == 'lost') return true;
  if (pet.status == 'home') {
    final lastUpdate = DateTime.parse(pet.updatedAt ?? '');
    return DateTime.now().difference(lastUpdate).inHours < 1;
  }
  return false; // found u otros
}

Color markerColor(String status) {
  return status == 'lost' ? Colors.red : Colors.green;
}
```

#### 2.3 Filtros por estado
- Chip `Perdidos` → muestra solo `lost` (rojo)
- Chip `Encontrados` → muestra solo `home` recientes (verde, últimas 1h)
- Chip `Todos` → muestra ambos
- `found` nunca aparece en ningún filtro del mapa

---

### PRIORIDAD 3 — PETS (`lib/features/pets/`)

#### 3.1 Lista de mascotas
**Endpoint:** `GET /pets/` → usa vista `my_pets` en BD

**Regla crítica:** Una fila por mascota, SIN duplicados.
- La vista ya usa `EXISTS` en lugar de `LEFT JOIN`
- Si aparecen duplicados: problema en la vista de Supabase o en el modelo Dart

**Modelo esperado:**
```dart
class PetModel {
  final String id;
  final String name;
  final String? breed;
  final int? ageYears;
  final String? photoUrl;
  final String status; // 'home' | 'lost' | 'found'
  final bool hasNoseScan;
  final double? lastSeenLat;
  final double? lastSeenLng;
  final String? lastSeenAt;
  final String? createdAt;
}
```

#### 3.2 Wizard de registro (5 pasos)
```
Paso 1: Datos básicos (nombre, raza, edad)
Paso 2: Foto de la mascota
Paso 3: Escaneo nasal (simulado en Flutter, real en backend)
Paso 4: Teléfono Bolivia (+591 XXXXXXXX) — se omite si ya fue registrado
Paso 5: Resumen y guardar
```

**Flujo correcto al guardar:**
```dart
// ❌ INCORRECTO — crashea si no hay rutas nombradas
Navigator.pushReplacementNamed(context, '/home');

// ✅ CORRECTO
AuthController.markHasPets();
Navigator.pop(context); // si vino de PetsView
// main.dart detecta hasPets y muestra HomeShell automáticamente
```

**Flag de teléfono registrado:**
```dart
// token_storage.dart
await tokenStorage.markPhoneRegistered();  // guarda flag local
await tokenStorage.hasRegisteredPhone();   // consulta flag
// Se limpia en clearAll() al hacer logout
```

#### 3.3 Detalle de mascota
- Muestra todos los datos del pet
- Botón de estado: solo `home` ↔ `lost` (el usuario controla)
- `found` se asigna solo por match biométrico (backend) — no hay botón para esto

---

## 🔌 ENDPOINTS DEL BACKEND (PRODUCCIÓN)

**Base URL:** `https://chowtrack.onrender.com`
**Auth:** `Authorization: Bearer <token>` en cada request protegido

```
POST   /auth/register              → Registro de usuario
GET    /auth/check-verification    → Verificar email
POST   /auth/login                 → Login (devuelve access_token)
POST   /auth/refresh               → Renovar token

GET    /pets/                      → Mis mascotas
POST   /pets/                      → Crear mascota
GET    /pets/{pet_id}              → Detalle de mascota
PATCH  /pets/{pet_id}/status       → Cambiar estado (lost/home)

GET    /map/pets                   → Mascotas en mapa (lat, lng, radius)

POST   /nose/register              → Registrar huella nasal
POST   /nose/identify              → Identificar mascota por nariz
```

---

## 🗄️ BASE DE DATOS (Supabase)

### Tablas clave
```sql
public.profiles          -- Usuarios (NO public.users)
public.pets              -- Mascotas
public.nose_embeddings   -- Huellas nasales (hasta 3 ángulos por mascota)
public.sightings         -- Avistamientos
public.matches           -- Matches biométricos
public.chats             -- Chats post-match (futuro)
public.messages          -- Mensajes (futuro)
```

### Vista crítica
```sql
-- my_pets: una fila por mascota (usa EXISTS, no LEFT JOIN)
CREATE OR REPLACE VIEW public.my_pets AS
SELECT p.*, EXISTS(
  SELECT 1 FROM public.nose_embeddings ne WHERE ne.pet_id = p.id
) AS has_nose_scan
FROM public.pets p
WHERE p.is_active = TRUE AND p.owner_id = auth.uid();
```

### Estados de mascota
```
home  → en casa, no aparece en mapa
lost  → perdida, marcador ROJO en mapa
found → encontrada por biometría, NO en mapa, notificación al dueño (futuro)
```

---

## 🤖 SISTEMA BIOMÉTRICO

### Pipeline (backend)
```
Foto JPEG → Gemini 2.0 Flash (valida que es nariz) 
         → SIFT (extrae ~3000 keypoints)
         → FLANN (busca pares similares)
         → RANSAC (filtra inliers geométricos)
         → Score = inliers / sqrt(min_keypoints)
         → Score > MATCH_THRESHOLD → MATCH
```

### Configuración actual
```python
MODEL = "gemini-2.0-flash"        # 1500 req/día gratis
MATCH_THRESHOLD = 2.2015           # Calibrado: mismo=4.28, diferente=0.11
```

### Scores de referencia (calibración real)
```
Mismo perro (distintas fotos): 4.2889
Perro diferente:               0.1141
Threshold:                     2.2015
Separación:                    4.1748 (excelente)
```

---

## 🔍 DIAGNÓSTICO — QUÉ VERIFICAR

### Home
- [ ] `PetsMapController.initialize()` protegido con `_initFuture ??=`
- [ ] `Geolocator.getServiceStatusStream()` activo y escuchando
- [ ] `WidgetsBindingObserver` en HomeView: `refreshLocation()` al `resumed`
- [ ] Bottom sheet de mascotas: nav bar se oculta mientras está abierto
- [ ] Tras marcar como lost: `loadPetsNearby()` se llama inmediatamente

### Map
- [ ] `shouldShowOnMap()` implementado con regla de 1 hora para `home`
- [ ] `found` NUNCA aparece en el mapa
- [ ] Marcador rojo para `lost`, verde para `home` reciente
- [ ] Filtros de chips funcionando correctamente
- [ ] Fallback a Cochabamba si no hay GPS

### Pets
- [ ] Lista sin duplicados (verificar con 1 mascota que tiene 3 registros nasales)
- [ ] Wizard: paso 4 de teléfono omitido si `hasRegisteredPhone()` es true
- [ ] Wizard: `Navigator.pop()` al guardar, NO `pushReplacementNamed`
- [ ] Botón de estado en PetDetail: solo cambia entre `home` y `lost`

---

## 📋 CONTEXTO DE LA DEFENSA

**Fecha:** En 2 días
**Demostración prevista:**
1. Login con cuenta existente
2. Mostrar "Mis mascotas" (lista sin duplicados)
3. Desde Home: marcar mascota como perdida (con GPS activo)
4. Ver pin rojo en el mapa
5. Activar/desactivar GPS en tiempo real → banner cambia al instante
6. Volver a `home` → marcador verde en mapa por 1 hora
7. Demo biométrica (local, con tests de terminal si falla en app)

**Pendientes conocidos (NO bloquean la defensa):**
- `GET /profile/` no existe → ProfileView muestra "Sin nombre" (aceptado)
- Botón de acción en PetDetailView no funciona (usar botón del Home)
- Notificaciones (futuro)
- Chat en tiempo real (futuro)
- Login con Google deshabilitado (deep link no configurado)
- Estado `found` no tiene UI (solo backend, futuro)

---

## 🛠️ COMANDOS ÚTILES

```bash
# Flutter
cd chowtrack/frontend
flutter clean && flutter pub get
flutter run

# Backend local
cd chowtrack/backend
source env/bin/activate  # Linux/Mac
.\env\Scripts\activate   # Windows
uvicorn app.main:app --reload

# Tests biométricos
cd chowtrack/backend/tests
python registro.py
python coincidencia.py
python coincidencia.py --calibrar

# Verificar backend en producción
curl https://chowtrack.onrender.com/
curl https://chowtrack.onrender.com/openapi.json | python -m json.tool
```

---

## ⚠️ LO QUE NO SE DEBE CAMBIAR

1. **Nombres de tablas:** `profiles`, `pets`, `nose_embeddings` (no renombrar)
2. **Modelo de Auth:** JWT propio vía FastAPI (no migrar a Supabase Auth)
3. **MATCH_THRESHOLD:** 2.2015 (calibrado con datos reales)
4. **Modelo Gemini:** `gemini-2.0-flash` (1500/día gratis)
5. **Vista `my_pets`:** Debe usar `EXISTS`, no `LEFT JOIN`
6. **Flutter:** `withValues(alpha:)` siempre, nunca `withOpacity()`