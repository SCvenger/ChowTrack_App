"""
generar_reporte.py — Ejecuta los unit tests y genera los reportes.

Uso (desde backend/UniTest):
    .venv\\Scripts\\python generar_reporte.py

Genera en la carpeta reportes/:
    reporte_tests.html        → resultado de cada test (abrir en navegador)
    cobertura_html/index.html → % de código cubierto, línea por línea
    Reporte_QA_ChowTrack.pdf  → resumen para entregar en la plataforma
    resultados.xml / cobertura.json → datos crudos usados para armar el PDF
"""

import json
import platform
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

from fpdf import FPDF

BASE = Path(__file__).parent
OUT = BASE / "reportes"

TIPOS = {
    "test_1_logica_pura": "Tipo 1 - Lógica pura",
    "test_2_validacion_datos": "Tipo 2 - Validación de datos",
    "test_3_con_mocks": "Tipo 3 - Con mocks",
}

VERDE = (46, 125, 50)
ROJO = (198, 40, 40)
GRIS = (110, 110, 110)
AZUL = (21, 101, 192)


# ════════════════════════════════════════════════════════════════════════════
# 1. Ejecutar pytest
# ════════════════════════════════════════════════════════════════════════════

def ejecutar_tests() -> int:
    OUT.mkdir(exist_ok=True)
    cmd = [
        sys.executable, "-m", "pytest",
        f"--html={OUT / 'reporte_tests.html'}", "--self-contained-html",
        f"--junitxml={OUT / 'resultados.xml'}",
        "--cov", "--cov-config=.coveragerc",
        f"--cov-report=html:{OUT / 'cobertura_html'}",
        f"--cov-report=json:{OUT / 'cobertura.json'}",
        "--cov-report=term",
    ]
    return subprocess.call(cmd, cwd=BASE)


# ════════════════════════════════════════════════════════════════════════════
# 2. Leer resultados
# ════════════════════════════════════════════════════════════════════════════

def leer_resultados():
    root = ET.parse(OUT / "resultados.xml").getroot()
    suite = root.find("testsuite") if root.tag == "testsuites" else root

    tests = []
    for tc in suite.iter("testcase"):
        modulo = tc.get("classname", "").split(".")[-1]
        estado, mensaje = "PASÓ", ""
        for tag, nombre in (("failure", "FALLÓ"), ("error", "ERROR"), ("skipped", "OMITIDO")):
            nodo = tc.find(tag)
            if nodo is not None:
                estado, mensaje = nombre, nodo.get("message", "")
                break
        tests.append({
            "modulo": modulo,
            "nombre": tc.get("name"),
            "tiempo": float(tc.get("time", 0)),
            "estado": estado,
            "mensaje": mensaje,
        })

    cobertura = json.loads((OUT / "cobertura.json").read_text(encoding="utf-8"))
    return suite, tests, cobertura


# ════════════════════════════════════════════════════════════════════════════
# 3. Armar el PDF
# ════════════════════════════════════════════════════════════════════════════

def txt(s: str) -> str:
    """Las fuentes básicas del PDF solo soportan latin-1."""
    return str(s).encode("latin-1", "replace").decode("latin-1")


def corto(s: str, n: int = 75) -> str:
    return s if len(s) <= n else s[: n - 3] + "..."


