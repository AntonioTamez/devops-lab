# Módulo 0 — Base de operaciones y control de coste

**Duración**: 4 h (2 sesiones de 2 h) · **Prerrequisitos**: ninguno · **Coste esperado**: 0,00 USD

> **Objetivo**: dejar montado el entorno, la suscripción y los guardarraíles de gasto **antes** de crear tu primer recurso real.

---

## Por qué este módulo va primero

Casi todo el mundo que aprende cloud por su cuenta hace lo contrario: abre la cuenta, crea una VM en el minuto 3, y descubre el problema tres semanas después en el extracto de la tarjeta. El coste no es el único motivo. Un entorno sin disciplina de limpieza acumula recursos huérfanos que te contaminan los labs siguientes: reglas de red que ya no recuerdas, una IP que no sabes de dónde salió, un `az group list` con 14 grupos y ninguna idea de cuáles importan.

Los guardarraíles de este módulo son además **exactamente lo que un DevOps hace el primer día en una suscripción nueva de empresa**. No es preparación para aprender: es el trabajo.

## Qué NO hacer en este módulo

- **No crees ninguna VM, App Service, base de datos ni nada facturable.** Solo grupos de recursos vacíos (gratis) y un budget (gratis).
- **No instales Docker Desktop todavía** — va en M5, y en Windows consume recursos y licencia comercial según el tamaño de tu empresa.
- **No intentes entender la sintaxis de Bicep** del Lab 0.4. Vas a copiar 25 líneas y desplegarlas. La comprensión llega en M8.
- **No configures Terraform, kubectl, Helm ni nada de "el kit DevOps"**. Cada herramienta entra cuando hay un problema que resuelve.

---

# Sesión 1 (2 h) — Entorno local y primer contacto

## Lab 0.1 — Herramientas base (40 min)

### Instalación

Abre **PowerShell como administrador** y ejecuta:

```powershell
winget install --id Microsoft.PowerShell        --source winget   # PowerShell 7 (distinto del 5.1 que trae Windows)
winget install --id Git.Git                     --source winget
winget install --id GitHub.cli                  --source winget
winget install --id Microsoft.AzureCLI          --source winget
winget install --id Microsoft.VisualStudioCode  --source winget   # omite si ya lo tienes
```

**Cierra y abre una terminal nueva** (el `PATH` no se refresca en la sesión actual). A partir de ahora usa **PowerShell 7** (`pwsh`), no el `powershell.exe` 5.1 que abre Windows por defecto. Configura Windows Terminal para que PowerShell 7 sea el perfil predeterminado.

> **Por qué PowerShell 7 y no 5.1**: 5.1 no tiene los operadores `&&` / `||`, ni operador ternario, ni `??`. Vas a escribir scripts que se ejecutan también en agentes de CI Linux, y `pwsh` es el mismo binario en ambos. Aprender 5.1 es aprender un dialecto que no se lleva a ningún sitio.

### WSL2 — Ubuntu

Lo instalas ahora aunque no lo uses hasta M2, porque requiere reinicio y no quieres perder 20 minutos de la sesión de M2 en esto.

```powershell
wsl --install -d Ubuntu-24.04
```

Reinicia. Al arrancar Ubuntu por primera vez te pedirá usuario y contraseña (no tienen que coincidir con los de Windows; **apúntala**, la vas a necesitar para `sudo`).

Verifica que quedó en versión 2:

```powershell
wsl --list --verbose    # la columna VERSION debe decir 2
```

### Extensiones de VS Code

```powershell
code --install-extension ms-vscode-remote.remote-wsl
code --install-extension ms-azuretools.vscode-bicep
code --install-extension ms-vscode.azurecli
code --install-extension GitHub.vscode-pull-request-github
code --install-extension timonwong.shellcheck
```

### Verificación del lab

```powershell
pwsh --version      # 7.x
git --version       # 2.4x o superior
gh --version
az version          # azure-cli 2.6x o superior
wsl -l -v           # Ubuntu-24.04, VERSION 2
```

Las cinco tienen que responder. Si alguna falla, resuélvelo ahora: no avances con una herramienta a medias.

---

## Lab 0.2 — Cuenta de Azure y primer contacto con `az` (35 min)

### Crear la cuenta

