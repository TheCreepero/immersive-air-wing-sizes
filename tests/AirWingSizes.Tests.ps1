BeforeDiscovery {
    $managerGameInfoScript = Join-Path $PSScriptRoot '..\..\..\Scripts\Vanilla\Get-HoiGameInfo.ps1'
    $script:VanillaAirPath = $null
    $script:VanillaDefinesPath = $null
    if (Test-Path -LiteralPath $managerGameInfoScript) {
        $powerShellExecutable = if (Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        $gameRootQuery = "(& '$managerGameInfoScript' -PassThru).GameRoot"
        $gameRootOutput = @(& $powerShellExecutable -NoProfile -Command $gameRootQuery 2>$null)
        if ($LASTEXITCODE -eq 0 -and $gameRootOutput.Count -gt 0) {
            $gameRoot = ([string]$gameRootOutput[-1]).Trim()
            $candidateAirPath = Join-Path $gameRoot 'common\units\air.txt'
            $candidateDefinesPath = Join-Path $gameRoot 'common\defines\00_defines.lua'
            if ((Test-Path -LiteralPath $candidateAirPath) -and (Test-Path -LiteralPath $candidateDefinesPath)) {
                $script:VanillaAirPath = $candidateAirPath
                $script:VanillaDefinesPath = $candidateDefinesPath
            }
        }
    }
    $script:HasVanillaInstall = $null -ne $script:VanillaAirPath
    $script:ExpectedDefines = [ordered]@{
        'NAir.ACE_WING_SIZE'         = '24'
        'NAir.AIR_WING_AVERAGE_SIZE' = '20'
    }
    $script:ExpectedDefineCases = @(
        foreach ($defineName in $script:ExpectedDefines.Keys) {
            @{ DefineName = $defineName; VanillaDefinesPath = $script:VanillaDefinesPath }
        }
    )
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    Import-Module (Join-Path $script:RepoRoot 'tools\AirWingSizes.psm1') -Force
    $script:SizeTable = Get-AirWingSizeTable -Path (Join-Path $script:RepoRoot 'tools\air-wing-sizes.json')
    $script:ShippedAirPath = Join-Path $script:RepoRoot 'common\units\air.txt'
    $script:DefinesPath = Join-Path $script:RepoRoot 'common\defines\zz_immersive_air_wing_sizes.lua'

    function Test-HasUtf8Bom {
        param([string]$Path)
        $fileBytes = [System.IO.File]::ReadAllBytes($Path)
        $fileBytes.Length -ge 3 -and $fileBytes[0] -eq 0xEF -and $fileBytes[1] -eq 0xBB -and $fileBytes[2] -eq 0xBF
    }

    $script:SampleText = "sub_units = {`r`n`tfighter = {`r`n`t`tneed = { small_plane_airframe = 1 }`r`n`t`tland_air_wing_size = 100 # vanilla`r`n`t`tmega_carrier_air_wing_size = 10`r`n`t}`r`n`tinfantry = {`r`n`t`tneed = { infantry_equipment = 100 }`r`n`t}`r`n`tmothership = {`r`n`t`tland_air_wing_size = 10`r`n`t}`r`n}`r`n"
}

Describe 'Size table' {
    It 'gives every sized sub-unit a whole number of planes from 1 to 1000' {
        foreach ($subUnitName in $script:SizeTable.Sizes.Keys) {
            $script:SizeTable.Sizes[$subUnitName] | Should -BeGreaterOrEqual 1 -Because $subUnitName
            $script:SizeTable.Sizes[$subUnitName] | Should -BeLessOrEqual 1000 -Because $subUnitName
        }
    }

    It 'never lists a sub-unit as both sized and unchanged' {
        $doubleListed = @($script:SizeTable.Sizes.Keys | Where-Object { $script:SizeTable.Unchanged.Contains($_) })
        $doubleListed | Should -BeNullOrEmpty
    }
}

Describe 'Convert-AirWingSizeText' {
    It 'changes only the land size of a sized sub-unit and keeps comments, other keys and CRLF' {
        $conversion = Convert-AirWingSizeText -Text $script:SampleText -SizeTable $script:SizeTable
        $expectedText = $script:SampleText.Replace('land_air_wing_size = 100 # vanilla', 'land_air_wing_size = 24 # vanilla')
        $conversion.Text | Should -BeExactly $expectedText
        @($conversion.Changes).Count | Should -Be 1
        $conversion.Changes[0].SubUnit | Should -Be 'fighter'
        $conversion.Changes[0].NewSize | Should -Be 24
    }

    It 'stops on an air sub-unit the table does not list' {
        $unlistedText = $script:SampleText.Replace('mothership', 'unlisted_plane')
        { Convert-AirWingSizeText -Text $unlistedText -SizeTable $script:SizeTable } | Should -Throw "*unlisted_plane*"
    }

    It 'stops on a sized sub-unit without a land_air_wing_size line' {
        $noLandSizeText = $script:SampleText.Replace("`t`tland_air_wing_size = 100 # vanilla`r`n", '')
        { Convert-AirWingSizeText -Text $noLandSizeText -SizeTable $script:SizeTable } | Should -Throw "*fighter*no land_air_wing_size*"
    }
}

Describe 'Set-AirWingSizes.ps1' {
    It 'writes a relative destination under the PowerShell location, not the process directory' {
        $sourcePath = Join-Path $TestDrive 'source.txt'
        [System.IO.File]::WriteAllText($sourcePath, $script:SampleText)
        $locationDirectory = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'location') -Force
        $processDirectory = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'process') -Force
        $originalProcessDirectory = [Environment]::CurrentDirectory
        try {
            [Environment]::CurrentDirectory = $processDirectory.FullName
            Push-Location -LiteralPath $locationDirectory.FullName
            & (Join-Path $script:RepoRoot 'tools\Set-AirWingSizes.ps1') -SourcePath $sourcePath -DestinationPath '.\out\air.txt' 6>$null | Out-Null
        }
        finally {
            Pop-Location
            [Environment]::CurrentDirectory = $originalProcessDirectory
        }
        Test-Path -LiteralPath (Join-Path $locationDirectory.FullName 'out\air.txt') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $processDirectory.FullName 'out\air.txt') | Should -BeFalse
    }
}

