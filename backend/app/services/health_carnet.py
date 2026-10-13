# app/services/health_carnet.py
"""
Render HTML imprimible del carnet de salud compartido.

Es la página que abre el veterinario al escanear el QR (no necesita la app
ni cuenta). Todo dato del usuario pasa por html.escape().
Paleta "Clean Tech Recovery" del README.
"""

from html import escape
from typing import Optional

from app.core.health_schemas import HealthCardSchema
from app.services.health_logic import DEWORMING_LABELS, parse_date, parse_datetime, BOLIVIA_TZ


TRUST_BLUE = "#0047AB"
EMERALD_GREEN = "#50C878"
PANIC_RED = "#DC3545"
SURFACE = "#FAF8FF"
OUTLINE = "#737784"

_STATUS = {
    "up_to_date":  ("Al día", EMERALD_GREEN),
    "due_soon":    ("Próxima a vencer", "#E8A317"),
    "overdue":     ("Vencida", PANIC_RED),
    "no_due_date": ("Sin refuerzo", OUTLINE),
    "superseded":  ("Renovada", OUTLINE),
    "no_records":  ("Sin registros", OUTLINE),
}

_SEX = {"male": "Macho", "female": "Hembra", "unknown": "—"}

_VACCINE_TYPES = {
    "rabies": "Antirrábica", "polyvalent": "Polivalente", "leptospirosis": "Leptospirosis",
    "bordetella": "Bordetella", "other": "Otra",
}

_DOC_TYPES = {
    "vaccine_certificate": "Certificado de vacuna", "lab_result": "Análisis de laboratorio",
    "xray": "Radiografía", "prescription": "Receta", "other": "Otro",
}


def _e(value: object) -> str:
    return escape("" if value is None else str(value))


def _d(value: Optional[str]) -> str:
    parsed = parse_date(value)
    return parsed.strftime("%d/%m/%Y") if parsed else "—"


def _dt(value: Optional[str]) -> str:
    parsed = parse_datetime(value)
    return parsed.astimezone(BOLIVIA_TZ).strftime("%d/%m/%Y %H:%M") if parsed else "—"


def _chip(status: str) -> str:
    label, color = _STATUS.get(status, (status, OUTLINE))
    return f'<span class="chip" style="background:{color}">{_e(label)}</span>'


def _table(headers: list[str], rows: list[list[str]], empty: str) -> str:
    if not rows:
        return f'<p class="empty">{_e(empty)}</p>'
    head = "".join(f"<th>{_e(h)}</th>" for h in headers)
    body = "".join("<tr>" + "".join(f"<td>{cell}</td>" for cell in row) + "</tr>" for row in rows)
    return f'<div class="scroll"><table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>'


def render_carnet_html(card: HealthCardSchema) -> str:
    pet, prof = card.pet, card.profile

    photo = (
        f'<img class="photo" src="{_e(pet.photo_url)}" alt="">' if pet.photo_url
        else '<div class="photo placeholder">🐾</div>'
    )
    age = f"{prof.age_months // 12} a {prof.age_months % 12} m" if prof.age_months is not None else (
        f"{pet.age_years} años" if pet.age_years is not None else "—"
    )
    weight = f"{card.latest_weight.weight_kg:g} kg ({_d(card.latest_weight.measured_at)})" if card.latest_weight else "—"

    facts = [
        ("Raza", _e(pet.breed or "—")), ("Sexo", _SEX.get(prof.sex, "—")), ("Edad", _e(age)),
        ("Nacimiento", _d(prof.birth_date)), ("Color", _e(prof.color or "—")),
        ("Esterilizado", "Sí" if prof.is_sterilized else "No"), ("Peso", _e(weight)),
        ("Microchip", _e(prof.microchip_id or "—")), ("Grupo sanguíneo", _e(prof.blood_type or "—")),
    ]
    facts_html = "".join(f"<div><span>{label}</span><strong>{value}</strong></div>" for label, value in facts)

    alerts = ""
    if prof.allergies or prof.chronic_conditions:
        items = "".join(f"<li><b>Alergia:</b> {_e(a)}</li>" for a in prof.allergies)
        items += "".join(f"<li><b>Condición crónica:</b> {_e(c)}</li>" for c in prof.chronic_conditions)
        alerts = f'<section class="alert"><h2>⚠ Alertas médicas</h2><ul>{items}</ul></section>'

    vaccines = _table(
        ["Vacuna", "Tipo", "Dosis", "Aplicada", "Refuerzo", "Lote", "Veterinario", "Estado"],
        [[
            _e(v.vaccine_name), _e(_VACCINE_TYPES.get(v.vaccine_type, v.vaccine_type)), _e(v.dose_number or "—"),
            _d(v.applied_at), _d(v.next_due_at), _e(v.batch_number or "—"),
            _e(" · ".join(x for x in (v.vet_name, v.clinic_name) if x) or "—"), _chip(v.due_status),
        ] for v in card.vaccinations],
        "Sin vacunas registradas.",
    )
    dewormings = _table(
        ["Producto", "Tipo", "Aplicada", "Próxima", "Peso", "Estado"],
        [[
            _e(d.product_name), _e(DEWORMING_LABELS.get(d.deworming_type, d.deworming_type)),
            _d(d.applied_at), _d(d.next_due_at), _e(f"{d.weight_kg:g} kg" if d.weight_kg else "—"),
            _chip(d.due_status),
        ] for d in card.dewormings],
        "Sin desparasitaciones registradas.",
    )
    medications = _table(
        ["Medicamento", "Dosis", "Frecuencia", "Desde", "Hasta", "Recetado por"],
        [[
            _e(m.name), _e(m.dosage or "—"), _e(m.frequency or "—"),
            _d(m.start_date), _d(m.end_date), _e(m.prescribed_by or "—"),
        ] for m in card.active_medications],
        "Sin tratamientos activos.",
    )
    visits = _table(
        ["Fecha", "Motivo", "Diagnóstico", "Tratamiento", "Veterinario"],
        [[
            _d(v.visit_date), _e(v.reason), _e(v.diagnosis or "—"), _e(v.treatment or "—"),
            _e(" · ".join(x for x in (v.vet_name, v.clinic_name) if x) or "—"),
        ] for v in card.recent_visits],
        "Sin consultas registradas.",
    )
    documents = "".join(
        f'<li><a href="{_e(doc.url)}" target="_blank" rel="noopener">{_e(doc.title)}</a>'
        f' <small>({_e(_DOC_TYPES.get(doc.doc_type, doc.doc_type))} · {_d(doc.issued_at)})</small></li>'
        for doc in card.documents if doc.url
    ) or '<li class="empty">Sin documentos adjuntos.</li>'

    vet = " · ".join(_e(x) for x in (prof.vet_name, prof.vet_clinic, prof.vet_phone) if x) or "—"
    diet = (
        f'<p style="margin:6px 0 0;font-size:.85rem"><b>Dieta:</b> {_e(prof.diet_notes)}</p>'
        if prof.diet_notes else ""
    )

    return f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Carnet de {_e(pet.name)} · ChowTrack</title>
