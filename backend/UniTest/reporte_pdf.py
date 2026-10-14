"""
reporte_pdf.py — Plugin de pytest: cada vez que se ejecuta un archivo de
tests listado en REPORTES, se genera automáticamente un PDF con el resultado.

No hay que hacer nada extra: basta con correr

    pytest test_registro_mascota.py
    pytest test_login.py

y al final aparece la ruta del PDF. Cada ejecución queda registrada:
  reportes/<carpeta>/<Prefijo>_<fecha>.pdf
  reportes/<carpeta>/historial.json   (lista de ejecuciones)

Para que otro archivo de tests genere su PDF, agrégalo a REPORTES.
Se activa desde conftest.py con:  pytest_plugins = ["reporte_pdf"]
"""

import json
import platform
from datetime import datetime
from pathlib import Path

import pytest

REPORTES = {
    "test_registro_mascota.py": {
        "titulo": "Registro de mascotas (POST /pets/)",
        "carpeta": "registro_mascotas",
        "prefijo": "Reporte_Registro_Mascotas",
        "intro": "Las pruebas verifican las reglas de validación de una mascota nueva y la "
                 "lógica del endpoint de registro.",
    },
    "test_login.py": {
        "titulo": "Inicio de sesión (POST /auth/login)",
        "carpeta": "login",
        "prefijo": "Reporte_Login",
        "intro": "Las pruebas verifican el inicio de sesión con email o nombre de usuario, "
                 "y que las credenciales incorrectas se rechacen.",
    },
}
BASE = Path(__file__).parent / "reportes"

VERDE = (46, 125, 50)
ROJO = (198, 40, 40)
GRIS = (110, 110, 110)
AZUL = (21, 101, 192)

_resultados: dict[str, list[dict]] = {}   # archivo de tests → resultados


# ════════════════════════════════════════════════════════════════════════════
# 1. Recolectar el resultado de cada test
# ════════════════════════════════════════════════════════════════════════════

@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    rep = (yield).get_result()
    modulo = item.path.name
    if modulo not in REPORTES:
        return
    # Se registra la ejecución del test ("call") o un fallo al prepararlo ("setup")
    if rep.when == "call" or (rep.when == "setup" and not rep.passed):
        _resultados.setdefault(modulo, []).append({
            "nombre": item.originalname,
            "dato": item.callspec.id if hasattr(item, "callspec") else "",
            "descripcion": (item.function.__doc__ or "").strip(),
            "estado": _estado(rep),
            "ms": rep.duration * 1000,
            "retro": _retroalimentacion(rep, modulo),
        })


def _estado(rep) -> str:
    if rep.passed:
        return "PASÓ"
    if rep.skipped:
        return "OMITIDO"
    return "FALLÓ" if rep.when == "call" else "ERROR"


def _retroalimentacion(rep, modulo: str) -> str:
    """Las líneas 'E ...' de pytest: qué se esperaba y qué llegó."""
    if rep.passed:
        return ""
    lineas = [l[1:].strip() for l in rep.longreprtext.splitlines() if l.startswith("E ")]
    lineas = [l for l in lineas if l and not l.startswith("For further information")]
    crash = getattr(rep.longrepr, "reprcrash", None)
    ubicacion = f"Línea {crash.lineno} de {modulo}" if crash else ""
    return "\n".join(filter(None, [ubicacion, *lineas[:8]])) or rep.longreprtext[-400:]


# ════════════════════════════════════════════════════════════════════════════
# 2. Al terminar: guardar historial y generar el PDF
# ════════════════════════════════════════════════════════════════════════════

def pytest_terminal_summary(terminalreporter):
    if not _resultados:
        return
    try:
        from fpdf import FPDF  # noqa: F401
    except ImportError:
        terminalreporter.write_line(
            "AVISO: no se generó el PDF. Instala fpdf2:  pip install fpdf2==2.8.4", yellow=True)
        return

    ahora = datetime.now()
    for modulo, resultados in _resultados.items():
        _reportar(terminalreporter, REPORTES[modulo], resultados, ahora)


