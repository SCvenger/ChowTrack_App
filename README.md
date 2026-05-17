# 🐾 Chow-Track: Pet Recovery System

![Flutter](https://img.shields.io/badge/-FLUTTER-02569B?logo=flutter&logoColor=white&style=fot-the-badge)
![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi&logoColor=white)
![Supabase](https://img.shields.io/badge/Database%20%26%20Auth-Supabase-3ECF8E?logo=supabase&logoColor=white)
![PyPI - Python Version](https://img.shields.io/pypi/pyversions/fastapi)
![Ubicación](https://img.shields.io/badge/Ubicación-Cochabamba%2C%20Bolivia-E53935)

**Ubicación:** Cochabamba, Bolivia.  
**Misión:** Reducir el tiempo de reencuentro entre mascotas extraviadas y sus familias mediante biometría de huella nasal (AI) y reportes comunitarios en tiempo real.

---

## 🛠️ Stack Tecnológico

### 📱 Frontend

- **Framework:** Flutter 3.41.9.
- **Diseño UI/UX:** Material 3 con enfoque _"Clean Tech Recovery"_.
- **Lenguaje:** Dart 3.11.5.
- **Arquitectura:** Arquitectura por Capas.
- **Gestión de Estado:** Bloc.
- **Tipografía:** Metropolis (Google Fonts).

### ⚙️ Backend & Datos (API)

- **Framework:** FastAPI.
- **Lenguaje:** Python 3.14.
- **Servidor ASGI:** Uvicorn con recarga en caliente en desarrollo (_StatReload_).
- **Base de Datos & Auth:** Supabase.

### Principios de Programación

- **Stateless por defecto:** Preferimos widgets sin estado para optimizar memoria en dispositivos Surface/Mobile.
- **Theming Centralizado:** Ningún color o fuente se escribe "a mano" en las vistas; todo debe llamar a `AppTheme`.

### 🎨 Paleta de Colores

Hemos definido una paleta de colores ("Clean Tech Recovery") para transmitir confianza, alerta y legibilidad en exteriores:

| Color             | Muestra | Código Hex   | Uso en la Aplicación                                                |
| :---------------- | :-----: | :----------- | :------------------------------------------------------------------ |
| **Trust Blue**    |   🟦    | `0xFF0047AB` | Color primario, botones de acción principal, barras superiores.     |
| **Emerald Green** |   🟩    | `0xFF50C878` | Estado SAFE, confirmaciones de éxito, alertas resueltas.            |
| **Panic Red**     |   🟥    | `0xFFDC3545` | Estado LOST, marcadores de peligro en el mapa, advertencias.        |
| **Surface**       |   🌫️    | `0xFFFAF8FF` | Fondos de inputs estilo Ghost, tarjetas secundarias y contenedores. |
| **Outline**       |   ⬜    | `0xFF737784` | Bordes de inputs                                                    |
| **Black**         |   ⬛    | `0xFF000000` | Texto, íconos y bordes de texto                                     |

---

## 📂 Estructura del Proyecto

Mantenemos una separación estricta para facilitar el mantenimiento y la lectura por agentes de IA:

```text
chowtrack/
├── frontend/               # Aplicación Móvil (Flutter)
│   └── lib/
│       ├── core/           # Identidad, temas, constantes y utilidades globales
│       │   ├── theme.dart       # Configuración de ThemeData y Google Fonts
│       │   ├── constants.dart   # URLs de API, llaves estáticas y strings fijos
│       │   └── utils/           # Validadores y formateadores de datos
│       ├── features/       # Módulos funcionales encapsulados
│       │   ├── auth/            # Login, Registro de usuario y Recuperación
│       │   ├── registration/    # Flujo de registro de mascota (Escaneo Nasal)
│       │   ├── map/             # Visualización de mascotas perdidas (GPS)
│       │   └── profile/         # Gestión de cuenta del dueño
│       ├── shared/         # Componentes transversales reutilizables
│       │   └── widgets/         # Botones (56px), Inputs (Ghost-style), Cards
│       └── main.dart       # Punto de entrada y orquestador de rutas
├── backend/                # API de Servicios (FastAPI)
│   ├── app/
│   │   ├── core/           # Configuraciones de entorno (Pydantic) y manejador de errores
│   │   ├── database/       # Inicializador del cliente global de Supabase
│   │   └── main.dart       # Instancia de FastAPI y ciclo de vida de la app (Lifespan)
│   ├── env/                # Entorno virtual de Python (Excluido en control de versiones)
│   └── requirements.txt    # Dependencias del servidor (FastAPI, Supabase, etc.)
└── .gitignore              # Archivo de exclusión global
```

---

## 🧠 Lógica de Negocio

- **El Identificador Único (Trufa Nasal)**
  A diferencia del microchip, Chow-Track utiliza la biometría nasal.
  **Proceso:** La app captura una imagen macro de la nariz del perro.
  **Lógica:** Se extraen puntos de interés que generan un "Hash Biométrico" único.
  **Flujo:**
  - El dueño registra al perro -> Se genera el Hash -> Se guarda en DB.
  - Alguien encuentra un perro -> Escanea la nariz -> La IA busca coincidencias entre Hashes en la DB.

- **Estados de la Mascota**
  Cada mascota en la DB debe tener un atributo status:
  **SAFE:** Estado por defecto.
  **LOST:** Activa la alerta en el mapa y notifica a usuarios cercanos.
  **FOUND:** Estado temporal cuando un tercero reporta un hallazgo.

- **Georreferenciación**
  La lógica de búsqueda prioriza un radio de 5km a 10km desde el último punto de avistamiento reportado, optimizando las consultas a la base de datos.

---

## 🛠️ Reglas Técnicas para el Código

- **Gestión de Estado:** Se utilizará Provider o Bloc para separar la UI de la lógica.

- **Tipado Estricto:** No se permite el uso de dynamic en Dart. Todos los modelos deben tener una clase definida (ej: PetModel).

- **Manejo de Errores:** Toda petición al backend debe estar envuelta en un bloque try-catch con mensajes de error amigables para el usuario.

- **Respeto al Tema:** No usar Colors.blue o SizedBox(height: 10). Usar AppColors.trustBlue y constantes de espaciado definidas en AppTheme.

---

## 📡 Integración con API

Se debe considerar que el backend responderá bajo el estándar JSON:

- **GET/pets**: Lista de mascotas.

- **POST/pets/identify**: Envío de imagen de trufa para comparación.

- **POST/auth/login**: Validación de credenciales.

---

### 🤖 Integración con IA

Integraremos el modelo de reconocimiento de huellas nasales de BrainAI para automatizar el proceso de identificación.

### Ejemplo de API:

Endpoint Clave (Ejemplo):

- https://api.brain.ai/v2/predict/nose-match

Datos Necesarios:

```JSON
{
  "image": "[base64-encoded-image]" // La foto de la nariz del perro
}
```

Respuesta Esperada:

```JSON
{
  "match_id": 12345,
  "match_score": 98.2, // Porcentaje de confianza (Umbral >90%)
  "is_dog": true,
  "match_type": "nose"
}

```

### Flujo de Desarrollo:

1. **Abrir Flutter Camera:** Captura de la nariz/trufa del perro con la cámara.

2. **Pre-procesamiento:** La imagen debe ser recortada para centrar la nariz antes de subirla además de remover el ruido de fondo.

3. **Validación:**

   **Si match_score > 90%:**
   - Mostrar modal: "¡Hemos encontrado a tu mascota!"
   - Llamar a otro endpoint: /api/pets/[match_id]
   - Para obtener los datos de contacto del dueño.

   **Si match_score < 90%:**
   - Mostrar mensaje: "No coincide con ninguna mascota registrada."

   - Ofrecer opción: "¿Quieres registrar este perro como perdido?"

---

## 🚀 Uso e Instalación

Descripción de los pasos para poner en marcha el proyecto en un entorno local.

1. **Clonar el Repositorio.**

   ```Bash
   git clone https://github.com/Scvenger/ChowTrack_App.git
   cd ChowTrack_App/chowtrack
   ```

2. **Configuración del Backend (FastAPI + Supabase).**

   ```Bash
    # Entrar a la carpeta backend
   cd backend
    # Crear el entorno virtual de Python
   python -m venv env
   ```

   **En Windows:**

   ```PowerShell
    # Activar el entorno virtual (PowerShell en Windows)
   .\env\Scripts\Activate.ps1
   ```

   **En Linux o MacOS:**

   ```Bash
    # Activar el entorno virtual (Linux o MacOS)
   source env/bin/activate
   ```

3. **Configuración de la Base de Datos (Supabase).**

   ```env
   SUPABASE_URL="https://tu-proyecto.supabase.co"
   SUPABASE_KEY="tu-anon-public-key"
   ```

   **Instalar librerias e inicializar el backend:**

   ```Bash
    # Instalar librerias
   pip install -r requirements.txt
    # Inicializar el backend
   uvicorn app.main:app --reload
   ```

4. **Configuración del Frontend (Flutter).**

   ```Bash
   cd frontend
   flutter pub get
   flutter run
   ```