class PDF(FPDF):
    def header(self):
        self.set_font("Helvetica", "B", 9)
        self.set_text_color(*GRIS)
        self.cell(0, 6, txt("ChowTrack - Reporte de Pruebas Unitarias"), align="R")
        self.ln(8)

    def footer(self):
        self.set_y(-12)
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*GRIS)
        self.cell(0, 6, txt(f"Página {self.page_no()}/{{nb}}"), align="C")

    def titulo(self, texto):
        self.ln(3)
        self.set_font("Helvetica", "B", 13)
        self.set_text_color(*AZUL)
        self.cell(0, 8, txt(texto), new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(*AZUL)
        self.line(self.l_margin, self.get_y(), self.w - self.r_margin, self.get_y())
        self.ln(3)
        self.set_text_color(0, 0, 0)

    def fila_dato(self, etiqueta, valor, color=None):
        self.set_font("Helvetica", "B", 10)
        self.cell(55, 7, txt(etiqueta))
        self.set_font("Helvetica", "", 10)
        if color:
            self.set_text_color(*color)
        self.cell(0, 7, txt(valor), new_x="LMARGIN", new_y="NEXT")
        self.set_text_color(0, 0, 0)

    def tabla(self, encabezados, filas, anchos, colores=None, izquierda=(1,)):
        self.set_font("Helvetica", "B", 9)
        self.set_fill_color(230, 236, 245)
        for h, w in zip(encabezados, anchos):
            self.cell(w, 7, txt(h), border=1, fill=True, align="C")
        self.ln()
        self.set_font("Helvetica", "", 8.5)
        for i, fila in enumerate(filas):
            for j, (valor, w) in enumerate(zip(fila, anchos)):
                color = colores[i][j] if colores and colores[i] and colores[i][j] else None
                if color:
                    self.set_text_color(*color)
                    self.set_font("Helvetica", "B", 8.5)
                align = "L" if j in izquierda else "C"
                self.cell(w, 6, txt(valor), border=1, align=align)
                self.set_text_color(0, 0, 0)
                self.set_font("Helvetica", "", 8.5)
            self.ln()


def generar_pdf(suite, tests, cobertura) -> Path:
    total = len(tests)
    pasaron = sum(t["estado"] == "PASÓ" for t in tests)
    fallaron = sum(t["estado"] in ("FALLÓ", "ERROR") for t in tests)
    omitidos = sum(t["estado"] == "OMITIDO" for t in tests)
    duracion = float(suite.get("time", 0))
    cob_total = cobertura["totals"]["percent_covered"]
    aprobado = fallaron == 0

    pdf = PDF()
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()

    # ── Portada / encabezado ─────────────────────────────────────────────
    pdf.set_font("Helvetica", "B", 18)
    pdf.cell(0, 10, txt("Reporte de Pruebas Unitarias"), new_x="LMARGIN", new_y="NEXT", align="C")
    pdf.set_font("Helvetica", "", 11)
    pdf.set_text_color(*GRIS)
    pdf.cell(0, 6, txt("Proyecto ChowTrack - Backend FastAPI"), new_x="LMARGIN", new_y="NEXT", align="C")
    pdf.cell(0, 6, txt(datetime.now().strftime("Generado el %d/%m/%Y a las %H:%M")),
             new_x="LMARGIN", new_y="NEXT", align="C")
    pdf.set_text_color(0, 0, 0)

    # ── 1. Resumen ───────────────────────────────────────────────────────
    pdf.titulo("1. Resumen de ejecución")
    pdf.fila_dato("Resultado general:", "APROBADO" if aprobado else "CON FALLAS",
                  VERDE if aprobado else ROJO)
    pdf.fila_dato("Total de tests:", str(total))
    pdf.fila_dato("Pasaron:", f"{pasaron} ({pasaron / total:.0%})", VERDE)
    pdf.fila_dato("Fallaron / error:", str(fallaron), ROJO if fallaron else None)
    pdf.fila_dato("Omitidos:", str(omitidos))
    pdf.fila_dato("Duración total:", f"{duracion:.2f} s")
    pdf.fila_dato("Cobertura de código:", f"{cob_total:.1f} %",
                  VERDE if cob_total >= 70 else ROJO)
    pdf.fila_dato("Entorno:", f"Python {platform.python_version()} - {platform.system()} - pytest")

    # ── 2. Resultados por tipo ───────────────────────────────────────────
    pdf.titulo("2. Resultados por tipo de prueba")
    filas, colores = [], []
    for modulo, nombre in TIPOS.items():
        grupo = [t for t in tests if t["modulo"] == modulo]
        ok = sum(t["estado"] == "PASÓ" for t in grupo)
        mal = len(grupo) - ok
        filas.append([nombre, f"{modulo}.py", str(len(grupo)), str(ok), str(mal)])
        colores.append([None, None, None, VERDE, ROJO if mal else None])
    pdf.tabla(["Tipo", "Archivo", "Tests", "Pasaron", "Fallaron"], filas,
              [50, 65, 22, 25, 25], colores, izquierda=(0, 1))

    # ── 3. Cobertura por módulo ──────────────────────────────────────────
    pdf.titulo("3. Cobertura por módulo")
    filas, colores = [], []
    for ruta, datos in sorted(cobertura["files"].items()):
        s = datos["summary"]
        nombre = "app/" + Path(ruta).as_posix().split("/app/", 1)[-1]
        pct = s["percent_covered"]
        filas.append([nombre, str(s["num_statements"]), str(s["missing_lines"]), f"{pct:.0f} %"])
        colores.append([None, None, None, VERDE if pct >= 70 else ROJO])
    pdf.tabla(["Módulo", "Líneas", "Sin cubrir", "Cobertura"], filas,
              [95, 30, 30, 32], colores, izquierda=(0,))
    pdf.set_font("Helvetica", "I", 8)
    pdf.set_text_color(*GRIS)
    pdf.multi_cell(0, 5, txt(
        "La cobertura se mide sobre los módulos bajo prueba unitaria. El detalle "
        "línea por línea está en reportes/cobertura_html/index.html."))
    pdf.set_text_color(0, 0, 0)

    # ── 4. Detalle de cada test ──────────────────────────────────────────
    pdf.add_page()
    pdf.titulo("4. Detalle de cada test")
    for modulo, nombre in TIPOS.items():
        grupo = [t for t in tests if t["modulo"] == modulo]
        if not grupo:
            continue
        pdf.set_font("Helvetica", "B", 10)
        pdf.cell(0, 8, txt(nombre), new_x="LMARGIN", new_y="NEXT")
        filas = [[str(i), corto(t["nombre"]), t["estado"], f"{t['tiempo'] * 1000:.1f}"]
                 for i, t in enumerate(grupo, 1)]
        colores = [[None, None, VERDE if t["estado"] == "PASÓ" else ROJO, None] for t in grupo]
        pdf.tabla(["#", "Test", "Estado", "ms"], filas, [10, 130, 25, 22], colores)
        pdf.ln(2)

    # ── 5. Fallos (si hay) ───────────────────────────────────────────────
    fallidos = [t for t in tests if t["estado"] in ("FALLÓ", "ERROR")]
    if fallidos:
        pdf.titulo("5. Detalle de fallos")
        for t in fallidos:
            pdf.set_font("Helvetica", "B", 9)
            pdf.set_text_color(*ROJO)
            pdf.multi_cell(0, 5, txt(f"{t['modulo']} :: {t['nombre']}"))
            pdf.set_font("Courier", "", 8)
            pdf.set_text_color(0, 0, 0)
            pdf.multi_cell(0, 4, txt(corto(t["mensaje"], 600)))
            pdf.ln(2)

    destino = OUT / "Reporte_QA_ChowTrack.pdf"
    pdf.output(str(destino))
    return destino


if __name__ == "__main__":
    codigo = ejecutar_tests()
    suite, tests, cobertura = leer_resultados()
    pdf = generar_pdf(suite, tests, cobertura)
    print("\n" + "=" * 60)
    print("Reportes generados en:", OUT)
    print("  - reporte_tests.html")
    print("  - cobertura_html/index.html")
    print("  -", pdf.name)
    print("=" * 60)
    sys.exit(codigo)
