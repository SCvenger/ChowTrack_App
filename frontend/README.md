# 🐾 Chow-Track: Pet Recovery System

**Ubicación:** Cochabamba, Bolivia.  
**Misión:** Reducir el tiempo de reencuentro entre mascotas extraviadas y sus familias mediante biometría de huella nasal (AI) y reportes comunitarios en tiempo real.

---

## 🛠️ Especificaciones Técnicas (Stack)

Este proyecto está diseñado para ser ligero, de alta visibilidad en exteriores y escalable.

- **Frontend:** Flutter 3.x (Canal Estable).
- **Diseño:** Material 3 con enfoque "Clean Tech Recovery".
- **Lenguaje:** Dart.
- **Arquitectura:** Layered Architecture (Arquitectura por Capas).
- **Gestión de Estado:** (Pendiente por definir: Bloc/Riverpod).
- **Tipografía:** Metropolis (vía Google Fonts).

### Principios de Programación

- **Stateless por defecto:** Preferimos widgets sin estado para optimizar memoria en dispositivos Surface/Mobile.
- **Theming Centralizado:** Ningún color o fuente se escribe "a mano" en las vistas; todo debe llamar a `AppTheme`.

---

## 📂 Estructura del Proyecto (Architecture)

Mantenemos una separación estricta para facilitar el mantenimiento y la lectura por agentes de IA:

```text
lib/
├── core/             # Manual de identidad y herramientas globales
│   ├── theme.dart    # Configuración de ThemeData y Google Fonts
│   ├── constants.dart # URLs de API, llaves y strings fijos
│   └── utils/         # Validadores y formateadores
├── features/         # Módulos funcionales de la App
│   ├── auth/         # Login, Registro de usuario, Recuperación
│   ├── registration/ # Flujo de registro de mascota (Escaneo Nasal)
│   ├── map/          # Visualización de mascotas perdidas (GPS)
│   └── profile/      # Gestión de cuenta del dueño
├── shared/           # Componentes que se usan en múltiples features
│   └── widgets/      # Botones (56px), Inputs (Ghost-style), Cards
└── main.dart         # Punto de entrada y orquestador de rutas

____________________________________________________________________________________________
🧠 Lógica de Negocio (Business Logic)
1. El Identificador Único (Trufa Nasal)
A diferencia del microchip, Chow-Track utiliza la biometría nasal.

Proceso: La app captura una imagen macro de la nariz del perro.

Lógica: Se extraen puntos de interés (minucias) que generan un "Hash Biométrico" único.

Flujo:
1. El dueño registra al perro -> Se genera el Hash -> Se guarda en DB.
2. Alguien encuentra un perro -> Escanea la nariz -> La IA busca coincidencias entre Hashes en la DB.

2. Estados de la Mascota
Cada mascota en la DB debe tener un atributo status:

SAFE: Estado por defecto.

LOST: Activa la alerta en el mapa y notifica a usuarios cercanos.

FOUND: Estado temporal cuando un tercero reporta un hallazgo.
3. Geofencing (Cochabamba)
La lógica de búsqueda prioriza un radio de 5km a 10km desde el último punto de avistamiento reportado, optimizando las consultas a la base de datos.
_____________________________________________________________________________________
🛠️ Reglas Técnicas para el Código (Dev Guidelines)
Gestión de Estado: Se utilizará Provider o Bloc (por definir) para separar la UI de la lógica.

Tipado Estricto: No se permite el uso de dynamic en Dart. Todos los modelos deben tener una clase definida (ej: PetModel).

Manejo de Errores: Toda petición al backend debe estar envuelta en un bloque try-catch con mensajes de error amigables para el usuario.

Respeto al Tema: No usar Colors.blue o SizedBox(height: 10). Usar AppColors.trustBlue y constantes de espaciado definidas en AppTheme.
______________________________________________________________________________________
📡 Integración con API (Contrato inicial)
Los agentes deben considerar que el backend responderá bajo el estándar JSON:

GET /pets: Lista de mascotas.

POST /pets/identify: Envío de imagen de trufa para comparación.

POST /auth/login: Validación de credenciales.
_________________________________________________________________________________
🤖 Integración con IA (Brain.ai)
Integraremos el modelo de reconocimiento de huellas nasales de Brain.ai para automatizar el proceso de identificación.

Endpoint Clave:

https://api.brain.ai/v2/predict/nose-match

Datos Necesarios (Payload):



{

  "image": "[base64-encoded-image]" // La foto de la nariz del perro

}


Respuesta Esperada (Response):



{

  "match_id": 12345,

  "match_score": 98.2, // Porcentaje de confianza (Umbral >90%)

  "is_dog": true,

  "match_type": "nose"

}



Flujo de Desarrollo:



Abrir Flutter Camera:



En el feature registration/ hay que crear un widget de cámara personalizado.



Pre-procesamiento:



La imagen debe ser recortada para centrar la nariz antes de subirla.



Validación:



Si match_score > 90%:



Mostrar modal: "¡Hemos encontrado a tu mascota!"



Llamar a otro endpoint: /api/pets/[match_id]



Para obtener los datos de contacto del dueño.


Si match_score < 90%:



Mostrar mensaje: "No coincide con ninguna mascota registrada."



Ofrecer opción: "¿Quieres registrar este perro como perdido?"
```