1. Ve a `azure.microsoft.com/free`. Necesitas una tarjeta (verificación de identidad; no se cobra si te quedas en capa gratuita) y un número de móvil.
2. **Usa una cuenta de correo personal**, no la de tu empresa. Si usas la corporativa acabarás en el tenant de tu empresa, sin permisos de Owner y sin poder crear service principals — y ahí se acaba el 60 % de esta ruta.
3. Al terminar tendrás una suscripción **Free Trial** con crédito de 200 USD válido **30 días**, y después servicios gratuitos durante 12 meses.

> **Trampa mental del crédito**: esos 200 USD caducan a los 30 días. No los uses como colchón. Cuando expiren, la suscripción pasa a Pay-As-You-Go y todo lo que dejes encendido va contra tu tarjeta. Los guardarraíles de la sesión 2 asumen que ese crédito **no existe**.

### Login y orientación

```powershell
az login
```

Se abre el navegador. Después:

```powershell
# ¿Quién soy y dónde estoy?
az account show

# Guarda el ID de suscripción, lo vas a usar constantemente
$subId = az account show --query id -o tsv
$subId

# Si tuvieras varias suscripciones
az account list -o table
az account set --subscription $subId
```

Configura la CLI para que sea usable:

```powershell
az config set core.output=table          # tablas legibles por defecto en vez de JSON
az config set core.collect_telemetry=no
az config set core.only_show_errors=true # silencia los WARNING de preview
az extension add --name resource-graph   # lo usarás en el Lab 0.6
```

### Primer contacto: crea y destruye un grupo de recursos

Un **grupo de recursos** (RG) es un contenedor lógico. No cuesta nada, no tiene capacidad, y es la unidad de borrado: cuando eliminas un RG, se van **todos** los recursos que contiene. Esa es la propiedad de la que depende todo tu control de coste.

```powershell
az group create --name rg-prueba --location westeurope --tags lab=true owner=antonio
az group list -o table
az group delete --name rg-prueba --yes --no-wait
```

`--no-wait` devuelve el control inmediatamente; el borrado sigue en segundo plano.

### Entiende `--query` desde ya

`az` devuelve JSON y filtra con **JMESPath** vía `--query`. Es la diferencia entre navegar el portal a mano y automatizar. Practica estas cuatro:

```powershell
# Un solo valor, sin comillas ni formato (ideal para asignar a variables)
az account show --query id -o tsv

# Seleccionar campos y renombrarlos
az group list --query "[].{Nombre:name, Region:location, Tags:tags}" -o table

# Filtrar
az group list --query "[?location=='westeurope'].name" -o tsv

# Filtrar por tag anidado
az group list --query "[?tags.lab=='true'].name" -o tsv
```

> **Gotcha de PowerShell**: en PowerShell, envuelve la expresión de `--query` en **comillas dobles** y usa comillas simples dentro (`"[?tags.lab=='true']"`). Al revés falla, porque PowerShell no interpola dentro de comillas simples y `az` recibe la cadena literal mal formada. Este error te va a morder al menos una vez; recuérdalo cuando pase.

### Verificación del lab

`az group list -o table` devuelve vacío y `az account show` muestra tu suscripción. Sabes explicar qué es un grupo de recursos y por qué borrarlo borra todo lo de dentro.

---

## Lab 0.3 — Repo `devops-lab` y bitácora (45 min)

Este repo es tu portafolio en construcción. Va a ser público desde el minuto uno: eso te obliga a escribir READMEs que se entiendan, y en el mes 9 tendrás nueve meses de historial de commits visible — que es una señal que ningún CV transmite.

### Crear el repo

```powershell
gh auth login          # elige GitHub.com → HTTPS → autenticar por navegador

mkdir C:\git\devops-lab
cd C:\git\devops-lab
git init -b main
```

Configura Git en condiciones (una sola vez, global):

```powershell
git config --global user.name  "Tu Nombre"
git config --global user.email "tu@email.com"
git config --global init.defaultBranch main
git config --global pull.rebase true          # historial lineal; lo justificamos en M1
git config --global core.autocrlf true        # Windows: LF en el repo, CRLF en disco
git config --global core.longpaths true       # evita el límite de 260 caracteres de Windows
```

### Estructura

```
devops-lab/
├── README.md
├── .gitignore
├── modulos/
│   └── 00-base-operaciones/
│       └── README.md          <- tu bitácora de este módulo
├── scripts/
│   └── teardown.ps1           <- Lab 0.6
└── infra/
    └── budget.bicep           <- Lab 0.4
```

```powershell
mkdir modulos\00-base-operaciones, scripts, infra
```

### `.gitignore`

```powershell
gh repo create devops-lab --public --source . --remote origin --description "Ruta de aprendizaje DevOps en Azure: labs, IaC y bitacora"
```

