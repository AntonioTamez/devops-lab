#Requires -Version 7
<#
.SYNOPSIS
    Elimina todos los grupos de recursos marcados como laboratorio.
.DESCRIPTION
    Busca grupos de recursos con el tag indicado y los elimina.
    Por seguridad pide confirmación explícita salvo que se use -Force,
    y nunca actúa si el filtro de tag está vacío.
.EXAMPLE
    .\teardown.ps1 -WhatIf      # muestra qué borraría, sin borrar nada
    .\teardown.ps1              # pide confirmación
    .\teardown.ps1 -Force       # sin preguntar (para tarea programada)
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateNotNullOrEmpty()]
    [string]$TagName = 'lab',

    [ValidateNotNullOrEmpty()]
    [string]$TagValue = 'true',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# --- Contexto: siempre saber en qué suscripción estás antes de destruir ---
$cuenta = az account show -o json | ConvertFrom-Json
if (-not $cuenta) { throw "No hay sesión de Azure activa. Ejecuta 'az login'." }

Write-Host "Suscripción : $($cuenta.name)" -ForegroundColor Cyan
Write-Host "ID          : $($cuenta.id)"   -ForegroundColor Cyan
Write-Host "Filtro      : $TagName=$TagValue" -ForegroundColor Cyan
Write-Host ""

# --- Descubrimiento ---
$grupos = az group list --tag "$TagName=$TagValue" --query "[].name" -o tsv

if ([string]::IsNullOrWhiteSpace($grupos)) {
    Write-Host "Nada que borrar. El entorno ya está limpio." -ForegroundColor Green
    exit 0
}

$lista = @($grupos -split "`n" | Where-Object { $_ -ne '' })

Write-Host "Se eliminarán $($lista.Count) grupo(s) de recursos:" -ForegroundColor Yellow
foreach ($g in $lista) {
    # Ojo: --query "length(@)" se rompe en Windows porque cmd.exe interpreta
    # los parentesis al pasar por az.cmd. Contamos en PowerShell.
    $n = @(az resource list --resource-group $g --query "[].id" -o tsv | Where-Object { $_ }).Count
    Write-Host "  - $g  ($n recursos)"
}
Write-Host ""

# --- Confirmación ---
if (-not $Force -and -not $WhatIfPreference) {
    $r = Read-Host "Escribe BORRAR para confirmar"
    if ($r -ne 'BORRAR') {
        Write-Host "Cancelado. No se ha borrado nada." -ForegroundColor Green
        exit 0
    }
}

# --- Ejecución ---
foreach ($g in $lista) {
    if ($PSCmdlet.ShouldProcess($g, "Eliminar grupo de recursos")) {
        az group delete --name $g --yes --no-wait
        Write-Host "Borrado iniciado: $g" -ForegroundColor Magenta
    }
}

Write-Host ""
if ($WhatIfPreference) {
    Write-Host "Simulacion (-WhatIf): no se ha borrado nada." -ForegroundColor Green
} else {
    Write-Host "Borrados lanzados en segundo plano. Verifica con: az group list -o table" -ForegroundColor Green
}