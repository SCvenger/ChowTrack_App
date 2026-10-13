# 🩺 Módulo Salud / Carnet Veterinario — Guía de integración (Frontend)

**Fecha:** 2026-10-13
**Alcance:** solo el lado del **dueño** (el veterinario únicamente *ve* el carnet por enlace/QR, sin cuenta).
**Estado:** backend implementado + BD migrada en Supabase (`ChowTrack-Backend`) + 38 tests en `UniTest/test_4_salud.py`.
**No toca nada existente:** `/pets`, `/map`, `/nose`, `/auth` siguen igual.

---

## 1. Qué se agregó

| Función | Para qué le sirve al dueño |
|---|---|
| **Ficha de salud** | Sexo, nacimiento (edad exacta), esterilizado, microchip, grupo sanguíneo, **alergias**, condiciones crónicas, dieta, veterinario de cabecera. |
| **Cartilla de vacunación** | Vacunas con dosis, lote, veterinario y **fecha de refuerzo**. El backend calcula si está *al día / por vencer / vencida*. |
| **Desparasitaciones** | Interna / externa / ambas, con próxima fecha y peso al aplicar. |
| **Historial clínico** | Consultas: motivo, diagnóstico, tratamiento, temperatura, peso, costo (Bs). |
| **Medicamentos** | Tratamientos con dosis, frecuencia y rango de fechas (`is_active` calculado). |
| **Control de peso** | Registros para graficar la evolución. |
| **Citas** | Agenda con estado `scheduled → completed / cancelled`. |
| **Documentos** | Fotos/PDF de análisis, radiografías, recetas, foto del carnet físico (bucket privado). |
| **Resumen + recordatorios** | Un endpoint con todo lo que la pantalla principal de salud necesita y lista de pendientes. |
| **Compartir con el veterinario** | Enlace temporal (1–168 h) → **QR**. El vet abre una página HTML imprimible sin instalar nada. Se puede revocar. |

---

## 2. Reglas generales (iguales al resto de la API)

- **Base URL:** `https://chowtrack.onrender.com` (`ApiConfig.baseUrl`).
- **Auth:** `Authorization: Bearer <access_token>` en todo, **excepto** `/health/shared/{token}` y `/health/shared/{token}/carnet` (públicos).
- **Errores:** mismo formato que hoy → `{"success": false, "error": "<mensaje para el usuario>", "detail": "<código>"}`. Mostrar `error` en el SnackBar.
- **Fechas que se envían:**
  - Fechas simples (`applied_at`, `visit_date`, `birth_date`...) → `"YYYY-MM-DD"`. **No pueden ser futuras** (422).
  - `scheduled_at` de citas → ISO con zona (`2026-10-20T10:00:00-04:00`). Si se manda **sin zona**, el backend asume **hora de Bolivia (UTC-4)**.
- **Fechas que se reciben:** siempre `String` ISO (como `last_seen_at` en `PetModel`). Usar `DateTime.tryParse`.
- **Números:** `weight_kg`, `temperature_c`, `cost_bob` llegan como `num` → `(json['x'] as num?)?.toDouble()`.
- **POST** crea (201) · **PATCH** edita *solo los campos enviados* (enviar `null` en un campo opcional lo borra) · **DELETE** responde **204 sin cuerpo**.
- PATCH con `{}` → 400 `empty_update`. Enviar `null` en un campo obligatorio → 422.

### Códigos de error nuevos (`detail`)
| HTTP | `detail` | Cuándo |
|---|---|---|
| 404 | `pet_not_found` | La mascota no existe o no es del usuario |
| 404 | `record_not_found` | El registro no existe para esa mascota |
| 404 | `share_not_found` | Enlace del carnet inválido, revocado o expirado |
| 400 | `empty_update` | PATCH sin campos |
| 400 | `invalid_base64` / `empty_file` | Archivo mal codificado |
| 413 | `file_too_large` | Documento > 5 MB |
| 415 | `unsupported_file_type` | No es JPG / PNG / PDF (se detecta por contenido, no por extensión) |
| 422 | `visit_not_found` | `visit_id` de un medicamento no pertenece a la mascota |
| 422 | (validación) | Fechas futuras, refuerzo antes de la aplicación, enum inválido, etc. |