Crea `.gitignore` con esto (crítico: aquí es donde la gente filtra credenciales por primera vez):

```gitignore
# Secretos y credenciales — NUNCA
*.pem
*.key
*.pfx
*.publishsettings
.env
.env.*
appsettings.*.local.json
azureauth.json
sp-credentials.json

# Terraform (M9)
*.tfstate
*.tfstate.*
.terraform/
*.tfvars

# Bicep/ARM
*.parameters.local.json

# .NET
bin/
obj/

# Sistema
.DS_Store
Thumbs.db
```

### Plantilla de bitácora

Guarda esto como `modulos/PLANTILLA.md` y cópialo en cada módulo nuevo:

```markdown
# Módulo NN — Nombre

**Fechas**: dd/mm – dd/mm · **Horas invertidas**: N h · **Coste incurrido**: N,NN USD

## Qué construí
Dos o tres frases. Qué existe ahora que antes no existía.

## Decisiones y por qué
| Decisión | Alternativa descartada | Motivo |
|---|---|---|

## Lo que se me rompió
Qué falló, cuánto tardé en diagnosticarlo, cómo lo encontré.
Esta sección es la más valiosa del documento: es de donde salen tus respuestas de entrevista.

## Cinco líneas por herramienta nueva
- **Herramienta**: qué problema resuelve / qué se hacía antes / qué cuesta adoptarla / cuándo NO usarla.

## Criterio de listo — evidencia
- [ ] Criterio 1 → captura, comando o enlace que lo demuestra

## Qué dejé pendiente
```

> **La sección "Lo que se me rompió" no es opcional.** En una entrevista de DevOps mid, la pregunta que decide es alguna variante de *"cuéntame algo que se te rompiera y cómo lo resolviste"*. Si no lo escribes en el momento, en el mes 9 no lo recordarás. Cinco minutos cada miércoles.

### Primer commit

```powershell
git add .
git commit -m "chore: estructura inicial del laboratorio"
git push -u origin main
```

### Verificación del lab

El repo es visible en `github.com/<tu-usuario>/devops-lab`, tiene `.gitignore` con las reglas de secretos, y tu bitácora del módulo 0 existe (aunque esté a medias).

---

# Sesión 2 (2 h) — Guardarraíles

## Lab 0.4 — El budget, como código (45 min)

### Primero: entiende qué hace y qué NO hace un budget

Un budget de Azure **no corta el gasto**. No hay ningún botón en Azure que diga "para de facturarme a los 10 USD". Un budget es un **detector de humo**: te manda un correo cuando cruzas un umbral. Si lo confundes con un límite duro, la primera factura sorpresa llegará igualmente.

Por eso el control real de coste son **tres** cosas juntas, y el budget es solo una:

| Capa | Qué hace | Este lab |
|---|---|---|
| Budget + alertas | Te avisa cuando ya estás gastando | 0.4 |
| Policy de denegación | Impide que existan los recursos caros | 0.5 |
| Teardown disciplinado | Elimina lo que sí creaste | 0.6 |

### El archivo

Crea `infra/budget.bicep`:

```bicep
targetScope = 'subscription'

@description('Correo al que llegan las alertas de presupuesto.')
param contactEmail string

@description('Importe mensual en la moneda de facturación de la suscripción.')
param amount int = 10

@description('Primer día del mes en curso, formato YYYY-MM-DD.')
param startDate string

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: 'budget-lab-mensual'
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    notifications: {
      Real_50: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: [ contactEmail ]
      }
      Real_80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [ contactEmail ]
      }
      Real_100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: [ contactEmail ]
      }
      Previsto_100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [ contactEmail ]
      }
    }
  }
}
```

### Desplegar

```powershell
az bicep install          # la primera vez; después az lo actualiza solo

$inicioMes = (Get-Date -Day 1).ToString('yyyy-MM-dd')

az deployment sub create `
  --name budget-inicial `
  --location westeurope `
  --template-file infra/budget.bicep `
  --parameters contactEmail='tu@email.com' amount=10 startDate=$inicioMes
```

> `--location` en un despliegue a nivel de suscripción **no** indica dónde vivirá el recurso (un budget no tiene región); indica dónde se almacenan los metadatos del despliegue. Es un detalle que confunde a todo el mundo la primera vez.

### La alerta que de verdad importa

