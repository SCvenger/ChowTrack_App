---
name: Clean Tech Recovery
version: 1.1.0
status: MVP activo

colors:
  # ── Colores activos en MVP ────────────────────────────────────────
  trust-blue: '#0047AB'          # Color primario de la app (AppColors.trustBlue)
  emerald-green: '#50C878'       # Estado SAFE y confirmaciones (AppColors.esmeraldGreen)
  panic-red: '#DC3545'           # Estado LOST y alertas críticas (AppColors.panicRed)
  surface: '#FAF8FF'             # Fondo principal (AppColors.surface)
  input-fill: '#F2F2F7'          # Relleno de inputs (AppColors.inputFill)
  outline: '#737784'             # Bordes y texto secundario (AppColors.outline)
  black: '#000000'               # Texto principal e íconos (AppColors.black)

  # ── Sistema Material 3 completo (reservado para v2) ───────────────
  primary: '#0047AB'
  on-primary: '#ffffff'
  primary-dark: '#00327D'
  secondary: '#006D36'
  on-secondary: '#ffffff'
  secondary-container: '#83FBA5'
  tertiary: '#651F00'
  tertiary-container: '#8B2E01'
  error: '#DC3545'
  surface-dim: '#D9D9E2'
  surface-container-low: '#F3F3FC'
  surface-container: '#EDEDF6'
  surface-container-high: '#E7E7F0'
  outline-variant: '#C3C6D5'
  inverse-surface: '#2E3037'
  inverse-on-surface: '#F0F0F9'

typography:
  font-family: Inter           # Google Fonts — sustituye a Metropolis (no disponible en GFonts)
  display-lg:
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
    flutter: AppTheme.displayLg
  headline-lg:
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    flutter: AppTheme.headlineLg
  headline-md:
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    flutter: AppTheme.headlineMd
  body-lg:
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
    flutter: AppTheme.bodyLg
  body-md:
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    flutter: AppTheme.bodyMd
  label-lg:
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
    flutter: AppTheme.labelLg
  label-sm:
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    flutter: AppTheme.labelSm

rounded:
  sm: 0.25rem    # 4px
  DEFAULT: 0.75rem  # 12px — inputs (actualizado para coincidir con mockups)
  md: 0.75rem    # 12px
  lg: 1rem       # 16px — botones y tarjetas
  xl: 1.5rem     # 24px — elementos HUD y escáner nasal
  full: 9999px   # chips y badges

spacing:
  base-unit: 8px
  margin-mobile: 24px     # Flutter: AppTheme.marginMobile
  gutter: 16px            # Flutter: AppTheme.gutter
  tap-target-min: 48px    # Flutter: AppTheme.tapTarget
  stack-sm: 12px          # Flutter: AppTheme.stackSm
  stack-md: 24px          # Flutter: AppTheme.stackMd
  stack-lg: 40px          # Flutter: AppTheme.stackLg
---

## Filosofía de diseño

Este sistema está construido sobre tres pilares: **Urgencia, Claridad y Confiabilidad**. Como herramienta de recuperación de mascotas, la interfaz debe transitar sin fricción desde una utilidad de rastreo cotidiana hasta una herramienta de emergencia de alta tensión.

La estética es **Minimalista Moderna** con influencia _Clean Tech_ — espacios en blanco generosos para reducir la carga cognitiva en situaciones de estrés. Para visibilidad exterior, el sistema emplea elementos de alto contraste y puntos de toque grandes e inequívocos. El overlay HUD del escaneo de trufa usa capas oscuras semi-transparentes y acentos verdes para representar las funciones de IA, aportando precisión tecnológica sin saturar la experiencia principal.

---

## Colores

### Activos en MVP

La paleta central opera con siete tokens. Todo lo que no esté en esta lista es parte del sistema Material 3 reservado para versiones posteriores.

