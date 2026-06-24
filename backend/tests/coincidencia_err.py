"""
coincidencia_err.py — Demostración de coincidencias ERRÓNEAS (falsos positivos)

Analiza 2 imágenes simultáneamente que NO deberían coincidir con ninguna
mascota registrada. Sirve para mostrar que el sistema rechaza correctamente
imágenes de perros distintos al registrado.

Imágenes esperadas (colocar en la carpeta image/):
  image/err01.jpg  — perro diferente al registrado
  image/err02.jpg  — otro perro diferente al registrado

Uso:
  python coincidencia_err.py
"""

import base64
import json
import os
import sys
import threading
import requests

from config import BASE_URL, TOKEN


def encode_image(path: str) -> str:
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def identificar(path: str, resultado: dict, clave: str) -> None:
    """Llama a /nose/identify y guarda el resultado en el dict compartido."""
    if not os.path.exists(path):
        resultado[clave] = {"error": f"No se encontró '{path}'"}
        return

    try:
        image_base64 = encode_image(path)
    except Exception as e:
        resultado[clave] = {"error": f"Error al leer imagen: {e}"}
        return

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
        resultado[clave] = {"error": f"No se pudo conectar a {BASE_URL}"}
        return

    if response.status_code == 200:
        resultado[clave] = response.json()
    else:
        try:
            resultado[clave] = {"error": f"HTTP {response.status_code}", "detail": response.json()}
        except Exception:
            resultado[clave] = {"error": f"HTTP {response.status_code}"}


def icono_resultado(data: dict) -> str:
    if "error" in data:
        return "⚠️ "
    return "✅ COINCIDENCIA" if data.get("match") else "❌ SIN COINCIDENCIA"


def imprimir_resultado(label: str, path: str, data: dict) -> None:
    print(f"\n  Imagen: {path}")
    if "error" in data:
        print(f"  {data['error']}")
        return
    print(f"  Resultado:   {icono_resultado(data)}")
    if data.get("match"):
        print(f"  Mascota:     {data.get('pet_name')} ({data.get('pet_id')})")
    print(f"  Score:       {data.get('score', 0.0):.4f}")
    print(f"  Mensaje:     {data.get('message', '')}")
    if data.get("explanation"):
        print(f"  Explicación: {data.get('explanation', '')[:80]}")


def main():
    if "PEGA" in TOKEN:
        print("\n❌ Edita config.py primero con tu TOKEN de /auth/login")
        sys.exit(1)

    # Rutas de las dos imágenes erróneas
    imagen_a = "image/err01.jpg"
    imagen_b = "image/err02.jpg"

    # Fallback: si no existen err0x, usa las de calibración que ya tenemos
    if not os.path.exists(imagen_a):
        imagen_a = "image/test02 pet.jpg"
    if not os.path.exists(imagen_b):
        imagen_b = "image/test02 pet.jpg"

    print("═" * 70)
    print("  DEMO — COINCIDENCIAS ERRÓNEAS (el sistema debe rechazarlas)")
    print("═" * 70)
    print(f"\n  Analizando 2 imágenes en paralelo...")
    print(f"    [A] {imagen_a}")
    print(f"    [B] {imagen_b}")

    resultados: dict = {}

    # Lanzar ambas identificaciones en paralelo
    hilo_a = threading.Thread(target=identificar, args=(imagen_a, resultados, "A"))
    hilo_b = threading.Thread(target=identificar, args=(imagen_b, resultados, "B"))

    hilo_a.start()
    hilo_b.start()
    hilo_a.join()
    hilo_b.join()

    # Mostrar resultados
    print("\n" + "═" * 70)
    print("  RESULTADOS")
    print("═" * 70)

    data_a = resultados.get("A", {"error": "Sin respuesta"})
    data_b = resultados.get("B", {"error": "Sin respuesta"})

    print(f"\n  ┌─ IMAGEN A {'─' * 56}")
    imprimir_resultado("A", imagen_a, data_a)
    print(f"\n  ├─ IMAGEN B {'─' * 56}")
    imprimir_resultado("B", imagen_b, data_b)
    print(f"\n  └{'─' * 68}")

    # Análisis comparativo
    print("\n" + "═" * 70)
    print("  ANÁLISIS COMPARATIVO")
    print("═" * 70)

    score_a = data_a.get("score", 0.0) if "error" not in data_a else None
    score_b = data_b.get("score", 0.0) if "error" not in data_b else None
    match_a = data_a.get("match", False) if "error" not in data_a else None
    match_b = data_b.get("match", False) if "error" not in data_b else None

    if score_a is not None:
        print(f"\n  Score imagen A: {score_a:.4f}  {'→ FALSO POSITIVO ⚠️' if match_a else '→ Rechazada correctamente ✅'}")
    if score_b is not None:
        print(f"  Score imagen B: {score_b:.4f}  {'→ FALSO POSITIVO ⚠️' if match_b else '→ Rechazada correctamente ✅'}")

    if match_a is False and match_b is False:
        print("\n  🟢 El sistema rechazó correctamente ambas imágenes erróneas.")
        print("     La biometría nasal distingue entre perros distintos.")
    elif match_a or match_b:
        print("\n  🔴 Atención: al menos una imagen superó el umbral.")
        print("     Considera usar fotos más nítidas o ajustar el umbral.")
        print("     Umbral actual: ver MATCH_THRESHOLD en app/routes/nose.py")

    print()


if __name__ == "__main__":
    main()
