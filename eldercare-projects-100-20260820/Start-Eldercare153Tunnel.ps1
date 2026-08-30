$ErrorActionPreference = 'Stop'

$taskRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$identityFile = Join-Path $taskRoot 'tools\eldercare_deploy_rsa'
$pidFile = Join-Path $taskRoot 'manifests\private\tunnel.pid'

if (-not (Test-Path -LiteralPath $identityFile)) {
  throw "SSH identity file is missing: $identityFile"
}

if (Test-Path -LiteralPath $pidFile) {
  $existingPid = [int](Get-Content -LiteralPath $pidFile -Raw)
  if (Get-Process -Id $existingPid -ErrorAction SilentlyContinue) {
    Write-Output "Tunnel is already running. PID=$existingPid"
    exit 0
  }
}

$sshArgs = @(
  '-N',
  '-i', $identityFile,
  '-o', 'IdentitiesOnly=yes',
  '-o', 'ExitOnForwardFailure=yes',
  '-o', 'ServerAliveInterval=30',
  '-o', 'ServerAliveCountMax=3',
  '-p', '12224'
)

for ($port = 18000; $port -le 18166; $port++) {
  $sshArgs += @('-L', "127.0.0.1:${port}:127.0.0.1:${port}")
}
$sshArgs += 'node2@192.168.100.10'

$process = Start-Process -FilePath 'ssh.exe' -ArgumentList $sshArgs -WindowStyle Hidden -PassThru
Set-Content -LiteralPath $pidFile -Value $process.Id -Encoding ascii
Start-Sleep -Seconds 2

if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
  throw 'SSH tunnel exited before becoming ready.'
}

$health = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:18000/health' -TimeoutSec 8
if ($health.StatusCode -ne 200) {
  throw "Portal health check failed: HTTP $($health.StatusCode)"
}

Write-Output "Tunnel ready. PID=$($process.Id) Portal=http://127.0.0.1:18000/"