| Token | Hex | Constante Dart | Uso |
|---|---|---|---|
| `trust-blue` | `#0047AB` | `AppColors.trustBlue` | Color primario, botones de acción, barras de progreso activo |
| `emerald-green` | `#50C878` | `AppColors.esmeraldGreen` | Estado `home`, éxito, confirmaciones, overlay de escaneo |
| `panic-red` | `#DC3545` | `AppColors.panicRed` | Estado `lost` y alertas críticas **exclusivamente** — nunca para errores de formulario |
| `surface` | `#FAF8FF` | `AppColors.surface` | Fondo principal de todas las pantallas |
| `input-fill` | `#F2F2F7` | `AppColors.inputFill` | Relleno de campos de texto |
| `outline` | `#737784` | `AppColors.outline` | Bordes de inputs, texto secundario, iconos inactivos |
| `black` | `#000000` | `AppColors.black` | Texto principal, títulos y headlines |

> **Regla crítica:** `panic-red` es el único color de estado de emergencia. Usar `error` del tema de Flutter (`#DC3545`) para errores de validación de formularios, manteniendo la misma paleta. El rojo nunca aparece en la UI en estado tranquilo.

### Sistema Material 3 (v2)

El esquema Material 3 completo (surface-container, inverse-surface, secondary, tertiary, etc.) está reservado para cuando se implemente el modo oscuro y la expansión del sistema de diseño. No implementar estos tokens en MVP.

---

## Tipografía

**Inter** es la fuente del sistema. Fue seleccionada por su rendimiento excepcional a tamaños pequeños y en condiciones de lectura exterior bajo luz solar directa, sus pesos variables precisos, y su adopción como estándar en aplicaciones tecnológicas de alta legibilidad.

### Escala tipográfica

Cada estilo tiene su constante Dart en `AppTheme`. Nunca usar valores de tamaño directamente en los widgets.

| Estilo | Tamaño | Peso | Uso | Constante |
|---|---|---|---|---|
| `display-lg` | 40px / 700 | Bold | Estados críticos: "MASCOTA ENCONTRADA" | `AppTheme.displayLg` |
| `headline-lg` | 32px / 700 | Bold | Títulos principales de pantalla | `AppTheme.headlineLg` |
| `headline-md` | 24px / 600 | SemiBold | Títulos de sección y wizard | `AppTheme.headlineMd` |
| `body-lg` | 18px / 400 | Regular | Descripciones y texto explicativo | `AppTheme.bodyLg` |
| `body-md` | 16px / 400 | Regular | Contenido principal de formularios | `AppTheme.bodyMd` |
| `label-lg` | 14px / 600 | SemiBold | Labels de inputs, botones secundarios | `AppTheme.labelLg` |
| `label-sm` | 12px / 500 | Medium | Notas, hints, metadata | `AppTheme.labelSm` |

### Reglas de uso

- El texto de cuerpo **nunca baja de 16px**. En condiciones de movimiento o estrés, la legibilidad es prioritaria.
- **All-Caps con letter-spacing** se usa exclusivamente en overlays HUD de escaneo (ej: el badge `ESCANEANDO...`). No aplica a labels de formularios ni navegación general.
- Toda la UI usa sentence case salvo los badges de estado HUD.

---

## Layout y espaciado

El sistema usa una **grilla fluida** basada en ritmo de 8px. Todas las constantes tienen su equivalente en `AppTheme`.

```dart
// app_theme.dart — constantes de espaciado
static const double stackSm     = 12;   // separación compacta entre elementos relacionados
static const double gutter      = 16;   // separación estándar entre campos de formulario
static const double stackMd     = 24;   // separación entre secciones de pantalla
static const double marginMobile = 24;  // margen horizontal de todos los Scaffold
static const double stackLg     = 40;   // separación entre bloques de contenido mayor
static const double tapTarget   = 48;   // altura mínima de todo elemento interactivo
```

- **Margen lateral:** 24px en todos los bordes del contenido para prevenir toques accidentales durante actividad física.
- **Tap targets:** Todo elemento interactivo (botones, toggles, chips, links) tiene mínimo 48×48dp.
- **Ritmo vertical:** Los bloques de contenido se separan con `stackLg` (40px) para mantener la estética aireada y evitar densidad de información.

---

## Shapes (border radius)

| Contexto | Valor | Token | Constante Flutter |
|---|---|---|---|
| Inputs, tarjetas pequeñas | 12px | `rounded.DEFAULT` | `BorderRadius.circular(12)` |
| Botones de acción, tarjetas | 16px | `rounded.lg` | `BorderRadius.circular(16)` |
| Elementos HUD, overlay escáner | 24px | `rounded.xl` | `BorderRadius.circular(24)` |
| Chips, badges, pills | 9999px | `rounded.full` | `BorderRadius.circular(999)` |

