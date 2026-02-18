param(
  [string]$ChromeBinary = "C:\Program Files\Google\Chrome\Application\chrome.exe",
  [string]$ChromeDriverPort = "4444",
  [string]$FirebaseProject = "demo-si-game"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ChromeBinary)) {
  throw "Chrome binary not found: $ChromeBinary"
}

function Get-Jdk21Home() {
  if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
    return $env:JAVA_HOME
  }
  $adoptiumBase = "C:\Program Files\Eclipse Adoptium"
  if (Test-Path $adoptiumBase) {
    $candidate = Get-ChildItem -Path $adoptiumBase -Directory | Where-Object { $_.Name -like "jdk-21*" } | Sort-Object Name | Select-Object -Last 1
    if ($candidate) {
      return $candidate.FullName
    }
  }
  return $null
}

$jdkHome = Get-Jdk21Home
if ($null -eq $jdkHome) {
  throw "JDK 21 not found. Install Temurin 21."
}
$env:JAVA_HOME = $jdkHome
$env:PATH = "$jdkHome\bin;$env:PATH"

function Stop-ProcessOnPort([int]$port) {
  $lines = netstat -ano -p tcp | Select-String ":$port\s"
  foreach ($line in $lines) {
    $parts = ($line.ToString() -replace "\s+", " ").Trim().Split(" ")
    if ($parts.Length -lt 5) { continue }
    $state = $parts[3]
    $procId = [int]$parts[4]
    if ($state -ne "LISTENING") { continue }
    try {
      Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    } catch {
      # ignore
    }
  }
}

Stop-ProcessOnPort 9099
Stop-ProcessOnPort 8080
Stop-ProcessOnPort 5001
Stop-ProcessOnPort 4000
Stop-ProcessOnPort 4400
Stop-ProcessOnPort 4500
Start-Sleep -Seconds 1

$chromeVersion = (Get-Item $ChromeBinary).VersionInfo.ProductVersion
$parts = $chromeVersion.Split(".")
if ($parts.Length -lt 3) {
  throw "Unexpected Chrome version format: $chromeVersion"
}
$prefix = "$($parts[0]).$($parts[1]).$($parts[2])"

$knownGood = Invoke-RestMethod "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json"
$match = $knownGood.versions | Where-Object { $_.version -like "$prefix*" } | Select-Object -Last 1
if ($null -eq $match) {
  throw "No matching chromedriver found for Chrome version prefix: $prefix"
}

$driverVersion = $match.version
$download = $match.downloads.chromedriver | Where-Object { $_.platform -eq "win64" } | Select-Object -First 1
if ($null -eq $download) {
  throw "No win64 chromedriver download for version $driverVersion"
}

$cacheDir = Join-Path $PSScriptRoot "..\.tmp\chromedriver\$driverVersion"
$cacheDir = [System.IO.Path]::GetFullPath($cacheDir)
$driverExe = Join-Path $cacheDir "chromedriver-win64\chromedriver.exe"

if (-not (Test-Path $driverExe)) {
  New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
  $zipPath = Join-Path $cacheDir "chromedriver.zip"
  Write-Host "Downloading chromedriver $driverVersion ..."
  Invoke-WebRequest -Uri $download.url -OutFile $zipPath
  Expand-Archive -Path $zipPath -DestinationPath $cacheDir -Force
}

Write-Host "Starting ChromeDriver: $driverExe"
$driver = Start-Process -FilePath $driverExe -ArgumentList "--port=$ChromeDriverPort" -PassThru

Write-Host "Starting Firebase emulators (auth, firestore, functions) ..."
$firebaseOutLog = Join-Path $PSScriptRoot "..\.tmp\firebase-visual-e2e.out.log"
$firebaseErrLog = Join-Path $PSScriptRoot "..\.tmp\firebase-visual-e2e.err.log"
$firebase = Start-Process -FilePath "cmd.exe" -ArgumentList "/c firebase emulators:start --only auth,firestore,functions --project $FirebaseProject --config firebase.json" -PassThru -RedirectStandardOutput $firebaseOutLog -RedirectStandardError $firebaseErrLog

function Wait-Port([int]$port, [int]$timeoutSec = 60) {
  $start = Get-Date
  while (((Get-Date) - $start).TotalSeconds -lt $timeoutSec) {
    try {
      $client = New-Object System.Net.Sockets.TcpClient
      $async = $client.BeginConnect("127.0.0.1", $port, $null, $null)
      $ok = $async.AsyncWaitHandle.WaitOne(500)
      if ($ok -and $client.Connected) {
        $client.EndConnect($async)
        $client.Close()
        return
      }
      $client.Close()
    } catch {
      # wait
    }
    Start-Sleep -Milliseconds 500
  }
  throw "Timed out waiting for emulator port $port. Check logs: $firebaseOutLog / $firebaseErrLog"
}

Wait-Port -port 9099
Wait-Port -port 8080
Wait-Port -port 5001

try {
  flutter drive -d chrome `
    --driver=test_driver/integration_test.dart `
    --target=integration_test/full_visual_e2e_test.dart `
    --dart-define=USE_FIREBASE_EMULATORS=true `
    --dart-define=FIREBASE_EMULATOR_PROJECT_ID=$FirebaseProject `
    --dart-define=E2E_BYPASS_PROFILE_UPSERT=true
}
finally {
  if ($driver -and -not $driver.HasExited) {
    Stop-Process -Id $driver.Id -Force -ErrorAction SilentlyContinue
  }
  if ($firebase -and -not $firebase.HasExited) {
    Stop-Process -Id $firebase.Id -Force -ErrorAction SilentlyContinue
  }
}
