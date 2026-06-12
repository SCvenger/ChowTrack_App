# app/services/nose_gemini.py

import json
import os
import time
from google import genai
from google.genai import types

# gemini-2.0-flash: 1500 req/día, 15 RPM en free tier (el más generoso)
# gemini-2.5-flash: solo 20 req/día — NO usar como principal
MODEL          = "gemini-2.0-flash"
MODEL_FALLBACK = "gemini-2.5-flash"
MAX_RETRIES    = 2
RETRY_DELAY    = 5


def _get_client() -> genai.Client:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY no está configurada en el entorno")
    return genai.Client(api_key=api_key)


def _clean_json(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return text.strip()


def _generate_with_retry(client, contents: list) -> str:
    models_to_try = [MODEL, MODEL_FALLBACK]

    for model in models_to_try:
        for attempt in range(MAX_RETRIES):
            try:
                response = client.models.generate_content(
                    model=model,
                    contents=contents,
                )
                return response.text
            except Exception as e:
                error_str = str(e)
                is_retriable = (
                    "503" in error_str or "UNAVAILABLE"        in error_str or
                    "429" in error_str or "RESOURCE_EXHAUSTED"  in error_str
                )
                is_last_attempt = attempt == MAX_RETRIES - 1

                if is_retriable and not is_last_attempt:
                    time.sleep(RETRY_DELAY)
                    continue
                if is_retriable and is_last_attempt:
                    break
                raise

    raise RuntimeError("gemini_unavailable")


# ════════════════════════════════════════════════════════════════════════════
# VALIDACIÓN + DESCRIPCIÓN
# ════════════════════════════════════════════════════════════════════════════

def validate_and_describe(image_bytes: bytes) -> dict:
    client = _get_client()

    prompt = (
        "Eres un sistema de validación biométrica de narices de perros. "
        "IMPORTANTE: Responde SIEMPRE en español, sin excepción. "
        "Analiza esta imagen y responde ÚNICAMENTE con un objeto JSON válido, "
        "sin texto adicional ni markdown, con esta estructura exacta:\n"
        "{\n"
        '  "is_dog_nose": boolean,\n'
        '  "quality_score": number,\n'
        '  "pattern": string,\n'
        '  "features": [string],\n'
        '  "notes": string\n'
        "}\n"
        "quality_score DEBE ser un número decimal entre 0.0 y 1.0 (ejemplo: 0.85). "
        "NO uses valores mayores a 1.0. "
        "Todos los valores de texto deben estar en español. "
        "Si la imagen NO es una nariz de perro, devuelve is_dog_nose=false."
    )

    try:
        text = _generate_with_retry(
            client,
            [types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"), prompt],
        )
        data = json.loads(_clean_json(text))

        # Clampear quality_score a [0.0, 1.0] por si Gemini ignora la instrucción
        raw_score = float(data.get("quality_score", 0.8))
        if raw_score > 1.0:
            raw_score = raw_score / 10.0
        quality_score = max(0.0, min(1.0, raw_score))

        return {
            "is_dog_nose":   bool(data.get("is_dog_nose", True)),
            "quality_score": round(quality_score, 3),
            "pattern":       str(data.get("pattern", "")),
            "features":      list(data.get("features", [])),
            "notes":         str(data.get("notes", "")),
        }
    except RuntimeError as e:
        if "gemini_unavailable" in str(e):
            return {
                "is_dog_nose":   True,
                "quality_score": 0.8,
                "pattern":       "Análisis no disponible temporalmente",
                "features":      [],
                "notes":         "Validación omitida. SIFT activo.",
            }
        raise
    except (json.JSONDecodeError, AttributeError):
        return {
            "is_dog_nose":   True,
            "quality_score": 0.8,
            "pattern":       "",
            "features":      [],
            "notes":         "No se pudo parsear respuesta de Gemini.",
        }


# ════════════════════════════════════════════════════════════════════════════
# EXPLICACIÓN DEL MATCH
# ════════════════════════════════════════════════════════════════════════════

def explain_match(image_query: bytes, image_registered: bytes) -> str:
    client = _get_client()

    prompt = (
        "Eres un asistente que compara dos imágenes de narices de perros. "
        "La primera es de un perro encontrado; la segunda de uno registrado. "
        "En 1-2 frases breves en español, explica si parecen el mismo perro "
        "y por qué (menciona rasgos como forma, crestas o manchas). Sin markdown."
    )

    try:
        text = _generate_with_retry(
            client,
            [
                types.Part.from_bytes(data=image_query,      mime_type="image/jpeg"),
                types.Part.from_bytes(data=image_registered, mime_type="image/jpeg"),
                prompt,
            ],
        )
        return text.strip()
    except Exception:
        return "Coincidencia detectada por análisis biométrico de características nasales (SIFT)."