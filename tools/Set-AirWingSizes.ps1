[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [string]$DestinationPath,

    [string]$SizeTablePath
)

$ErrorActionPreference = 'Stop'

$toolsDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SizeTablePath) {
    $SizeTablePath = Join-Path $toolsDirectory 'air-wing-sizes.json'
}

Import-Module (Join-Path $toolsDirectory 'AirWingSizes.psm1') -Force

$resolvedSourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
$sizeTable = Get-AirWingSizeTable -Path $SizeTablePath
$sourceText = [System.IO.File]::ReadAllText($resolvedSourcePath)
$conversion = Convert-AirWingSizeText -Text $sourceText -SizeTable $sizeTable -SourceName $resolvedSourcePath

$resolvedDestinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
$destinationDirectory = Split-Path -Parent $resolvedDestinationPath
if (-not (Test-Path -LiteralPath $destinationDirectory)) {
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
}
[System.IO.File]::WriteAllText($resolvedDestinationPath, $conversion.Text, [System.Text.UTF8Encoding]::new($false))

Write-Host "Wrote $resolvedDestinationPath from $resolvedSourcePath ($($conversion.Changes.Count) land wing size(s) set)."
$conversion.Changes
