"""
resultados_a_serenity.py — Convierte los resultados de pytest y flutter test al
formato JSON de Serenity BDD, para que `mvn verify` (serenity-maven-plugin)
genere el reporte HTML de Serenity.

Serenity no ejecuta pruebas de Python ni de Dart. Este script NO inventa
resultados: lee los archivos que generan las pruebas reales y traduce cada
caso (nombre, archivo, duración, resultado y error) a un "test outcome".

Entradas (por defecto, relativas a la raíz del proyecto):
  .ci-reports/backend/resultados.xml    → JUnit XML de pytest
  .ci-reports/frontend/resultados.json  → reporte JSON de flutter test

Salida:
  qa/serenity/target/site/serenity/*.json

Uso:
  python qa/serenity/resultados_a_serenity.py [--raiz RUTA]

Solo usa la librería estándar de Python.
"""

import argparse
import hashlib
import json
import shutil
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path

ZONA = timezone(timedelta(hours=-4))  # Bolivia, sin horario de verano
ZONA_ID = "America/La_Paz"

# Nombre legible de cada archivo de pruebas (la "feature" en Serenity).
FEATURES = {
    "test_1_logica_pura": "Backend - Lógica pura (distancia, regla de 1 hora, SIFT)",
    "test_2_validacion_datos": "Backend - Validación de datos de entrada",
    "test_3_con_mocks": "Backend - Endpoints con Supabase simulado",
    "test_4_salud": "Backend - Módulo Salud (carnet veterinario)",
    "test_login": "Backend - Inicio de sesión (esquema)",
    "test_registro_mascota": "Backend - Registro de mascota",
    "health_module_test": "Frontend - Módulo Salud",
    "ux_fixes_test": "Frontend - Validaciones y accesibilidad",
    "pet_detail_view_test": "Frontend - Detalle de mascota",
    "widget_test": "Frontend - Pantalla de acceso",
}


def fecha_serenity(dt: datetime) -> str:
    """Formato ZonedDateTime de Java: 2026-11-18T17:06:10.123-04:00[America/La_Paz]"""
    return dt.astimezone(ZONA).isoformat(timespec="milliseconds") + f"[{ZONA_ID}]"


def slug(texto: str) -> str:
    return "".join(c if c.isalnum() else "-" for c in texto.lower()).strip("-")


def outcome(*, capa, archivo, nombre, resultado, duracion_ms, inicio, error=None):
    feature = FEATURES.get(archivo, f"{capa} - {archivo}")
    story_id = slug(archivo)
    titulo = nombre.replace("_", " ").strip()
    if titulo.lower().startswith("test "):
        titulo = titulo[5:]
    titulo = titulo[:1].upper() + titulo[1:]
    fin = inicio + timedelta(milliseconds=duracion_ms)

    paso = {
        "number": 1,
        "description": f"Ejecutar {archivo} :: {nombre}",
        "duration": duracion_ms,
        "startTime": fecha_serenity(inicio),
        "screenshots": [],
        "result": resultado,
        "precondition": False,
        "level": 0,
    }
    datos = {
        "name": titulo,
        "id": f"{story_id};{slug(nombre)}",
        "scenarioId": f"{story_id}:{nombre}",
        "methodName": nombre,
        "testSteps": [paso],
        "userStory": {
            "id": story_id,
            "storyName": feature,
            "displayName": feature,
            "path": capa.lower(),
            "pathElements": [{"name": capa.lower(), "description": capa}],
            "type": "feature",
        },
        "title": titulo,
        "description": "",
        "tags": [
            {"name": capa, "type": "capa", "displayName": capa},
            {"name": feature, "type": "feature", "displayName": feature},
            {"name": "pytest" if capa == "Backend" else "flutter test",
             "type": "herramienta",
             "displayName": "pytest" if capa == "Backend" else "flutter test"},
        ],
        "startTime": fecha_serenity(inicio),
        "endTime": fecha_serenity(fin),
        "duration": duracion_ms,
        "projectKey": "",
        "manual": False,
        "testSource": "JUnit",
        "result": resultado,
    }
    if error:
        tipo, mensaje = error
        falla = {"errorType": tipo, "message": mensaje[:4000], "stackTrace": []}
        paso["exception"] = falla
        datos["testFailureCause"] = falla
        datos["testFailureClassname"] = tipo
        datos["testFailureMessage"] = mensaje[:4000]
    return datos