De las cuatro notificaciones, la que te salvará es **`Previsto_100`** (`thresholdType: 'Forecasted'`). Azure proyecta tu gasto al final del mes según el ritmo actual. Si el día 3 dejas encendido algo que cuesta 5 USD/día, la alerta de gasto *real* no salta hasta el día 6 —cuando ya llevas 30 USD—, pero la de *previsión* salta el mismo día 3. En un presupuesto de 10 USD/mes, esa diferencia lo es todo.

### Verificación del lab

```powershell
az consumption budget list -o table
```

Debe aparecer `budget-lab-mensual`. Confírmalo también en el portal: **Cost Management → Budgets**, y comprueba que los cuatro umbrales están activos con tu correo.

> **No puedes forzar el disparo de la alerta sin gastar de verdad.** El criterio de listo del módulo respecto al budget es que exista, con las cuatro notificaciones y el correo correcto — no que hayas recibido el mail. Lo recibirás de forma natural en M5 o M12.

Commit:

```powershell
git add infra/budget.bicep
git commit -m "feat: budget mensual de 10 USD con alertas reales y previstas"
```

Acabas de hacer tu primer despliegue de infraestructura como código. No necesitas entender la sintaxis todavía; sí necesitas notar la propiedad importante: **ese archivo es la definición completa del budget**. Si mañana borras el budget, lo recreas idéntico con un comando. Ese es todo el argumento de IaC, y lo desarrollaremos en M8.

---

## Lab 0.5 — Convención de tags y freno de emergencia (35 min)

### La convención

Sin convención de tags, tu script de limpieza no sabe qué borrar y tu Cost Analysis no sabe qué agrupar. Adopta esta y respétala **en todos** los grupos de recursos a partir de ahora:

| Tag | Valores | Para qué |
|---|---|---|
| `lab` | `true` \| `false` | Marca lo que el teardown puede destruir sin preguntar. **`false` = protegido** |
| `owner` | tu nombre | Costumbre profesional; en una empresa identifica al responsable del gasto |
| `modulo` | `00`…`14` | Te permite saber de qué lab salió cada recurso tres meses después |
| `expira` | `YYYY-MM-DD` | Fecha tras la cual el recurso debe morir. Tu red de seguridad |

Regla de oro para el resto de la ruta: **si creas un grupo de recursos sin `lab=true`, lo estás haciendo mal.** Nada de lo que construyas en los módulos 1 al 13 es permanente.

```powershell
az group create --name rg-m00-demo --location westeurope `
  --tags lab=true owner=antonio modulo=00 expira=2026-12-31
```

### El freno de emergencia

En la ruta te advertí de dos recursos capaces de destrozar tu presupuesto: **Azure Firewall (~700 USD/mes)** y **Application Gateway (~180 USD/mes)**. No los vas a necesitar en toda la Fase 1. La forma correcta de garantizar que no aparecen por accidente —o por copiar un tutorial sin leerlo— no es la fuerza de voluntad: es una política que los **deniegue**.

Crea `infra/policy-deny-caros.json`:

```json
{
  "mode": "All",
  "policyRule": {
    "if": {
      "field": "type",
      "in": [
        "Microsoft.Network/azureFirewalls",
        "Microsoft.Network/applicationGateways",
        "Microsoft.Network/bastionHosts",
        "Microsoft.Network/expressRouteCircuits",
        "Microsoft.Network/virtualNetworkGateways",
        "Microsoft.Network/vpnGateways",
        "Microsoft.Sql/managedInstances",
        "Microsoft.DBforPostgreSQL/servers"
      ]
    },
    "then": { "effect": "deny" }
  }
}
```

Créala y asígnala a tu suscripción:

```powershell
$subId = az account show --query id -o tsv

az policy definition create `
  --name "deny-recursos-caros" `
  --display-name "Denegar recursos de coste elevado en laboratorio" `
  --description "Impide crear recursos que superan el presupuesto de aprendizaje" `
  --rules "@infra/policy-deny-caros.json" `
  --mode All

az policy assignment create `
  --name "deny-caros-sub" `
  --display-name "Freno de coste - suscripcion de laboratorio" `
  --policy "deny-recursos-caros" `
  --scope "/subscriptions/$subId"
```

> **La asignación tarda entre 5 y 30 minutos en hacer efecto.** Si pruebas inmediatamente y el recurso se crea, la policy no ha fallado: aún no se ha propagado. Es un comportamiento normal de Azure Policy que confunde a mucha gente.

