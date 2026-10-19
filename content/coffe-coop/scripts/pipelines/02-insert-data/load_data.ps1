<#
.SYNOPSIS
    Coffee Coop - Carga los INSERT de data/sql en coffee_coop_db usando psql (no necesita Python).

.DESCRIPTION
    Ejecuta en orden todos los archivos .sql generados por 01-generate-data:
        01-INSERT-DEPARTMENTS.sql ... 15-INSERT-PAYMENTS-part-003.sql, 99-RESET-SEQUENCES.sql
    Cada archivo trae su propio BEGIN/COMMIT: si uno falla, ese archivo se revierte,
    el script se detiene y dice desde cual retomar (-StartFrom).

.EXAMPLE
    .\load_data.ps1
    .\load_data.ps1 -StartFrom 12-INSERT-DELIVERIES-part-002
    .\load_data.ps1 -Only FARMERS
    .\load_data.ps1 -DryRun
#>
param(
    [string]$DbHost    = "localhost",
    [int]   $Port      = 5433,
    [string]$User      = "cc_admin",
    [string]$Database  = "coffee_coop_db",
    [string]$SqlDir    = "",
    [string]$StartFrom = "",
    [string]$Only      = "",
    [string]$PsqlPath  = "",
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$Schemas = @("geo", "farm", "buy", "pay")
$Tables  = @("geo.departments", "geo.municipalities", "farm.coffee_varieties", "farm.certifications",
             "buy.collection_points", "buy.daily_prices", "farm.farmers", "farm.farms", "farm.plots",
             "farm.plot_varieties", "farm.farm_certifications", "buy.deliveries", "buy.quality_analyses",
             "pay.settlements", "pay.payments")

function Write-Info($msg)  { Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg) }
function Write-Ok($msg)    { Write-Host ("[{0}] [OK] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg) -ForegroundColor Green }
function Write-Fail($msg)  { Write-Host ("[{0}] [ERROR] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg) -ForegroundColor Red }

# ##################################################
# #   1. psql y carpeta de archivos                #
# ##################################################

if (-not $PsqlPath) {
    $cmd = Get-Command psql -ErrorAction SilentlyContinue
    if ($cmd) {
        $PsqlPath = $cmd.Source
    } else {
        $found = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\psql.exe" -ErrorAction SilentlyContinue |
                 Sort-Object { [int]($_.FullName -replace '.*PostgreSQL\\(\d+).*', '$1') } -Descending |
                 Select-Object -First 1
        if ($found) { $PsqlPath = $found.FullName }
    }
}
if (-not $PsqlPath -or -not (Test-Path $PsqlPath)) {
    Write-Fail "No se encontro psql. Usa -PsqlPath 'C:\Program Files\PostgreSQL\18\bin\psql.exe'"
    exit 1
}

if (-not $SqlDir) { $SqlDir = Join-Path $PSScriptRoot "../../../data/sql" }
if (-not (Test-Path $SqlDir)) {
    Write-Fail "No existe la carpeta $SqlDir. Genera primero los datos con 01-generate-data."
    exit 1
}
$SqlDir = (Resolve-Path $SqlDir).Path

$files = @(Get-ChildItem -Path $SqlDir -Filter "*.sql" | Sort-Object Name)
if ($StartFrom) { $files = @($files | Where-Object { [string]::CompareOrdinal($_.Name, $StartFrom) -ge 0 }) }
if ($Only)      { $files = @($files | Where-Object { $_.Name -like "*$Only*" }) }
if ($files.Count -eq 0) {
    Write-Fail "No hay archivos .sql para ejecutar en $SqlDir"
    exit 1
}

Write-Info "psql:     $PsqlPath"
Write-Info "Carpeta:  $SqlDir"
Write-Info "Destino:  $User@${DbHost}:$Port/$Database"
Write-Info "$($files.Count) archivos para ejecutar"

if ($DryRun) {
    $files | ForEach-Object { Write-Host "   $($_.Name)" }
    exit 0
}

# ##################################################
# #   2. Contrasena y conexion                     #
# ##################################################

$passwordWasSet = [bool]$env:PGPASSWORD
if (-not $passwordWasSet) {
    $secure = Read-Host "Contrasena de $User" -AsSecureString
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
$env:PGCLIENTENCODING = "UTF8"     # los datos tienen tildes y enes

function Invoke-Scalar([string]$sql) {
    $out = & $PsqlPath -h $DbHost -p $Port -U $User -d $Database -tAq -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) { throw "psql fallo ejecutando: $sql" }
    return $out
}

try {
    try {
        $schemaList = ($Schemas | ForEach-Object { "'$_'" }) -join ","
        $n = [int](Invoke-Scalar "SELECT COUNT(*) FROM pg_namespace WHERE nspname IN ($schemaList)")
    } catch {
        Write-Fail "No fue posible conectarse a $Database en ${DbHost}:$Port. Revisa usuario, contrasena, puerto y que el servicio este corriendo."
        exit 1
    }
    if ($n -ne $Schemas.Count) {
        Write-Fail "Faltan esquemas (encontrados $n de $($Schemas.Count)). Ejecuta primero scripts/ddl/02-create-tables.sql y 03-alter-tables.sql."
        exit 1
    }
    Write-Ok "Conectado. Esquemas encontrados: $($Schemas -join ', ')"

    $fullLoad = (-not $StartFrom) -and (-not $Only)
    if ($fullLoad -and -not $Force) {
        $hasData = Invoke-Scalar "SELECT EXISTS (SELECT 1 FROM farm.farmers) OR EXISTS (SELECT 1 FROM geo.departments)"
        if ($hasData -eq "t") {
            Write-Fail "Las tablas ya tienen datos. Recrea la base, usa -StartFrom para retomar o -Force para cargar igual."
            exit 1
        }
    }

    # ##################################################
    # #   3. Carga                                     #
    # ##################################################

    $t0 = Get-Date
    $i = 0
    foreach ($f in $files) {
        $i++
        $pct = [int](($i - 1) * 100 / $files.Count)
        Write-Progress -Activity "Cargando $Database" -Status "$i/$($files.Count)  $($f.Name)" -PercentComplete $pct
        $t = Get-Date
        & $PsqlPath -h $DbHost -p $Port -U $User -d $Database -q -v ON_ERROR_STOP=1 -f $f.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Progress -Activity "Cargando $Database" -Completed
            Write-Fail "Fallo $($f.Name). Ese archivo se revirtio; los anteriores quedaron guardados."
            Write-Host "        Corrige el problema y retoma con:  .\load_data.ps1 -StartFrom $($f.BaseName)" -ForegroundColor Yellow
            exit 1
        }
        $mb = $f.Length / 1MB
        Write-Ok ("{0,-42} {1,6:N1} MB {2,7:N1} s" -f $f.Name, $mb, ((Get-Date) - $t).TotalSeconds)
    }
    Write-Progress -Activity "Cargando $Database" -Completed
    Write-Info ("Carga terminada en {0:N1} minutos" -f ((Get-Date) - $t0).TotalMinutes)

    # ##################################################
    # #   4. Conteo por tabla                          #
    # ##################################################

    $k = 0
    $sql = ($Tables | ForEach-Object { $k++; "SELECT $k AS n, '$_' AS t, COUNT(*) AS c FROM $_" }) -join " UNION ALL "
    $sql = "SELECT t, c FROM ($sql) x ORDER BY n"
    $rows = Invoke-Scalar $sql
    $total = 0
    Write-Info "Registros por tabla:"
    foreach ($r in $rows) {
        $parts = $r -split '\|'
        $total += [long]$parts[1]
        Write-Host ("   {0,-28} {1,12:N0}" -f $parts[0], [long]$parts[1])
    }
    Write-Host ("   {0,-28} {1,12:N0}" -f "TOTAL", $total) -ForegroundColor Cyan
}
finally {
    if (-not $passwordWasSet) { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }
}