def desde_pytest(xml_path: Path):
    raiz = ET.parse(xml_path).getroot()
    suites = [raiz] if raiz.tag == "testsuite" else raiz.findall("testsuite")
    for suite in suites:
        ts = suite.get("timestamp")
        inicio = datetime.fromisoformat(ts) if ts else datetime.now(ZONA)
        if inicio.tzinfo is None:
            inicio = inicio.astimezone()
        for caso in suite.findall("testcase"):
            archivo = (caso.get("classname") or "").split(".")[-1]
            dur = int(float(caso.get("time") or 0) * 1000)
            resultado, error = "SUCCESS", None
            for etiqueta, res in (("failure", "FAILURE"), ("error", "ERROR")):
                nodo = caso.find(etiqueta)
                if nodo is not None:
                    resultado = res
                    error = (nodo.get("type") or etiqueta,
                             (nodo.get("message") or "") + "\n" + (nodo.text or ""))
            if caso.find("skipped") is not None:
                resultado = "SKIPPED"
            yield outcome(capa="Backend", archivo=archivo, nombre=caso.get("name"),
                          resultado=resultado, duracion_ms=dur, inicio=inicio,
                          error=error)
            inicio += timedelta(milliseconds=dur)


def desde_flutter(json_path: Path):
    suites, pruebas, errores = {}, {}, {}
    eventos = [json.loads(l) for l in json_path.read_text(encoding="utf-8").splitlines()
               if l.strip().startswith("{")]
    # Los tiempos de flutter son milisegundos desde el inicio; el archivo se
    # termina de escribir al final, así que su fecha marca el último evento.
    fin = datetime.fromtimestamp(json_path.stat().st_mtime, ZONA)
    inicio_base = fin - timedelta(milliseconds=max((e.get("time", 0) for e in eventos), default=0))
    for ev in eventos:
            tipo = ev.get("type")
            if tipo == "suite":
                suites[ev["suite"]["id"]] = ev["suite"]["path"]
            elif tipo == "testStart":
                pruebas[ev["test"]["id"]] = ev["test"] | {"inicio": ev.get("time", 0)}
            elif tipo == "error":
                errores.setdefault(ev["testID"], []).append(ev.get("error", ""))
            elif tipo == "testDone" and not ev.get("hidden"):
                t = pruebas[ev["testID"]]
                archivo = Path(suites.get(t["suiteID"], "desconocido")).stem
                res = {"success": "SUCCESS", "failure": "FAILURE",
                       "error": "ERROR"}.get(ev.get("result"), "ERROR")
                if ev.get("skipped"):
                    res = "SKIPPED"
                errs = errores.get(ev["testID"])
                inicio = inicio_base + timedelta(milliseconds=t["inicio"])
                yield outcome(capa="Frontend", archivo=archivo, nombre=t["name"],
                              resultado=res,
                              duracion_ms=max(0, ev.get("time", 0) - t["inicio"]),
                              inicio=inicio,
                              error=("TestFailure", "\n".join(errs)) if errs else None)


def main():
    aqui = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--raiz", type=Path, default=aqui.parents[1],
                    help="Raíz del proyecto ChowTrack (por defecto, dos niveles arriba)")
    args = ap.parse_args()

    backend = args.raiz / ".ci-reports" / "backend" / "resultados.xml"
    frontend = args.raiz / ".ci-reports" / "frontend" / "resultados.json"
    salida = aqui / "target" / "site" / "serenity"
    if salida.exists():
        shutil.rmtree(salida)
    salida.mkdir(parents=True)

    totales = {}
    for nombre, ruta, lector in (("backend", backend, desde_pytest),
                                 ("frontend", frontend, desde_flutter)):
        if not ruta.exists():
            print(f"[AVISO] No existe {ruta}; se omite {nombre}.")
            continue
        n = 0
        for datos in lector(ruta):
            h = hashlib.sha256(datos["id"].encode()).hexdigest()
            (salida / f"{h}.json").write_text(
                json.dumps(datos, ensure_ascii=False), encoding="utf-8")
            n += 1
            totales[datos["result"]] = totales.get(datos["result"], 0) + 1
        print(f"{nombre}: {n} pruebas convertidas desde {ruta}")

    if not totales:
        print("[ERROR] No se encontró ningún resultado de pruebas.")
        sys.exit(1)
    print("Resultados:", ", ".join(f"{k}={v}" for k, v in sorted(totales.items())))
    print(f"JSON de Serenity en: {salida}")


if __name__ == "__main__":
    main()