---

## 3. Endpoints

Prefijo de mascota: **`/pets/{pet_id}/health`**

### 3.1 Resumen y carnet
```
GET  /pets/{pet_id}/health          → HealthSummary   (pantalla principal de "Salud")
GET  /pets/{pet_id}/health/card     → HealthCard      (vista previa del carnet completo)
GET  /health/reminders?days=30      → List<HealthReminder>  (todas mis mascotas; days 1–365)
```

### 3.2 Ficha de salud (1 por mascota)
```
GET  /pets/{pet_id}/health/profile  → HealthProfile  (si no existe devuelve valores por defecto con is_registered=false)
PUT  /pets/{pet_id}/health/profile  → HealthProfile  (reemplaza la ficha completa)
```

### 3.3 CRUD de historial (mismo patrón para todos)
```
GET    /pets/{pet_id}/health/<recurso>
POST   /pets/{pet_id}/health/<recurso>
PATCH  /pets/{pet_id}/health/<recurso>/{record_id}
DELETE /pets/{pet_id}/health/<recurso>/{record_id}
```
| `<recurso>` | Orden del GET | Extras |
|---|---|---|
| `vaccinations` | más reciente primero (`applied_at`) | `due_status`, `days_until_due` |
| `dewormings` | más reciente primero | `due_status`, `days_until_due` |
| `visits` | más reciente primero (`visit_date`) | — |
| `medications` | más reciente primero (`start_date`) | `is_active`; filtro `?active_only=true` |
| `weights` | más reciente primero (`measured_at`) | invertir la lista para el gráfico |
| `appointments` | **más próxima primero** (`scheduled_at` asc) | filtro `?status=scheduled\|completed\|cancelled` |
| `documents` | más reciente primero | `url` firmada (1 h); PATCH solo edita metadatos |

### 3.4 Compartir con el veterinario
```
GET    /pets/{pet_id}/health/shares            → List<HealthShare> (últimos 20)
POST   /pets/{pet_id}/health/shares            → HealthShare   body: {"expires_in_hours": 24}  (1–168)
DELETE /pets/{pet_id}/health/shares/{share_id} → 204 (revoca)

GET /health/shared/{token}          → HealthCard (JSON, público)
GET /health/shared/{token}/carnet   → Página HTML imprimible (público)  ← ESTO VA EN EL QR
```

---

## 4. Contratos JSON

### 4.1 Body de creación (POST) — campos

`*` = obligatorio. Entre paréntesis: límites.

**Vacuna** `POST .../vaccinations`
```json
{
  "vaccine_name": "Antirrábica",          // * (2–80)
  "vaccine_type": "rabies",               // rabies|polyvalent|leptospirosis|bordetella|other (default other)
  "dose_number": 1,                       // 1–20
  "applied_at": "2026-10-01",             // * no futura
  "next_due_at": "2027-10-01",            // ≥ applied_at
  "batch_number": "L-2291",               // (50)
  "vet_name": "Dra. Rojas",               // (80)
  "clinic_name": "Clínica San Roque",     // (100)
  "notes": "Sin reacciones"               // (500)
}
```

**Desparasitación** `POST .../dewormings`
```json
{ "product_name": "Drontal Plus", "deworming_type": "internal", "applied_at": "2026-10-01",
  "next_due_at": "2027-01-01", "weight_kg": 12.4, "notes": null }
```
`product_name`* (2–80) · `deworming_type`: `internal|external|both` · `applied_at`* · `weight_kg` (0–150]

