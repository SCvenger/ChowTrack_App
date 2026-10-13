"""
TIPO 1 — Unit tests de LÓGICA PURA (funciones sin dependencias externas)

Probamos funciones que reciben datos y devuelven un resultado, sin BD ni red:
  - _haversine()          → distancia en metros (filtro de radio del mapa)
  - _within_last_hour()   → regla de 1 hora para el pin verde (status home)
  - nose_sift (serialización y matching) → base de la biometría nasal

Patrón usado: AAA (Arrange - Act - Assert).
"""

from datetime import datetime, timedelta, timezone

import numpy as np
import pytest

from app.routes.map import _haversine, _within_last_hour
from app.services import nose_sift

# Plaza 14 de Septiembre, Cochabamba (fallback del mapa en la app)
COCHA_LAT, COCHA_LNG = -17.3895, -66.1568


# ════════════════════════════════════════════════════════════════════════════
# _haversine
# ════════════════════════════════════════════════════════════════════════════

def test_haversine_mismo_punto_es_cero():
    assert _haversine(COCHA_LAT, COCHA_LNG, COCHA_LAT, COCHA_LNG) == 0


def test_haversine_un_grado_de_latitud_son_111_km():
    # Arrange: dos puntos separados exactamente 1° de latitud
    lat2 = COCHA_LAT + 1
    # Act
    distancia = _haversine(COCHA_LAT, COCHA_LNG, lat2, COCHA_LNG)
    # Assert: ~111.2 km (tolerancia de 500 m)
    assert distancia == pytest.approx(111_195, abs=500)


def test_haversine_es_simetrica():
    ida = _haversine(COCHA_LAT, COCHA_LNG, -17.40, -66.17)
    vuelta = _haversine(-17.40, -66.17, COCHA_LAT, COCHA_LNG)
    assert ida == pytest.approx(vuelta)


def test_haversine_mascota_cercana_dentro_del_radio_de_5km():
    # Mascota a ~1.1 km del usuario → debe entrar en el radio por defecto
    distancia = _haversine(COCHA_LAT, COCHA_LNG, -17.3795, -66.1568)
    assert distancia < 5000


# ════════════════════════════════════════════════════════════════════════════
# _within_last_hour  (regla del pin verde)
# ════════════════════════════════════════════════════════════════════════════

NOW = datetime(2026, 10, 7, 12, 0, 0, tzinfo=timezone.utc)


def test_hace_10_minutos_esta_dentro_de_la_hora():
    ts = (NOW - timedelta(minutes=10)).isoformat()
    assert _within_last_hour(ts, NOW) is True


def test_hace_2_horas_ya_no_se_muestra():
    ts = (NOW - timedelta(hours=2)).isoformat()
    assert _within_last_hour(ts, NOW) is False


def test_justo_una_hora_es_el_limite_incluido():
    ts = (NOW - timedelta(hours=1)).isoformat()
    assert _within_last_hour(ts, NOW) is True


def test_acepta_sufijo_Z_de_supabase():
    assert _within_last_hour("2026-10-07T11:30:00Z", NOW) is True


def test_timestamp_sin_zona_horaria_se_asume_utc():
    assert _within_last_hour("2026-10-07T11:30:00", NOW) is True


@pytest.mark.parametrize("valor_invalido", [None, "", "no-es-fecha", "2026-99-99"])
def test_timestamp_invalido_devuelve_false(valor_invalido):
    assert _within_last_hour(valor_invalido, NOW) is False


# ════════════════════════════════════════════════════════════════════════════
# nose_sift — biometría nasal
# ════════════════════════════════════════════════════════════════════════════

def test_serializar_y_deserializar_huella_no_pierde_datos():
    # Arrange: keypoints (x,y) y descriptores SIFT de 128 dimensiones
    rng = np.random.default_rng(42)
    keypoints = rng.random((50, 2), dtype=np.float32)
    descriptores = rng.random((50, 128), dtype=np.float32)

    # Act: ida y vuelta por base64 (así se guarda en nose_embeddings)
    texto = nose_sift.serialize_features(keypoints, descriptores)
    kp2, des2 = nose_sift.deserialize_features(texto)

    # Assert
    assert isinstance(texto, str)
    np.testing.assert_array_equal(kp2, keypoints)
    np.testing.assert_array_equal(des2, descriptores)


def test_matching_sin_descriptores_devuelve_lista_vacia():
    assert nose_sift._flann_good_matches(None, None) == []


def test_matching_con_pocos_matches_da_score_cero():
    # Con menos de MIN_GOOD_FOR_RANSAC matches no hay verificación geométrica
    des = np.zeros((1, 128), dtype=np.float32)
    kp = np.zeros((1, 2), dtype=np.float32)
    resultado = nose_sift.match_with_geometry(kp, des, kp, des)
    assert resultado["score"] == 0.0
    assert resultado["inliers"] == 0


def test_misma_huella_supera_umbral_y_distinta_no():
    """
    Compara una huella sintética consigo misma (desplazada) y contra otra
    totalmente distinta. La misma debe puntuar alto; la distinta, ~0.
    """
    rng = np.random.default_rng(7)
    n = 300
    kp = rng.random((n, 2), dtype=np.float32) * 500
    des = rng.random((n, 128), dtype=np.float32)

    kp_desplazado = kp + np.float32(20)  # misma nariz, foto movida
    otra_kp = rng.random((n, 2), dtype=np.float32) * 500
    otra_des = rng.random((n, 128), dtype=np.float32)

    mismo = nose_sift.match_with_geometry(kp, des, kp_desplazado, des)
    distinto = nose_sift.match_with_geometry(kp, des, otra_kp, otra_des)

    MATCH_THRESHOLD = 2.2015  # mismo valor que app/routes/nose.py
    assert mismo["score"] > MATCH_THRESHOLD
    assert distinto["score"] < MATCH_THRESHOLD
