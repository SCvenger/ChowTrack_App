# app/services/nose_sift.py
"""
Servicio de extracción y comparación de huellas nasales mediante OpenCV SIFT.

Pipeline de matching:
  1. Pre-procesamiento con CLAHE (normaliza iluminación desigual)
  2. Extracción SIFT (keypoints + descriptores)
  3. FLANN + ratio de Lowe (matches candidatos)
  4. Verificación geométrica RANSAC (filtra falsos positivos)
  5. Score basado en INLIERS geométricos absolutos

Por qué inliers en vez de conteo simple:
  Dos narices de perros distintos comparten muchos descriptores parecidos
  (todas son texturas rugosas). Pero solo el mismo perro produce matches
  que son ADEMÁS geométricamente coherentes (forman una transformación
  espacial consistente). RANSAC cuenta exactamente esos: los inliers.
"""

import base64
import cv2
import numpy as np
from io import BytesIO
from PIL import Image


# ── Constantes ──────────────────────────────────────────────────────────────
MAX_DIMENSION       = 1024
MIN_KEYPOINTS       = 8
LOWE_RATIO          = 0.75
MIN_GOOD_FOR_RANSAC = 6
RANSAC_THRESHOLD    = 6.0
FLANN_INDEX_KDTREE  = 1


# ════════════════════════════════════════════════════════════════════════════
# PRE-PROCESAMIENTO
# ════════════════════════════════════════════════════════════════════════════

def _preprocess(image_bytes: bytes) -> np.ndarray:
    """bytes → escala de grises normalizada con CLAHE + suavizado leve."""
    pil_img = Image.open(BytesIO(image_bytes)).convert("RGB")

    w, h = pil_img.size
    if max(w, h) > MAX_DIMENSION:
        scale = MAX_DIMENSION / max(w, h)
        pil_img = pil_img.resize((int(w * scale), int(h * scale)))

    gray = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2GRAY)

    # CLAHE: contraste adaptativo por zonas — clave para fotos con
    # iluminación desigual (flash, sombra, luz natural variable)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)

    # Suavizado bilateral: reduce ruido del sensor sin borrar las crestas
    gray = cv2.bilateralFilter(gray, d=5, sigmaColor=50, sigmaSpace=50)

    return gray


# ════════════════════════════════════════════════════════════════════════════
# EXTRACCIÓN
# ════════════════════════════════════════════════════════════════════════════

def extract_full(image_bytes: bytes):
    """
    Extrae keypoints + descriptores.
    Retorna (puntos_xy, descriptores, count) o (None, None, count) si insuficiente.
    """
    gray = _preprocess(image_bytes)

    sift = cv2.SIFT_create(
        nfeatures=0,
        contrastThreshold=0.03,
        edgeThreshold=15,
    )
    keypoints, descriptors = sift.detectAndCompute(gray, None)

    if descriptors is None or len(keypoints) < MIN_KEYPOINTS:
        return None, None, len(keypoints) if keypoints else 0

    pts = np.array([kp.pt for kp in keypoints], dtype=np.float32)
    return pts, descriptors, len(keypoints)


def extract_descriptors(image_bytes: bytes) -> tuple[np.ndarray | None, int]:
    """Compatibilidad: solo descriptores + count."""
    _, descriptors, count = extract_full(image_bytes)
    return descriptors, count


# ════════════════════════════════════════════════════════════════════════════
# SERIALIZACIÓN
# ════════════════════════════════════════════════════════════════════════════

def serialize_features(keypoints: np.ndarray, descriptors: np.ndarray) -> str:
    """Empaqueta keypoints (x,y) + descriptores en un solo base64."""
    buffer = BytesIO()
    np.savez_compressed(
        buffer,
        kp=keypoints.astype(np.float32),
        des=descriptors.astype(np.float32),
    )
    return base64.b64encode(buffer.getvalue()).decode("utf-8")