def _reportar(terminalreporter, info: dict, resultados: list[dict], ahora: datetime) -> None:
    carpeta = BASE / info["carpeta"]
    carpeta.mkdir(parents=True, exist_ok=True)
    historial_json = carpeta / "historial.json"
    destino = carpeta / f"{info['prefijo']}_{ahora:%Y-%m-%d_%H-%M-%S}.pdf"

    fallaron = sum(r["estado"] in ("FALLÓ", "ERROR") for r in resultados)
    historial = _leer_historial(historial_json) + [{
        "fecha": ahora.strftime("%d/%m/%Y %H:%M:%S"),
        "total": len(resultados),
        "pasaron": sum(r["estado"] == "PASÓ" for r in resultados),
        "fallaron": fallaron,
        "resultado": "APROBADO" if fallaron == 0 else "CON FALLAS",
        "archivo": destino.name,
    }]

    try:
        _generar_pdf(destino, ahora, historial, resultados, info)
    except Exception as e:  # un error del PDF no debe tapar el resultado de los tests
        terminalreporter.write_line(f"AVISO: no se pudo generar el PDF: {e}", yellow=True)
        return

    historial_json.write_text(json.dumps(historial, indent=2, ensure_ascii=False), encoding="utf-8")
    terminalreporter.write_sep("=", f"Reporte PDF generado ({info['carpeta']})")
    terminalreporter.write_line(str(destino), green=fallaron == 0, red=fallaron > 0)


