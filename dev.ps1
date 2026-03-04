param(
  [string]$ProjectId = "demo-si-game"
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$firebaseConfigPath = Join-Path $scriptRoot "firebase.local.json"

function Stop-ProcessesOnPort {
  param([int]$Port)

  $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if (-not $listeners) {
    return
  }

  $processIds = $listeners | Select-Object -ExpandProperty OwningProcess -Unique
  foreach ($processId in $processIds) {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
    if ($null -eq $proc) {
      continue
    }
    $name = [string]$proc.Name
    Write-Host "Stopping process on port ${Port}: $name (PID $processId)..."
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
  }
}

Stop-ProcessesOnPort -Port 8080
Stop-ProcessesOnPort -Port 9099
Stop-ProcessesOnPort -Port 5001

if (-not (Test-Path (Join-Path $scriptRoot "functions\\node_modules\\firebase-functions"))) {
  Write-Host "Installing functions dependencies..."
  npm --prefix (Join-Path $scriptRoot "functions") install
}

if (-not (Test-Path (Join-Path $scriptRoot "frontend\\node_modules"))) {
  Write-Host "Installing frontend dependencies..."
  npm --prefix (Join-Path $scriptRoot "frontend") install
}

Write-Host "Starting Firebase emulators + frontend (project: $ProjectId)..."
Push-Location $scriptRoot
try {
  firebase --config $firebaseConfigPath emulators:exec --project $ProjectId 'npm --prefix frontend run dev'
} finally {
  Pop-Location
}
