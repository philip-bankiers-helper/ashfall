param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [string]$OutputDirectory,
    [string]$LogDirectory,
    [switch]$SkipPublicChecks
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Pass -GodotPath pointing to an official Godot 4.7.2 Windows executable.' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'build' }
if (-not $LogDirectory) { $LogDirectory = Join-Path $OutputDirectory 'logs' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$LogDirectory = [IO.Path]::GetFullPath($LogDirectory)
New-Item -ItemType Directory -Force $OutputDirectory,$LogDirectory | Out-Null
function Invoke-GodotStep([string]$Name,[string[]]$Arguments) {
    $logPath = Join-Path $LogDirectory ($Name+'.log')
    $consolePath = Join-Path $LogDirectory ($Name+'-console.txt')
    $previousAppData = $env:APPDATA
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:APPDATA = Join-Path $LogDirectory 'profile\Roaming'
        $env:LOCALAPPDATA = Join-Path $LogDirectory 'profile\Local'
        New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
        & $GodotPath @Arguments --log-file $logPath *> $consolePath
    } finally {
        $env:APPDATA = $previousAppData
        $env:LOCALAPPDATA = $previousLocalAppData
    }
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit $LASTEXITCODE. See $logPath" }
    if ((Get-Content -LiteralPath $logPath -Raw) -match '(?m)SCRIPT ERROR:|Parse Error:|^ERROR:') { throw "$Name reported errors. See $logPath" }
}
Invoke-GodotStep 'import' @('--headless','--xr-mode','off','--audio-driver','Dummy','--path',$projectRoot,'--editor','--import')
if (-not $SkipPublicChecks) {
    Invoke-GodotStep 'public-checks' @('--headless','--xr-mode','off','--audio-driver','Dummy','--path',$projectRoot,'--script','res://tools/test_public.gd')
    if ((Get-Content -LiteralPath (Join-Path $LogDirectory 'public-checks.log') -Raw) -notmatch 'PUBLIC_CHECKS_OK') { throw 'Public distribution checks did not complete.' }
}
$executable = Join-Path $OutputDirectory 'Ashfall.exe'
Invoke-GodotStep 'export' @('--headless','--xr-mode','off','--audio-driver','Dummy','--path',$projectRoot,'--export-release','Windows Desktop',$executable)
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Export did not create Ashfall.exe.' }
$result = [ordered]@{executable=$executable;sha256=(Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $executable).Length;xr_started=$false;headset_verified=$false}
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $LogDirectory 'build-result.json') -Encoding utf8
$result | ConvertTo-Json
