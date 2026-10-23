param([Parameter(ValueFromRemainingArguments=$true)][string[]]$GraphifyArguments)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskGraphify = Join-Path $taskRoot '.runtime\graphify-venv\Scripts\graphify.exe'
if (-not (Test-Path -LiteralPath $taskGraphify)) {
 throw 'Graphify local não instalado. Consulte docs/graphify.md para preparar o ambiente.'
}
$taskPreviousBackend = $env:GRAPHIFY_BACKEND
$taskPreviousLog = $env:GRAPHIFY_QUERY_LOG_DISABLE
$taskPreviousUtf8 = $env:PYTHONUTF8
$taskPreviousPath = $env:PATH
$taskCode = 0
Push-Location -LiteralPath $taskRoot
try {
 $env:GRAPHIFY_BACKEND = 'none'
 $env:GRAPHIFY_QUERY_LOG_DISABLE = '1'
 $env:PYTHONUTF8 = '1'
 $env:PATH = (Split-Path -Parent $taskGraphify) + [IO.Path]::PathSeparator + $env:PATH
 if ($GraphifyArguments.Count -eq 0) { $GraphifyArguments = @('--help') }
 if ($GraphifyArguments[0] -eq 'refresh') {
  & $taskGraphify extract . --code-only --max-workers 4
  $taskCode = $LASTEXITCODE
  if ($taskCode -eq 0) {
   & $taskGraphify cluster-only . --no-label
   $taskCode = $LASTEXITCODE
  }
 } else {
  & $taskGraphify @GraphifyArguments
  $taskCode = $LASTEXITCODE
 }
} finally {
 $env:GRAPHIFY_BACKEND = $taskPreviousBackend
 $env:GRAPHIFY_QUERY_LOG_DISABLE = $taskPreviousLog
 $env:PYTHONUTF8 = $taskPreviousUtf8
 $env:PATH = $taskPreviousPath
 Pop-Location
}
exit $taskCode