**Consulta** `POST .../visits`
```json
{ "visit_date": "2026-10-10", "reason": "Vómitos", "diagnosis": "Gastritis leve",
  "treatment": "Dieta blanda 3 días", "vet_name": "Dr. Pérez", "clinic_name": "VetCentro",
  "weight_kg": 12.1, "temperature_c": 38.9, "cost_bob": 150, "notes": null }
```
`visit_date`* · `reason`* (2–200) · `diagnosis`/`treatment` (1000) · `temperature_c` 30–45 · `cost_bob` ≥ 0

**Medicamento** `POST .../medications`
```json
{ "name": "Omeprazol", "dosage": "10 mg", "frequency": "Cada 24 h", "start_date": "2026-10-10",
  "end_date": "2026-10-17", "prescribed_by": "Dr. Pérez", "visit_id": "<id de consulta>", "notes": null }
```
`name`* · `start_date`* · `end_date` ≥ `start_date` (null = tratamiento indefinido) · `visit_id` opcional

**Peso** `POST .../weights` → `{ "weight_kg": 12.5, "measured_at": "2026-10-13", "notes": null }`

**Cita** `POST .../appointments`
```json
{ "scheduled_at": "2026-10-20T10:00:00-04:00", "reason": "Refuerzo antirrábica",
  "vet_name": "Dra. Rojas", "clinic_name": "Clínica San Roque", "address": "Av. Heroínas 123", "notes": null }
```
Para completar / cancelar: `PATCH .../appointments/{id}` con `{"status": "completed"}`.

**Documento** `POST .../documents`
```json
{ "title": "Hemograma", "doc_type": "lab_result", "issued_at": "2026-10-10", "notes": null,
  "file_base64": "<base64 del archivo, se acepta prefijo data:...;base64,>" }
```
`doc_type`: `vaccine_certificate|lab_result|xray|prescription|other` · máx **5 MB** · JPG/PNG/PDF.
(Mismo mecanismo base64 que ya usa `NoseAiService` para `/nose/register`.)

**Ficha** `PUT .../profile`
```json
{ "sex": "female", "birth_date": "2023-05-10", "color": "Café", "is_sterilized": true,
  "microchip_id": "985112003456789", "blood_type": "DEA 1.1+",
  "allergies": ["Pollo"], "chronic_conditions": ["Displasia de cadera"],
  "diet_notes": "Croquetas hipoalergénicas", "vet_name": "Dra. Rojas",
  "vet_clinic": "Clínica San Roque", "vet_phone": "+591 44123456" }
```
`sex`: `male|female|unknown` · listas máx 20 elementos de 50 caracteres (se limpian duplicados/vacíos) ·
`vet_phone` acepta fijos y celulares (`^\+?\d[\d\s-]{6,19}$`), a diferencia del teléfono del dueño que es solo celular +591.

### 4.2 Respuestas

Todos los registros devuelven los mismos campos del body + `id`, `pet_id`, `created_at`, `updated_at`, y además:

| Recurso | Campos calculados |
|---|---|
| Vacuna / Desparasitación | `due_status`, `days_until_due` (int o null; negativo = vencida) |
| Medicamento | `is_active` |
| Documento | `mime_type`, `size_bytes`, `url` (firmada, **expira en 1 h — no guardarla**, volver a pedir la lista) |
| Ficha | `age_months`, `is_registered` |

**HealthSummary** — `GET /pets/{pet_id}/health`
```json
{
  "pet_id": "…", "pet_name": "Maya", "photo_url": "https://…",
  "profile": { …HealthProfile… },
  "vaccination_status": "overdue",
  "deworming_status": "up_to_date",
  "latest_weight": { "id": "…", "weight_kg": 12.5, "measured_at": "2026-10-13", … } | null,
  "next_appointment": { …Appointment… } | null,
  "active_medications": [ …Medication… ],
  "reminders": [ …HealthReminder… ],
  "counts": { "vaccinations": 4, "dewormings": 2, "visits": 3, "medications_active": 1, "documents": 2 }
}
```