Pruébalo más tarde (o al empezar M1) intentando crear un Application Gateway; debe fallar con `RequestDisallowedByPolicy`. Cuando llegues a **M3** y quieras estudiar balanceo L7 de verdad, quitas la asignación durante esa sesión y la vuelves a poner. Ese gesto consciente es justamente el punto.

En **M4** ampliarás esto con policies de tags obligatorios, roles personalizados y ámbitos de management group. Aquí solo pones el freno.

```powershell
git add infra/policy-deny-caros.json
git commit -m "feat: policy que deniega recursos fuera del presupuesto de laboratorio"
```

---

## Lab 0.6 — `teardown.ps1` y prueba de fuego (40 min)

Este script es el hábito central del módulo. Se ejecuta **al final de cada sesión de estudio**, no cuando te acuerdes.

Crea `scripts/teardown.ps1`:

```powershell
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
    $n = az resource list --resource-group $g --query "length(@)" -o tsv
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
Write-Host "Borrados lanzados en segundo plano. Verifica con: az group list -o table" -ForegroundColor Green
```

### Por qué el script está escrito así

Estas cuatro decisiones son las que separan un script de laboratorio de uno que podrías dejar corriendo en una empresa:

1. **Imprime la suscripción antes de destruir.** El accidente clásico de un DevOps es ejecutar un script de limpieza contra el contexto equivocado. Ver el nombre en pantalla cuesta cero y evita una catástrofe.
2. **Se rinde si el filtro está vacío.** Si `az group list --tag` no devuelve nada, sale con éxito. Un script que interpreta "sin resultados" como "borra todo" es exactamente cómo se destruyen entornos de producción.
3. **`SupportsShouldProcess`** te da `-WhatIf` gratis. Ejecutar en seco antes de destruir debe ser reflejo, no excepción.
4. **Confirmación escrita, no `[S/N]`.** Teclear `BORRAR` requiere un acto consciente; pulsar `S` es muscular.

### Prueba de fuego (el criterio de listo del módulo)

```powershell
# 1. Crear tres grupos: dos de laboratorio y uno "protegido"
az group create -n rg-test-a -l westeurope --tags lab=true  owner=antonio modulo=00
az group create -n rg-test-b -l westeurope --tags lab=true  owner=antonio modulo=00
az group create -n rg-importante -l westeurope --tags lab=false owner=antonio

# 2. Ensayo en seco: debe listar SOLO rg-test-a y rg-test-b
.\scripts\teardown.ps1 -WhatIf

# 3. Ejecución real, cronometrada
Measure-Command { .\scripts\teardown.ps1 -Force }

# 4. Verificar: rg-importante sigue vivo, los otros dos no
az group list -o table
```

**Apruebas el módulo si**: el ensayo en seco no menciona `rg-importante`, la ejecución real lo deja intacto, y el ciclo completo tarda menos de 2 minutos.

Limpia el grupo protegido a mano al terminar la prueba:

```powershell
az group delete -n rg-importante --yes --no-wait
```

### Automatiza el recordatorio

```powershell
$accion  = New-ScheduledTaskAction -Execute 'pwsh.exe' `
           -Argument '-NoProfile -File "C:\git\devops-lab\scripts\teardown.ps1" -WhatIf'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At 19:00
Register-ScheduledTask -TaskName "DevOps Lab - revision semanal" `
  -Action $accion -Trigger $trigger -Description "Muestra que quedaria por limpiar"
```

Fíjate en que la tarea programada usa **`-WhatIf`**: te *informa*, no destruye por su cuenta. Automatizar un borrado desatendido sin supervisión es cómo se pierde trabajo. El borrado real lo lanzas tú.

```powershell
git add scripts/teardown.ps1
git commit -m "feat: script de teardown con ensayo en seco y confirmacion explicita"
git push
```

---

# Cierre del módulo

## Checklist de "listo"

| # | Criterio | Cómo lo demuestras |
|---|---|---|
| 1 | Entorno funcional | `pwsh`, `git`, `gh`, `az` y `wsl -l -v` responden correctamente |
| 2 | Suscripción operativa | `az account show` devuelve tu suscripción; `az config` con salida en tabla |
| 3 | Budget vivo | `az consumption budget list` muestra `budget-lab-mensual` con 4 notificaciones y tu correo |
| 4 | Freno activo | La policy `deny-recursos-caros` está asignada a la suscripción |
| 5 | Teardown fiable | Borra los RG con `lab=true` en <2 min y **no toca** los que tienen `lab=false` |
| 6 | Repo público | `devops-lab` en GitHub con `.gitignore`, `infra/`, `scripts/` y la bitácora del módulo 0 |
| 7 | Entorno limpio | `az group list -o table` devuelve vacío |