def _leer_historial(ruta: Path) -> list[dict]:
    try:
        return json.loads(ruta.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return []


# ════════════════════════════════════════════════════════════════════════════
# 3. Armar el PDF
# ════════════════════════════════════════════════════════════════════════════

def _txt(s) -> str:
    """Las fuentes básicas del PDF solo soportan latin-1."""
    return str(s).encode("latin-1", "replace").decode("latin-1")


def _generar_pdf(destino: Path, ahora: datetime, historial: list[dict],
                 resultados: list[dict], info: dict) -> None:
    from fpdf import FPDF

    total = len(resultados)
    pasaron = sum(r["estado"] == "PASÓ" for r in resultados)
    fallaron = total - pasaron
    aprobado = fallaron == 0
    duracion = sum(r["ms"] for r in resultados)

    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()

    def titulo(texto):
        pdf.ln(4)
        pdf.set_font("Helvetica", "B", 13)
        pdf.set_text_color(*AZUL)
        pdf.cell(0, 8, _txt(texto), new_x="LMARGIN", new_y="NEXT")
        pdf.set_draw_color(*AZUL)
        pdf.line(pdf.l_margin, pdf.get_y(), pdf.w - pdf.r_margin, pdf.get_y())
        pdf.ln(3)
        pdf.set_text_color(0, 0, 0)

    def parrafo(alto, texto):
        pdf.multi_cell(0, alto, _txt(texto), align="L", new_x="LMARGIN", new_y="NEXT")

    def dato(etiqueta, valor, color=None):
        pdf.set_font("Helvetica", "B", 10)
        pdf.cell(50, 7, _txt(etiqueta))
        pdf.set_font("Helvetica", "", 10)
        if color:
            pdf.set_text_color(*color)
        pdf.cell(0, 7, _txt(valor), new_x="LMARGIN", new_y="NEXT")
        pdf.set_text_color(0, 0, 0)

    def encabezado_tabla(columnas):
        pdf.set_font("Helvetica", "B", 9)
        pdf.set_fill_color(230, 236, 245)
        for texto, ancho in columnas:
            pdf.cell(ancho, 7, _txt(texto), border=1, fill=True, align="C")
        pdf.ln()
        pdf.set_font("Helvetica", "", 8.5)

    # ── Encabezado ───────────────────────────────────────────────────────
    pdf.set_font("Helvetica", "B", 17)
    pdf.cell(0, 10, _txt("Reporte de Pruebas Unitarias"), new_x="LMARGIN", new_y="NEXT", align="C")
    pdf.set_font("Helvetica", "", 11)
    pdf.set_text_color(*GRIS)
    pdf.cell(0, 6, _txt(f"ChowTrack - {info['titulo']}"),
             new_x="LMARGIN", new_y="NEXT", align="C")
    pdf.cell(0, 6, _txt(ahora.strftime("Ejecutado el %d/%m/%Y a las %H:%M:%S")),
             new_x="LMARGIN", new_y="NEXT", align="C")
    pdf.set_text_color(0, 0, 0)

    # ── 1. Resumen ───────────────────────────────────────────────────────
    titulo("1. Resumen")
    dato("Resultado general:", "APROBADO" if aprobado else "CON FALLAS", VERDE if aprobado else ROJO)
    dato("Pruebas ejecutadas:", str(total))
    dato("Pasaron:", f"{pasaron} ({pasaron / total:.0%})", VERDE)
    dato("Fallaron:", str(fallaron), ROJO if fallaron else None)
    dato("Duración:", f"{duracion:.0f} ms")
    dato("Entorno:", f"Python {platform.python_version()} - {platform.system()} - pytest {pytest.__version__}")
    pdf.ln(2)
    pdf.set_font("Helvetica", "I", 9)
    pdf.set_text_color(*GRIS)
    parrafo(5,
        f"{info['intro']} La base de datos se reemplaza por una simulada (mock), "
        "por lo que no se usa internet ni la base de datos real.")
    pdf.set_text_color(0, 0, 0)

    # ── 2. Detalle ───────────────────────────────────────────────────────
    titulo("2. Detalle de cada prueba")
    encabezado_tabla([("#", 9), ("Qué se verifica", 142), ("Estado", 22), ("ms", 17)])
    for i, r in enumerate(resultados, 1):
        descripcion = r["descripcion"] or r["nombre"]
        if r["dato"]:
            descripcion += f"  [dato: {r['dato']}]"
        pdf.cell(9, 6, str(i), border=1, align="C")
        pdf.cell(142, 6, _txt(descripcion[:88]), border=1)
        pdf.set_text_color(*(VERDE if r["estado"] == "PASÓ" else ROJO))
        pdf.set_font("Helvetica", "B", 8.5)
        pdf.cell(22, 6, _txt(r["estado"]), border=1, align="C")
        pdf.set_text_color(0, 0, 0)
        pdf.set_font("Helvetica", "", 8.5)
        pdf.cell(17, 6, f"{r['ms']:.1f}", border=1, align="C", new_x="LMARGIN", new_y="NEXT")

    # ── 3. Retroalimentación ─────────────────────────────────────────────
    titulo("3. Retroalimentación")
    fallidos = [r for r in resultados if r["estado"] != "PASÓ"]
    if not fallidos:
        pdf.set_font("Helvetica", "", 10)
        pdf.set_text_color(*VERDE)
        parrafo(6, "Todas las pruebas pasaron. No hay fallos que reportar.")
        pdf.set_text_color(0, 0, 0)
    for r in fallidos:
        pdf.set_font("Helvetica", "B", 9.5)
        pdf.set_text_color(*ROJO)
        parrafo(5, f"{r['estado']}: {r['nombre']}")
        pdf.set_text_color(0, 0, 0)
        if r["descripcion"]:
            pdf.set_font("Helvetica", "I", 9)
            parrafo(5, f"Se esperaba: {r['descripcion']}")
        pdf.set_font("Courier", "", 8)
        parrafo(4, r["retro"])
        pdf.ln(3)

    # ── 4. Historial ─────────────────────────────────────────────────────
    titulo("4. Historial de ejecuciones (últimas 10)")
    encabezado_tabla([("Fecha", 45), ("Total", 22), ("Pasaron", 25), ("Fallaron", 25), ("Resultado", 35)])
    for h in historial[-10:]:
        ok = h["resultado"] == "APROBADO"
        pdf.cell(45, 6, _txt(h["fecha"]), border=1, align="C")
        pdf.cell(22, 6, str(h["total"]), border=1, align="C")
        pdf.cell(25, 6, str(h["pasaron"]), border=1, align="C")
        pdf.cell(25, 6, str(h["fallaron"]), border=1, align="C")
        pdf.set_text_color(*(VERDE if ok else ROJO))
        pdf.cell(35, 6, _txt(h["resultado"]), border=1, align="C", new_x="LMARGIN", new_y="NEXT")
        pdf.set_text_color(0, 0, 0)

    pdf.output(str(destino))