def deserialize_features(encoded: str):
    """base64 → (keypoints, descriptors)."""
    raw = base64.b64decode(encoded.encode("utf-8"))
    data = np.load(BytesIO(raw), allow_pickle=False)
    return data["kp"], data["des"]


# ── Compatibilidad con formato viejo (solo descriptores) ─────────────────────
def serialize_descriptors(descriptors: np.ndarray) -> str:
    buffer = BytesIO()
    np.save(buffer, descriptors.astype(np.float32), allow_pickle=False)
    return base64.b64encode(buffer.getvalue()).decode("utf-8")


def deserialize_descriptors(encoded: str) -> np.ndarray:
    raw = base64.b64decode(encoded.encode("utf-8"))
    return np.load(BytesIO(raw), allow_pickle=False)


# ════════════════════════════════════════════════════════════════════════════
# MATCHING
# ════════════════════════════════════════════════════════════════════════════

def _flann_good_matches(des_query, des_train):
    """FLANN + ratio test de Lowe → lista de buenos matches."""
    if des_query is None or des_train is None:
        return []
    if len(des_query) < 2 or len(des_train) < 2:
        return []

    index_params = dict(algorithm=FLANN_INDEX_KDTREE, trees=5)
    search_params = dict(checks=50)
    flann = cv2.FlannBasedMatcher(index_params, search_params)

    try:
        matches = flann.knnMatch(des_query, des_train, k=2)
    except cv2.error:
        return []

    good = []
    for pair in matches:
        if len(pair) < 2:
            continue
        m, n = pair
        if m.distance < LOWE_RATIO * n.distance:
            good.append(m)
    return good


def match_descriptors(des_query: np.ndarray, des_train: np.ndarray) -> dict:
    """Matching simple sin geometría (compatibilidad con registros viejos)."""
    good = _flann_good_matches(des_query, des_train)
    denom = min(len(des_query), len(des_train)) if (
        des_query is not None and des_train is not None
    ) else 1
    # Score conservador para formato viejo
    score = min(len(good) / denom, 1.0) if denom > 0 else 0.0
    return {"good_matches": len(good), "inliers": 0, "score": round(score, 4)}


def match_with_geometry(
    kp_query: np.ndarray, des_query: np.ndarray,
    kp_train: np.ndarray, des_train: np.ndarray,
) -> dict:
    """
    Matching con verificación geométrica RANSAC.

    SCORE = inliers / sqrt(min_keypoints)

    El score se basa en el número absoluto de inliers (matches geométricamente
    consistentes), normalizado suavemente. Rangos típicos observados:
      - Mismo perro:    15-80 inliers  → score alto
      - Perro distinto:  0-6  inliers  → score muy bajo

    Retorna: { good_matches, inliers, inlier_ratio, score }
    """
    result = {"good_matches": 0, "inliers": 0, "inlier_ratio": 0.0, "score": 0.0}

    good = _flann_good_matches(des_query, des_train)
    result["good_matches"] = len(good)

    # Sin suficientes matches no hay geometría que verificar
    if len(good) < MIN_GOOD_FOR_RANSAC:
        return result

    src_pts = np.float32([kp_query[m.queryIdx] for m in good]).reshape(-1, 1, 2)
    dst_pts = np.float32([kp_train[m.trainIdx] for m in good]).reshape(-1, 1, 2)

    H, mask = cv2.findHomography(src_pts, dst_pts, cv2.RANSAC, RANSAC_THRESHOLD)

    if H is None or mask is None:
        return result

    inliers = int(mask.sum())
    inlier_ratio = inliers / len(good) if good else 0.0

    # Score interpretable: inliers absolutos normalizados.
    # sqrt suaviza para que no dependa linealmente del nº de keypoints.
    denom = max(np.sqrt(min(len(des_query), len(des_train))), 1.0)
    score = inliers / denom

    result["inliers"] = inliers
    result["inlier_ratio"] = round(inlier_ratio, 4)
    result["score"] = round(score, 4)

    return result