**HealthReminder**
```json
{ "pet_id": "…", "pet_name": "Maya", "kind": "vaccination", "record_id": "…",
  "title": "Vacuna Antirrábica", "due_date": "2026-10-01", "days_left": -12, "is_overdue": true }
```
`kind`: `vaccination | deworming | appointment` (`due_date` de una cita es datetime ISO). Ordenados: vencidos primero.
Una cita `scheduled` cuya hora ya pasó aparece con `is_overdue: true` → sugerir al usuario marcarla como completada o cancelada.

**HealthShare**
```json
{ "id": "…", "pet_id": "…", "token": "…",
  "share_url":  "https://chowtrack.onrender.com/health/shared/<token>",
  "carnet_url": "https://chowtrack.onrender.com/health/shared/<token>/carnet",
  "expires_at": "2026-10-14T20:00:00+00:00", "revoked_at": null, "last_accessed_at": null,
  "is_active": true, "created_at": "…" }
```
`last_accessed_at` permite mostrar "El veterinario abrió el carnet a las 15:32".

**HealthCard** (`/card` y `/health/shared/{token}`): `pet {name, breed, age_years, photo_url}`, `profile`,
`vaccination_status`, `deworming_status`, `latest_weight`, `vaccinations[]`, `dewormings[]`,
`active_medications[]`, `recent_visits[]` (últimas 10), `documents[]`, `generated_at`, `expires_at`.
**No incluye datos del dueño** (ni email, ni teléfono, ni `owner_id`).

---

## 5. Enums → texto y color sugeridos (usar `AppTheme`, nunca colores a mano)

### `due_status` (por registro) y `vaccination_status` / `deworming_status` (global)
| Valor | Texto UI | Color sugerido |
|---|---|---|
| `up_to_date` | Al día | Emerald Green |
| `due_soon` | Vence pronto (≤ 30 días) | Ámbar / warning |
| `overdue` | Vencida | Panic Red |
| `no_due_date` | Sin refuerzo programado | Outline |
| `superseded` | Renovada (ya hay una aplicación posterior) | Outline, tarjeta atenuada |
| `no_records` *(solo global)* | Sin registros | Outline |

> **Regla de renovación:** solo la *última* aplicación de cada vacuna cuenta para alertas.
> Vacunas con tipo conocido se agrupan por `vaccine_type` (una antirrábica renueva a otra);
> las `other` se agrupan por nombre (sin tildes/mayúsculas). En desparasitación, `both` cubre interna y externa.
> El frontend **no** necesita recalcular nada: usar `due_status` tal cual.

### Otros enums
| Campo | Valores → texto |
|---|---|
| `vaccine_type` | `rabies` Antirrábica · `polyvalent` Polivalente (séxtuple/óctuple) · `leptospirosis` Leptospirosis · `bordetella` Bordetella (tos de las perreras) · `other` Otra |
| `deworming_type` | `internal` Interna · `external` Externa (pulgas/garrapatas) · `both` Interna y externa |
| `status` (cita) | `scheduled` Agendada · `completed` Realizada · `cancelled` Cancelada |
| `doc_type` | `vaccine_certificate` Certificado de vacuna · `lab_result` Análisis · `xray` Radiografía · `prescription` Receta · `other` Otro |
| `sex` | `male` Macho · `female` Hembra · `unknown` Sin especificar |

---

## 6. Modelos Dart sugeridos (mismo estilo que `PetModel`)

Ubicación sugerida: `lib/features/health/models/`. Ejemplo para vacunas; el resto sigue el mismo patrón con los campos de la sección 4.

