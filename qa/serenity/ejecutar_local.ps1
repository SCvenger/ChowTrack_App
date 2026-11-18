<#
  ejecutar_local.ps1 — Ejecuta en local lo mismo que el Jenkinsfile:
  pruebas backend (pytest), pruebas frontend (flutter test) y reporte Serenity.

  Uso, desde la raíz del proyecto:
      powershell -ExecutionPolicy Bypass -File qa\serenity\ejecutar_local.ps1

  Parámetros opcionales (si tus rutas son distintas):
      -Python  ruta a python.exe con las dependencias de requirements-test.txt
      -Maven   ruta a mvn.cmd
      -Abrir   abre el reporte Serenity al terminar
#>
param(
    [string]$Python = "backend\UniTest\.venv\Scripts\python.exe",
    [string]$Maven  = "C:\Users\leona\Downloads\apache-maven-3.10.0-bin\apache-maven-3.10.0\bin\mvn.cmd",
    [switch]$Abrir
)

$ErrorActionPreference = 'Stop'
$raiz = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $raiz
$Python = (Resolve-Path $Python).Path
$rep = Join-Path $raiz '.ci-reports'

Write-Host "`n== 1/4 Preparar carpetas de reportes ==" -ForegroundColor Cyan
if (Test-Path $rep) { Remove-Item $rep -Recurse -Force }
New-Item -ItemType Directory -Force "$rep\backend", "$rep\frontend" | Out-Null

Write-Host "`n== 2/4 Pruebas backend (pytest) ==" -ForegroundColor Cyan
Push-Location backend\UniTest
& $Python -m pytest -p no:cacheprovider -q -o addopts="" `
    --junitxml="$rep\backend\resultados.xml" `
    --html="$rep\backend\index.html" --self-contained-html `
    --cov --cov-config=.coveragerc --cov-report="html:$rep\backend\cobertura"
$backend = $LASTEXITCODE
Pop-Location

Write-Host "`n== 3/4 Pruebas frontend (flutter test) ==" -ForegroundColor Cyan
Push-Location frontend
& flutter test --no-pub --file-reporter "json:$rep\frontend\resultados.json"
$frontend = $LASTEXITCODE
Pop-Location

Write-Host "`n== 4/4 Reporte Serenity ==" -ForegroundColor Cyan
& $Python qa\serenity\resultados_a_serenity.py
if ($LASTEXITCODE -ne 0) { throw "La conversión a Serenity falló." }
& $Maven -q -B -f qa\serenity\pom.xml verify
if ($LASTEXITCODE -ne 0) { throw "Maven no pudo generar el reporte Serenity." }

$index = Join-Path $raiz 'qa\serenity\target\site\serenity\index.html'
Write-Host "`n== Resumen ==" -ForegroundColor Cyan
Write-Host ("Backend:  " + $(if ($backend -eq 0) { 'OK' } else { "FALLÓ (código $backend)" }))
Write-Host ("Frontend: " + $(if ($frontend -eq 0) { 'OK' } else { "FALLÓ (código $frontend)" }))
Write-Host "Reporte Serenity: $index"
Write-Host "Otros reportes:   $rep"
if ($Abrir) { Start-Process $index }
if ($backend -ne 0 -or $frontend -ne 0) { exit 1 }