## Preguntas de autoevaluación

Respóndelas por escrito en tu bitácora. Si alguna te cuesta, el módulo no está cerrado:

1. ¿Por qué un budget de Azure no impide que gastes de más? ¿Qué sí lo impide?
2. Diferencia entre una alerta de umbral `Actual` y una `Forecasted`. ¿Cuál te avisa antes y por qué importa con 10 USD de presupuesto?
3. Tu script de teardown se ejecuta y no encuentra grupos con `lab=true`. ¿Qué debe hacer, y por qué es peligrosa la alternativa?
4. ¿Qué pasa exactamente a los 30 días con el crédito de la cuenta gratuita?
5. Has borrado un grupo de recursos con una VM dentro. ¿Se borra también el disco? ¿Y la IP pública? *(Pista: depende de cómo se creó. Lo confirmarás en M2 — anota tu hipótesis ahora y compárala luego.)*

## Errores típicos de este módulo

| Error | Consecuencia | Prevención |
|---|---|---|
| Registrarse con la cuenta corporativa | Sin permisos de Owner, no puedes crear service principals ni policies → la ruta se rompe en M4 | Correo personal, tenant propio |
| Confiar en el budget como límite de gasto | Factura sorpresa | Las tres capas del Lab 0.4 |
| Crear grupos de recursos sin tags | El teardown no los ve y quedan acumulándose | Convención del Lab 0.5, sin excepciones |
| Apagar una VM desde dentro del sistema operativo | Sigue facturando cómputo | `az vm deallocate` (lo verás en M2) |
| Instalar "todo el kit DevOps" el primer día | Ruido y herramientas que no sabes por qué tienes | Cada herramienta entra con su problema |
| Dejar la bitácora "para luego" | En el mes 9 no recordarás nada que contar en una entrevista | 15 min cada miércoles, es parte del 30 % |

## Recursos

Consulta solo si te atascas — este módulo se aprende ejecutando, no leyendo. Total recomendado: **menos de 40 minutos**.

| Recurso | Idioma | Para qué |
|---|---|---|
| [Cost Management — crear un presupuesto](https://learn.microsoft.com/es-es/azure/cost-management-billing/costs/tutorial-acm-create-budgets) | ES | Fondo conceptual del Lab 0.4 |
| [Referencia de `az` CLI](https://learn.microsoft.com/es-es/cli/azure/reference-index) | ES | Consulta puntual de comandos |
| [Consultar con `--query` (JMESPath)](https://learn.microsoft.com/es-es/cli/azure/query-azure-cli) | ES | Los 20 minutos con mejor retorno de toda la CLI |
| [Convenciones de nomenclatura y tags (CAF)](https://learn.microsoft.com/es-es/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) | ES | Estándar real de empresa, útil desde ya |
| [Instalar WSL](https://learn.microsoft.com/es-es/windows/wsl/install) | ES | Si el Lab 0.1 falla |
| [Estructura de Azure Policy](https://learn.microsoft.com/es-es/azure/governance/policy/concepts/definition-structure) | ES | Fondo del Lab 0.5; se profundiza en M4 |
| [Precios de Azure](https://azure.microsoft.com/es-es/pricing/calculator/) | ES | Consúltala **antes** de crear cualquier recurso nuevo, siempre |

## Bitácora — qué escribir antes de cerrar

Rellena `modulos/00-base-operaciones/README.md` con la plantilla. Los dos apartados que no puedes saltarte:

- **Decisiones**: por qué correo personal y no corporativo; por qué el budget como código y no por el portal; por qué el teardown confirma con texto escrito.
- **Lo que se me rompió**: seguro que algo falló (el `PATH` tras `winget`, las comillas del `--query`, la propagación de la policy). Escríbelo con cuánto tardaste en diagnosticarlo. Empieza el hábito con algo trivial y en el mes 9 lo tendrás automatizado para algo serio.

## Antes de empezar M1

Elige ahora el **repositorio real de tu trabajo** sobre el que harás el entregable de M1 (migración a trunk-based con branch protection y CODEOWNERS). Criterios: que tenga al menos dos personas commiteando, que no sea crítico para una entrega inminente, y que puedas proponer cambios de proceso sin pedir permiso a tres niveles. Aprovechar tu acceso en el trabajo es la palanca principal de esta ruta — y M1 es donde empieza a rendir.
