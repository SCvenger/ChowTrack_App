# tests/coincidencia.py
"""
═══════════════════════════════════════════════════════════════════════════
TEST DE COINCIDENCIA — Compara una foto nueva contra los registros
═══════════════════════════════════════════════════════════════════════════

USO:
  1. Coloca la foto a identificar en esta carpeta como:  prueba.jpg
  2. Edita config.py con tu TOKEN
  3. Ejecuta:  python coincidencia.py

MODO CALIBRACIÓN (recomendado para afinar el umbral):
  Coloca dos fotos:
    - mismo.jpg     → otra foto del MISMO perro registrado
    - diferente.jpg → foto de OTRO perro distinto
  Ejecuta:  python coincidencia.py --calibrar
  El script mostrará ambos scores para que veas la separación real.
"""

import base64
import json
import os
import sys
import requests

from config import BASE_URL, TOKEN


def encode_image(path: str) -> str:
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def identificar(path: str) -> dict | None:
    if not os.path.exists(path):
        print(f"  ⚠️  No se encontró '{path}'")
        return None

    try:
        image_base64 = encode_image(path)
    except Exception as e:
        print(f"  ❌ Error al leer la imagen: {e}")
        return None

    try:
        response = requests.post(
            f"{BASE_URL}/nose/identify",
            headers={
                "Authorization": f"Bearer {TOKEN}",
                "Content-Type": "application/json",
            },
            json={"image_base64": image_base64},
            timeout=40,
        )
    except requests.exceptions.ConnectionError:
        print(f"  ❌ No se pudo conectar a {BASE_URL}. ¿Está corriendo el backend?")
        return None

    if response.status_code == 200:
        return response.json()
    else:
        print(f"  ❌ Error {response.status_code}")
        try:
            print(f"     {json.dumps(response.json(), indent=6, ensure_ascii=False)}")
        except Exception:
            print(f"     {response.text}")
        return None


def mostrar_resultado(data: dict):
    print(f"\n  {'─' * 60}")
    if data.get("match"):
        print(f"  ✅ COINCIDENCIA ENCONTRADA")
        print(f"     Mascota:     {data.get('pet_name')} ({data.get('pet_id')})")
    else:
        print(f"  ❌ SIN COINCIDENCIA")
    print(f"     Score:       {data.get('score')}")
    print(f"     Mensaje:     {data.get('message')}")
    if data.get("explanation"):
        print(f"     Explicación: {data.get('explanation')[:80]}")
    print(f"  {'─' * 60}")


def modo_normal():
    print("═" * 70)
    print("  TEST DE COINCIDENCIA")
    print("═" * 70)
    print("\n🔍 Identificando 'prueba.jpg' contra los registros...")

    data = identificar("image/prueba Maya.jpeg")
    if data:
        mostrar_resultado(data)


def modo_calibracion():
    print("═" * 70)
    print("  MODO CALIBRACIÓN — Mide la separación real de scores")
    print("═" * 70)

    print("\n🔍 [1/2] Identificando 'mismo.jpg' (debería COINCIDIR)...")
    data_mismo = identificar("image/prueba Maya.jpeg")
    score_mismo = data_mismo.get("score", 0.0) if data_mismo else None
    if data_mismo:
        mostrar_resultado(data_mismo)

    print("\n🔍 [2/2] Identificando 'diferente.jpg' (NO debería coincidir)...")
    data_dif = identificar("image/8638033.jpg")
    score_dif = data_dif.get("score", 0.0) if data_dif else None
    if data_dif:
        mostrar_resultado(data_dif)

    # Análisis de separación
    print("\n" + "═" * 70)
    print("  ANÁLISIS DE CALIBRACIÓN")
    print("═" * 70)

    if score_mismo is None or score_dif is None:
        print("\n  ⚠️  No se pudieron obtener ambos scores. Verifica las fotos.")
        return

    print(f"\n  Score MISMO perro:     {score_mismo}")
    print(f"  Score perro DIFERENTE: {score_dif}")

    separacion = score_mismo - score_dif
    print(f"  Separación:            {separacion:.4f}")

    if separacion <= 0:
        print("\n  🔴 PROBLEMA: el perro diferente puntúa igual o más alto.")
        print("     El sistema NO puede discriminar con estas fotos.")
        print("     Recomendación: usa fotos más nítidas y cercanas a la trufa.")
    else:
        umbral_sugerido = round(score_dif + separacion / 2, 4)
        print(f"\n  🟢 UMBRAL SUGERIDO: {umbral_sugerido}")
        print(f"     (punto medio entre ambos scores)")
        print(f"\n     Aplícalo en app/routes/nose.py:")
        print(f"       MATCH_THRESHOLD = {umbral_sugerido}")

        margen = separacion / max(score_dif, 0.0001)
        if margen < 1.0:
            print(f"\n  ⚠️  La separación es estrecha (margen {margen:.1f}x).")
            print("     Para mayor fiabilidad, registra los 3 ángulos del perro.")


def main():
    if "PEGA" in TOKEN:
        print("\n❌ Edita config.py primero con tu TOKEN de /auth/login")
        sys.exit(1)

    if "--calibrar" in sys.argv:
        modo_calibracion()
    else:
        modo_normal()


if __name__ == "__main__":
    main()