<style>
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
         background: {SURFACE}; color: #000; }}
  header {{ background: {TRUST_BLUE}; color: #fff; padding: 20px 16px; display: flex; gap: 16px; align-items: center; }}
  header h1 {{ margin: 0; font-size: 1.5rem; }}
  header p {{ margin: 4px 0 0; opacity: .85; font-size: .9rem; }}
  .photo {{ width: 72px; height: 72px; border-radius: 50%; object-fit: cover; border: 3px solid #fff; background: #fff; }}
  .placeholder {{ display: grid; place-items: center; font-size: 2rem; }}
  main {{ max-width: 960px; margin: 0 auto; padding: 16px; }}
  section {{ background: #fff; border: 1px solid #e3e1ea; border-radius: 12px; padding: 16px; margin-bottom: 16px; }}
  h2 {{ margin: 0 0 12px; font-size: 1.05rem; color: {TRUST_BLUE}; display: flex; gap: 8px; align-items: center; }}
  .facts {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 12px; }}
  .facts span {{ display: block; font-size: .75rem; color: {OUTLINE}; }}
  .alert {{ border-color: {PANIC_RED}; }}
  .alert h2 {{ color: {PANIC_RED}; }}
  .alert ul {{ margin: 0; padding-left: 20px; }}
  .scroll {{ overflow-x: auto; }}
  table {{ width: 100%; border-collapse: collapse; font-size: .85rem; }}
  th, td {{ text-align: left; padding: 8px 6px; border-bottom: 1px solid #eee; vertical-align: top; }}
  th {{ color: {OUTLINE}; font-weight: 600; white-space: nowrap; }}
  .chip {{ color: #fff; border-radius: 999px; padding: 2px 10px; font-size: .75rem; white-space: nowrap; }}
  .empty {{ color: {OUTLINE}; font-style: italic; margin: 0; }}
  footer {{ text-align: center; color: {OUTLINE}; font-size: .75rem; padding: 8px 16px 24px; }}
  @media print {{ header {{ -webkit-print-color-adjust: exact; print-color-adjust: exact; }} section {{ break-inside: avoid; }} }}
</style>
</head>
<body>
<header>
  {photo}
  <div>
    <h1>{_e(pet.name)}</h1>
    <p>Carnet de salud digital · ChowTrack</p>
  </div>
</header>
<main>
  <section><h2>Ficha</h2><div class="facts">{facts_html}</div>
    <p style="margin:12px 0 0;font-size:.85rem"><b>Veterinario de cabecera:</b> {vet}</p>
    {diet}
  </section>
  {alerts}
  <section><h2>Cartilla de vacunación {_chip(card.vaccination_status)}</h2>{vaccines}</section>
  <section><h2>Desparasitaciones {_chip(card.deworming_status)}</h2>{dewormings}</section>
  <section><h2>Tratamientos activos</h2>{medications}</section>
  <section><h2>Consultas recientes</h2>{visits}</section>
  <section><h2>Documentos</h2><ul style="margin:0;padding-left:20px">{documents}</ul></section>
</main>
<footer>Generado el {_dt(card.generated_at)} · Enlace válido hasta {_dt(card.expires_at)} · Datos registrados por el dueño de la mascota.</footer>
</body>
</html>"""