```dart
// lib/features/health/models/vaccination_model.dart

class VaccinationModel {
  final String id;
  final String petId;
  final String vaccineName;
  final String vaccineType;   // rabies | polyvalent | leptospirosis | bordetella | other
  final int? doseNumber;
  final String appliedAt;     // YYYY-MM-DD
  final String? nextDueAt;
  final String? batchNumber;
  final String? vetName;
  final String? clinicName;
  final String? notes;
  final String dueStatus;     // up_to_date | due_soon | overdue | no_due_date | superseded
  final int? daysUntilDue;

  const VaccinationModel({
    required this.id,
    required this.petId,
    required this.vaccineName,
    this.vaccineType = 'other',
    this.doseNumber,
    required this.appliedAt,
    this.nextDueAt,
    this.batchNumber,
    this.vetName,
    this.clinicName,
    this.notes,
    this.dueStatus = 'no_due_date',
    this.daysUntilDue,
  });

  factory VaccinationModel.fromJson(Map<String, dynamic> json) => VaccinationModel(
        id:           json['id']            as String,
        petId:        json['pet_id']        as String,
        vaccineName:  json['vaccine_name']  as String,
        vaccineType:  (json['vaccine_type'] as String?) ?? 'other',
        doseNumber:   json['dose_number']   as int?,
        appliedAt:    json['applied_at']    as String,
        nextDueAt:    json['next_due_at']   as String?,
        batchNumber:  json['batch_number']  as String?,
        vetName:      json['vet_name']      as String?,
        clinicName:   json['clinic_name']   as String?,
        notes:        json['notes']         as String?,
        dueStatus:    (json['due_status']   as String?) ?? 'no_due_date',
        daysUntilDue: json['days_until_due'] as int?,
      );

  /// Body para POST (crear). Para PATCH enviar solo los campos editados.
  Map<String, dynamic> toCreateJson() => {
        'vaccine_name': vaccineName,
        'vaccine_type': vaccineType,
        'dose_number':  doseNumber,
        'applied_at':   appliedAt,
        'next_due_at':  nextDueAt,
        'batch_number': batchNumber,
        'vet_name':     vetName,
        'clinic_name':  clinicName,
        'notes':        notes,
      };

  bool get isOverdue    => dueStatus == 'overdue';
  bool get isDueSoon    => dueStatus == 'due_soon';
  bool get isSuperseded => dueStatus == 'superseded';
}
```

```dart
// lib/features/health/models/health_reminder_model.dart
class HealthReminderModel {
  final String petId;
  final String petName;
  final String kind;      // vaccination | deworming | appointment
  final String recordId;
  final String title;
  final String dueDate;
  final int daysLeft;
  final bool isOverdue;

  const HealthReminderModel({
    required this.petId, required this.petName, required this.kind, required this.recordId,
    required this.title, required this.dueDate, required this.daysLeft, required this.isOverdue,
  });

  factory HealthReminderModel.fromJson(Map<String, dynamic> json) => HealthReminderModel(
        petId:     json['pet_id']     as String,
        petName:   json['pet_name']   as String,
        kind:      json['kind']       as String,
        recordId:  json['record_id']  as String,
        title:     json['title']      as String,
        dueDate:   json['due_date']   as String,
        daysLeft:  json['days_left']  as int,
        isOverdue: json['is_overdue'] as bool,
      );
}
```

Listas en la ficha: `(json['allergies'] as List<dynamic>? ?? const []).cast<String>()`.

Servicio sugerido: `lib/features/health/services/health_service.dart`, con el mismo patrón de `PetService`
(token desde `TokenStorage`, `try/catch`, excepción propia con mensaje amigable = campo `error` de la respuesta,
401 → "Sesión expirada").

---

## 7. Flujos de UI sugeridos

1. **Detalle de mascota → pestaña/botón "Salud"** → `GET /pets/{id}/health`.
   - Chip de estado de vacunas y desparasitación (`vaccination_status`, `deworming_status`).
   - Tarjeta "Próxima cita" (`next_appointment`), "Peso actual" (`latest_weight`), "Tratamientos activos".
   - Banner rojo si `profile.allergies` no está vacío (lo primero que debe ver un vet).
   - Lista corta de `reminders`.
   - Accesos a: Cartilla · Desparasitación · Consultas · Medicamentos · Peso · Citas · Documentos · Ficha.
2. **Cartilla de vacunación:** lista con chip `due_status`; las `superseded` atenuadas.
   Al registrar, sugerir `next_due_at` (+1 año antirrábica/polivalente) — es solo una ayuda de UI, el usuario decide.
