# tests/registro.py
"""
═══════════════════════════════════════════════════════════════════════════
TEST DE REGISTRO — Registra una mascota con 3 fotos de ángulos distintos
═══════════════════════════════════════════════════════════════════════════

USO:
  1. Coloca 3 fotos de la nariz del MISMO perro en esta carpeta:
       - frontal.jpg
       - izquierda.jpg
       - derecha.jpg
  2. Edita config.py con tu TOKEN y PET_ID
  3. Ejecuta:  python registro.py

Las 3 fotos deben ser del mismo perro, tomadas desde ángulos ligeramente
diferentes para dar al sistema un barrido más completo de la trufa.
"""

import base64
import json
import os
import sys
import time
import requests

from config import BASE_URL, TOKEN, PET_ID


# ── Fotos a registrar: (archivo, photo_index, etiqueta) ─────────────────────
FOTOS = [
    ("image/maya 1.jpeg",   0, "frontal"),
    ("image/maya 2.jpeg", 1, "izquierda"),
    ("image/maya 3.jpeg",   2, "derecha"),
]


def encode_image(path: str) -> str:
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def registrar_foto(path: str, photo_index: int, etiqueta: str) -> bool:
    if not os.path.exists(path):
        print(f"  ⚠️  No se encontró '{path}' — omitiendo ángulo {etiqueta}")
        return False

    print(f"\n📤 Registrando ángulo {etiqueta} (índice {photo_index})...")

    try:
        image_base64 = encode_image(path)
    except Exception as e:
        print(f"  ❌ Error al leer la imagen: {e}")
        return False

    try:
        response = requests.post(
            f"{BASE_URL}/nose/register",
            headers={
                "Authorization": f"Bearer {TOKEN}",
                "Content-Type": "application/json",
            },
            json={
                "pet_id": PET_ID,
                "image_base64": image_base64,
                "photo_index": photo_index,
            },
            timeout=40,
        )
    except requests.exceptions.ConnectionError:
        print(f"  ❌ No se pudo conectar a {BASE_URL}. ¿Está corriendo el backend?")
        return False

    if response.status_code == 200:
        data = response.json()
        print(f"  ✅ {data.get('message', 'Registrado')}")
        print(f"     Keypoints detectados: {data.get('keypoint_count')}")
        print(f"     Calidad (Gemini):     {data.get('quality_score')}")
        print(f"     Patrón:               {data.get('pattern', '')[:70]}")
        return True
    else:
        print(f"  ❌ Error {response.status_code}")
        try:
            print(f"     {json.dumps(response.json(), indent=6, ensure_ascii=False)}")
        except Exception:
            print(f"     {response.text}")
        return False


def main():
    print("═" * 70)
    print("  TEST DE REGISTRO DE HUELLA NASAL — 3 ÁNGULOS")
    print("═" * 70)

    # Validación de configuración
    if "PEGA" in TOKEN or "PEGA" in PET_ID:
        print("\n❌ Edita config.py primero:")
        print("   - TOKEN: tu access_token de /auth/login")
        print("   - PET_ID: el UUID de tu mascota (de GET /pets/)")
        sys.exit(1)

    exitosos = 0
    for i, (path, idx, etiqueta) in enumerate(FOTOS):
        if i > 0:
            print("\n  ⏳ Esperando 10s para no saturar el rate limit de Gemini...")
            time.sleep(10)
        if registrar_foto(path, idx, etiqueta):
            exitosos += 1

    print("\n" + "═" * 70)
    print(f"  RESULTADO: {exitosos}/{len(FOTOS)} ángulos registrados")
    print("═" * 70)

    if exitosos == 0:
        print("\n⚠️  No se registró ningún ángulo. Verifica:")
        print("   - Que las fotos frontal.jpg/izquierda.jpg/derecha.jpg existan")
        print("   - Que el TOKEN no haya expirado")
        print("   - Que el backend esté corriendo")
    elif exitosos < len(FOTOS):
        print(f"\n⚠️  Solo se registraron {exitosos} ángulos. Para máxima precisión,")
        print("   registra los 3 ángulos.")
    else:
        print("\n🎉 Registro completo. Ahora ejecuta coincidencia.py para probar.")


if __name__ == "__main__":
    main()