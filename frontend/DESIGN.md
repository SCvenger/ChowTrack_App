---
name: Clean Tech Recovery
colors:
  surface: '#faf8ff'
  surface-dim: '#d9d9e2'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3fc'
  surface-container: '#ededf6'
  surface-container-high: '#e7e7f0'
  surface-container-highest: '#e2e2eb'
  on-surface: '#191b22'
  on-surface-variant: '#434653'
  inverse-surface: '#2e3037'
  inverse-on-surface: '#f0f0f9'
  outline: '#737784'
  outline-variant: '#c3c6d5'
  surface-tint: '#2559bd'
  primary: '#00327d'
  on-primary: '#ffffff'
  primary-container: '#0047ab'
  on-primary-container: '#a5bdff'
  inverse-primary: '#b1c5ff'
  secondary: '#006d36'
  on-secondary: '#ffffff'
  secondary-container: '#83fba5'
  on-secondary-container: '#00743a'
  tertiary: '#651f00'
  on-tertiary: '#ffffff'
  tertiary-container: '#8b2e01'
  on-tertiary-container: '#ffaa8a'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae2ff'
  primary-fixed-dim: '#b1c5ff'
  on-primary-fixed: '#001946'
  on-primary-fixed-variant: '#00419e'
  secondary-fixed: '#83fba5'
  secondary-fixed-dim: '#66dd8b'
  on-secondary-fixed: '#00210c'
  on-secondary-fixed-variant: '#005227'
  tertiary-fixed: '#ffdbcf'
  tertiary-fixed-dim: '#ffb59a'
  on-tertiary-fixed: '#380d00'
  on-tertiary-fixed-variant: '#802900'
  background: '#faf8ff'
  on-background: '#191b22'
  surface-variant: '#e2e2eb'
typography:
  display-lg:
    fontFamily: metropolis
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: metropolis
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-md:
    fontFamily: metropolis
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: metropolis
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: metropolis
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: metropolis
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: metropolis
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base-unit: 8px
  margin-mobile: 24px
  gutter: 16px
  tap-target-min: 48px
  stack-sm: 12px
  stack-md: 24px
  stack-lg: 40px
---

## Brand & Style

This design system is built on the pillars of **Urgency, Clarity, and Reliability**. As a dog recovery tool, the interface must transition seamlessly from a calm, daily tracking utility to a high-stakes emergency tool. 

The aesthetic is **Modern Minimalist** with a "Clean Tech" influence—utilizing vast white space to reduce cognitive load during high-stress situations. For outdoor visibility, the system employs high-contrast elements and large, unambiguous touch points. A signature feature is the **Sleek HUD Overlay**, which uses semi-transparent dark layers and neon-infused accents to represent AI-driven scanning and tracking features, providing a high-tech, precise feel without cluttering the core experience.

## Colors

The palette is engineered for maximum legibility in outdoor environments, specifically under direct sunlight.

*   **Trust Blue (#0047AB):** Used for primary branding, active navigation states, and authoritative UI elements. It establishes a sense of professional security.
*   **Emerald Green (#50C878):** Reserved for "Safe" status indicators, successful connections (GPS), and positive confirmations.
*   **Panic Red (#DC3545):** High-chroma red used exclusively for the "Report Lost" trigger and active search alerts. It must never be used for minor errors.
*   **Pure White (#FFFFFF):** The bedrock of the design system, providing the highest possible contrast for text and iconography.

## Typography

The system utilizes **Metropolis** (as a high-quality alternative to Urbanist) to achieve a geometric, clean-tech look that remains legible at high speeds. 

**Hierarchy Rules:**
*   **Large Headings:** Use `display-lg` for critical status updates (e.g., "PET FOUND").
*   **Legibility First:** Body text never drops below 16px to ensure readability while walking or running.
*   **Case Usage:** Labels should use All-Caps with slight letter spacing to differentiate from body content in complex HUD overlays.

## Layout & Spacing

This design system uses a **Fluid Grid** based on an 8px square rhythm. 

*   **Margins:** A generous 24px side margin is enforced on mobile to prevent accidental edge-touches during vigorous outdoor activity.
*   **Tap Targets:** Every interactive element (buttons, toggles, links) must be a minimum of 48x48dp.
*   **Vertical Rhythm:** Content blocks are separated by `stack-lg` (40px) to maintain the minimalist, airy feel and prevent information density fatigue.

## Elevation & Depth

To maintain a "Clean Tech" aesthetic, the system avoids heavy, muddy shadows. 

1.  **Flat Base:** The primary background is pure white and flat.
2.  **HUD Overlays:** AI scanning and map features use a "Glassmorphic" stack. These surfaces use a `background-blur (20px)` with a 60% opacity dark tint (#1A1A1A) and a 1px inner stroke in white (10% opacity).
3.  **Soft Elevation:** Floating Action Buttons (FABs) and critical cards use **Ambient Shadows**: a subtle, diffused blue-tinted shadow (Hex #0047AB at 8% opacity, 15px blur, 4px offset).

## Shapes

The shape language is **Soft Rounded**. This balances the clinical nature of "Clean Tech" with the friendly, approachable world of pet care.

*   **Buttons & Cards:** 16px (`rounded-lg`) corner radius.
*   **Input Fields:** 8px (`soft`) corner radius.
*   **HUD Elements:** 24px (`rounded-xl`) corner radius to suggest a more organic, lens-like feel for AI features.

## Components

*   **Primary Action Buttons:** Solid `Trust Blue` backgrounds with White `label-lg` text. Height is fixed at 56px for high-visibility tapping.
*   **Panic Button:** A unique, oversized circular button (80x80dp) using `Panic Red` with a subtle pulsing outer ring animation when active.
*   **Status Chips:** Small, pill-shaped indicators. "Live" tracking uses a Green background with a 2px White border for maximum pop against map layers.
*   **HUD Cards:** Used for AI dog-breed identification or distance tracking. Features a frosted-glass background, high-contrast white text, and a `secondary` (Emerald Green) accent for data points.
*   **Progress Bars:** Thin, 4px high bars. Backgrounds are light grey, while the progress fill is a vibrant Emerald Green to signify "system health."
*   **Input Fields:** Ghost-style inputs with 1px `ui_border_hex` borders that thicken and turn `Trust Blue` on focus.