> El valor de 12px para inputs fue verificado contra los mockups de Stitch. El DESIGN original especificaba 8px pero los mockups muestran un radio mayor — se adopta 12px como valor correcto.

---

## Elevación y profundidad

### Base plana (toda la UI general)

Fondo blanco plano sin sombras. La jerarquía visual se comunica a través del color y el espaciado, no de la elevación.

### HUD overlay del escaneo de trufa (MVP)

Durante el escaneo, el overlay de instrucciones usa una capa oscura semi-transparente:

```dart
// MVP — overlay sólido semi-transparente (sin blur para preservar FPS)
Container(
  decoration: BoxDecoration(
    color: Colors.black.withOpacity(0.60),
    borderRadius: BorderRadius.circular(24),
  ),
  child: content,
)
```

> El efecto glassmorphic con `BackdropFilter(filter: ImageFilter.blur(sigmaX: 20))` está planificado para **v2**. Se omite en MVP porque aplica sobre el preview de cámara y puede causar frame drops en dispositivos de gama media. Medir FPS antes de activar.

### Elevación suave (FABs y tarjetas críticas — v2)

Ambient shadow con tint azul: `BoxShadow(color: Color(0xFF0047AB).withOpacity(0.08), blurRadius: 15, offset: Offset(0, 4))`.

> Verificar impacto en FPS en Realme 8 Pro antes de aplicar globalmente.

---

## Componentes

### MVP — implementados

| Componente | Especificación | Estado |
|---|---|---|
| **Botón primario** | Trust Blue, blanco, 56px altura, `rounded.lg` | ✅ `FilledButton` en `app_theme.dart` |
| **Botón secundario** | Outline, sin fondo, 56px altura | ✅ `OutlinedButton` en `app_theme.dart` |
| **Input de texto** | Fondo `input-fill` (#F2F2F7), sin borde en reposo, borde Trust Blue en foco, 12px radius | ✅ `inputDecorationTheme` en `app_theme.dart` |
| **Progress dots** | Dot activo = azul (ancho expandido), completado = verde, pendiente = gris | ✅ `ProgressIndicator` widget |
| **Photo picker** | Círculo punteado 140×140, ícono cámara, preview con overlay de edición | ✅ `PhotoPickerWidget` en `shared/widgets/` |
| **HUD overlay escaneo** | Fondo negro 60% opacidad, círculo guía verde, badge `ESCANEANDO...` | ✅ `Step3NoseScan` |

### Futuros — planificados para v2+

| Componente | Especificación |
|---|---|
| **Panic Button** | Circular 80×80dp, Panic Red, animación de pulso exterior cuando activo |
| **Status Chip** | Pill-shape, fondo color por estado, borde blanco 2px para capas de mapa |
| **HUD Card** | Glassmorphic, texto blanco, acento Emerald Green para datos de IA |
| **Progress Bar** | 4px altura, fondo gris claro, relleno Emerald Green |
| **Match Modal** | Overlay de pantalla completa, foto de la mascota, score de similitud, acciones |
| **Live tracking badge** | Verde + pulsación, sobre capa de mapa |

---

## Modo oscuro

El sistema Material 3 definido en el frontmatter incluye los tokens para modo oscuro (`inverse-surface`, `inverse-on-surface`). La implementación se planifica para **v2** junto con el sistema de colores completo.

Para MVP, la app opera en modo claro exclusivamente. El `ThemeData` de Flutter debe tener `brightness: Brightness.light` explícito para prevenir herencia inesperada del sistema.

---

## Principios de accesibilidad

- Contraste mínimo WCAG AA en todos los pares texto/fondo (verificar con herramienta de contraste antes de cada release).
- El overlay HUD usa blanco puro sobre oscuro — relación de contraste > 7:1.
- Ningún elemento transmite información únicamente a través del color (acompañar siempre con ícono o texto).
- Tamaño mínimo de fuente 12px — `label-sm` es el límite absoluto.