Describe 'Shipped common/units/air.txt' {
    It 'is saved without a UTF-8 BOM' {
        Test-HasUtf8Bom -Path $script:ShippedAirPath | Should -BeFalse
    }

    It 'gives every air sub-unit the size of the table or leaves it as listed unchanged' {
        $shippedEntries = Get-AirSubUnitWingSize -Text ([System.IO.File]::ReadAllText($script:ShippedAirPath))
        $landEntries = @($shippedEntries | Where-Object { $_.Key -eq 'land_air_wing_size' })
        $landEntries.Count | Should -BeGreaterThan 0
        foreach ($landEntry in $landEntries) {
            if ($script:SizeTable.Sizes.ContainsKey($landEntry.SubUnit)) {
                $landEntry.Value | Should -Be $script:SizeTable.Sizes[$landEntry.SubUnit] -Because $landEntry.SubUnit
            }
            else {
                $script:SizeTable.Unchanged.Contains($landEntry.SubUnit) | Should -BeTrue -Because "$($landEntry.SubUnit) must be in the size table"
            }
        }
    }

    It 'is the installed vanilla file with the table applied' -Skip:(-not $script:HasVanillaInstall) -ForEach @(@{ VanillaAirPath = $script:VanillaAirPath }) {
        $vanillaText = [System.IO.File]::ReadAllText($VanillaAirPath)
        $expectedText = (Convert-AirWingSizeText -Text $vanillaText -SizeTable $script:SizeTable).Text -replace "`r`n", "`n"
        $shippedText = [System.IO.File]::ReadAllText($script:ShippedAirPath) -replace "`r`n", "`n"
        $shippedText | Should -BeExactly $expectedText -Because 'a game update changed vanilla air.txt: run tools\Set-AirWingSizes.ps1 again'
    }
}

Describe 'Shipped defines' {
    It 'is saved without a UTF-8 BOM' {
        Test-HasUtf8Bom -Path $script:DefinesPath | Should -BeFalse
    }

    It 'sets single NDefines entries only' {
        $definesLines = @([System.IO.File]::ReadAllLines($script:DefinesPath) | Where-Object { $_.Trim() -ne '' })
        $definesLines.Count | Should -BeGreaterThan 0
        foreach ($definesLine in $definesLines) {
            $definesLine | Should -Match '^NDefines\.N[A-Za-z]+\.[A-Z0-9_]+ = -?\d+(\.\d+)?$'
        }
    }

    It 'sets exactly the planned defines to the planned values' -ForEach @(@{ ExpectedDefines = $script:ExpectedDefines }) {
        $shippedDefines = [ordered]@{}
        foreach ($definesLine in @([System.IO.File]::ReadAllLines($script:DefinesPath) | Where-Object { $_.Trim() -ne '' })) {
            if ($definesLine -match '^NDefines\.(N[A-Za-z]+\.[A-Z0-9_]+) = (\S+)$') {
                $shippedDefines[$Matches[1]] = $Matches[2]
            }
        }
        @($shippedDefines.Keys | Sort-Object) | Should -Be @($ExpectedDefines.Keys | Sort-Object)
        foreach ($defineName in $ExpectedDefines.Keys) {
            $shippedDefines[$defineName] | Should -Be $ExpectedDefines[$defineName] -Because $defineName
        }
    }

    It '<DefineName> is a name the vanilla defines file sets in its table' -Skip:(-not $script:HasVanillaInstall) -ForEach $script:ExpectedDefineCases {
        $tableName, $entryName = $DefineName.Split('.')
        $vanillaLines = [System.IO.File]::ReadAllLines($VanillaDefinesPath)
        $currentTable = $null
        $isFound = $false
        foreach ($vanillaLine in $vanillaLines) {
            if ($vanillaLine -match '^(N[A-Za-z]+) = \{') {
                $currentTable = $Matches[1]
            }
            elseif ($currentTable -eq $tableName -and $vanillaLine -match "^\s*$entryName\s*=") {
                $isFound = $true
                break
            }
        }
        $isFound | Should -BeTrue -Because "$entryName must exist in vanilla's $tableName table; the game ignores an unknown name [DEF-002]"
    }
}
