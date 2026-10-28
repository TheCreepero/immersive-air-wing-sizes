Set-StrictMode -Version Latest

$script:WingSizeKeys = @('land_air_wing_size', 'carrier_air_wing_size', 'submarine_carrier_air_wing_size', 'mega_carrier_air_wing_size')

function Get-AirWingSizeTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $tableJson = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
    $sizes = @{}
    foreach ($sizeEntry in $tableJson.sizes.PSObject.Properties) {
        $sizes[$sizeEntry.Name] = [int]$sizeEntry.Value
    }
    $unchanged = [System.Collections.Generic.HashSet[string]]::new([string[]]@($tableJson.unchanged))

    [PSCustomObject]@{
        Sizes     = $sizes
        Unchanged = $unchanged
    }
}

function Split-ScriptLines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    @([regex]::Split($Text, '(?<=\n)') | Where-Object { $_ -ne '' })
}

function Get-CodePart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Line
    )

    $insideQuotes = $false
    for ($characterIndex = 0; $characterIndex -lt $Line.Length; $characterIndex++) {
        $character = $Line[$characterIndex]
        if ($character -eq '"') {
            $insideQuotes = -not $insideQuotes
        }
        elseif ($character -eq '#' -and -not $insideQuotes) {
            return $Line.Substring(0, $characterIndex)
        }
    }
    $Line
}

function Get-AirSubUnitWingSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $lines = Split-ScriptLines -Text $Text
    $entries = [System.Collections.Generic.List[PSObject]]::new()
    $depth = 0
    $currentSubUnit = $null
    $keyPattern = '^\s*(' + ($script:WingSizeKeys -join '|') + ')\s*=\s*(-?\d+)'

    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $codePart = Get-CodePart -Line $lines[$lineIndex]

        if ($depth -eq 1 -and $codePart -match '^\s*([A-Za-z0-9_]+)\s*=\s*\{') {
            $currentSubUnit = $Matches[1]
        }
        elseif ($depth -eq 2 -and $null -ne $currentSubUnit -and $codePart -match $keyPattern) {
            $entries.Add([PSCustomObject]@{
                    SubUnit   = $currentSubUnit
                    Key       = $Matches[1]
                    Value     = [int]$Matches[2]
                    LineIndex = $lineIndex
                })
        }

        $depth += ([regex]::Matches($codePart, '\{')).Count - ([regex]::Matches($codePart, '\}')).Count
        if ($depth -le 1) {
            $currentSubUnit = $null
        }
    }

    , $entries
}

function Convert-AirWingSizeText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [PSObject]$SizeTable,

        [string]$SourceName = 'the source file'
    )

    $lines = Split-ScriptLines -Text $Text
    $entries = Get-AirSubUnitWingSize -Text $Text
    $landEntries = @($entries | Where-Object { $_.Key -eq 'land_air_wing_size' })
    $airSubUnits = @($entries | ForEach-Object { $_.SubUnit } | Select-Object -Unique)

    foreach ($airSubUnit in $airSubUnits) {
        $isListed = $SizeTable.Sizes.ContainsKey($airSubUnit) -or $SizeTable.Unchanged.Contains($airSubUnit)
        if (-not $isListed) {
            throw "Air sub-unit '$airSubUnit' in $SourceName is not in the size table: add it to 'sizes' or 'unchanged'."
        }
        $hasLandSize = @($landEntries | Where-Object { $_.SubUnit -eq $airSubUnit }).Count -gt 0
        if ($SizeTable.Sizes.ContainsKey($airSubUnit) -and -not $hasLandSize) {
            throw "Air sub-unit '$airSubUnit' in $SourceName has no land_air_wing_size line to change."
        }
    }

    $changes = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($landEntry in $landEntries) {
        if (-not $SizeTable.Sizes.ContainsKey($landEntry.SubUnit)) {
            continue
        }
        $newSize = $SizeTable.Sizes[$landEntry.SubUnit]
        $lines[$landEntry.LineIndex] = [regex]::Replace($lines[$landEntry.LineIndex], '(land_air_wing_size\s*=\s*)-?\d+', ('${1}' + $newSize), 1)
        $changes.Add([PSCustomObject]@{
                SubUnit = $landEntry.SubUnit
                OldSize = $landEntry.Value
                NewSize = $newSize
            })
    }

    [PSCustomObject]@{
        Text    = $lines -join ''
        Changes = @($changes)
    }
}

Export-ModuleMember -Function Get-AirWingSizeTable, Get-AirSubUnitWingSize, Convert-AirWingSizeText