3. **Home:** badge/contador con `GET /health/reminders` (vencidos primero). Tocar uno → navegar a la mascota (`pet_id`) y al registro (`record_id`).
4. **"Mostrar al veterinario":** `POST .../shares` → mostrar **QR de `carnet_url`** (paquete sugerido: `qr_flutter`) + botón copiar/compartir enlace + duración elegible (2 h, 24 h, 7 días) + botón "Revocar".
5. **Documentos:** reutilizar `PhotoPickerWidget` / cámara para la foto del carnet físico; para PDF, `file_picker`. Abrir `url` con `url_launcher`.
6. **Peso:** gráfico de línea con `GET .../weights` (invertir orden). Se puede usar `fl_chart`.

> Nota de navegación (regla del proyecto): las nuevas pantallas se abren con `Navigator.push(MaterialPageRoute(...))`
> y se cierran con `Navigator.pop`, **no** con rutas nombradas.

---

## 8. Base de datos (Supabase)

Migraciones aplicadas: `health_module_vet_records`, `health_module_index_medications_visit`
(copia del SQL en `Actualizaciones/sql/`).

| Tabla | Relación | Notas |
|---|---|---|
| `pet_health_profiles` | 1:1 `pets` (PK = `pet_id`) | listas como `text[]` |
| `pet_vaccinations` | N:1 `pets` | CHECK `next_due_at ≥ applied_at` |
| `pet_dewormings` | N:1 `pets` | ídem |
| `pet_vet_visits` | N:1 `pets` | |
| `pet_medications` | N:1 `pets`, N:1 `pet_vet_visits` (SET NULL) | CHECK `end_date ≥ start_date` |
| `pet_weight_logs` | N:1 `pets` | |
| `pet_vet_appointments` | N:1 `pets` | enum `appointment_status` |
| `pet_health_documents` | N:1 `pets` | archivo en bucket privado **`pet-health`** (5 MB, jpg/png/pdf) |
| `pet_health_shares` | N:1 `pets` | token único ≥ 24 chars, `expires_at`, `revoked_at` |

- Todo con `ON DELETE CASCADE` hacia `pets`, `updated_at` por trigger (`handle_updated_at`, el mismo de siempre).
- **RLS activado** en las 9 tablas: solo el dueño de la mascota (`EXISTS` sobre `pets`, igual que `nose_embeddings`).
  Los tokens de compartir solo los crea el backend (service_role).
- No se modificó ninguna tabla/vista existente (`profiles`, `pets`, `nose_embeddings`, `my_pets` intactas).

---

## 9. Despliegue

- **Sin dependencias nuevas** en `requirements.txt`.
- Variable opcional en Render: `PUBLIC_BASE_URL` (default `https://chowtrack.onrender.com`) — se usa para armar `share_url`/`carnet_url`.
- Tests: `cd backend/UniTest && .venv\Scripts\python -m pytest` → 104 passed (38 nuevos del módulo).

## 10. Archivos del backend

```
app/core/health_schemas.py      ← schemas Pydantic del módulo
app/services/health_logic.py    ← lógica pura (vencimientos, recordatorios, zona horaria BO, tipo de archivo)
app/services/health_carnet.py   ← HTML imprimible del carnet compartido
app/routes/health.py            ← endpoints
app/core/config.py              ← + PUBLIC_BASE_URL
app/main.py                     ← + include_router(health.router / health.public_router)
UniTest/test_4_salud.py         ← tests
```

## 11. Pendiente / futuro (fuera de alcance de esta entrega)

- Lado del **veterinario** con cuenta (rol `vet` ya existe en `user_role`): registrar vacunas firmadas por el vet, validar el carnet.
- Notificaciones push de recordatorios (hoy el frontend consulta `/health/reminders`).
- Exportar carnet a PDF (hoy la página HTML se puede imprimir/guardar como PDF desde el navegador).
- Vincular un documento a una vacuna concreta (foto del sticker).
