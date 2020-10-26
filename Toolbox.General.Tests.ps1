#Requires -Modules Pester
#Requires -Version 5.1

$moduleName = 'Toolbox.General'

$testModule = $PSCommandPath.Replace('.Tests.ps1', '.psm1')
Remove-Module $moduleName -Force -Verbose:$false -EA Ignore
Import-Module $testModule -Force -Verbose:$false


Describe 'Get-DefaultParameterValuesHC' {
    InModuleScope $moduleName {
        Context 'should retrieve the default values' {
            It 'from a script' {
                $testScript = (New-Item -Path "TestDrive:\scripts.ps1" -Force -ItemType File -EA Ignore).FullName
                @"
        Param (
            [Parameter(Mandatory)]
            [String]`$PrinterName,
            [Parameter(Mandatory)]
            [String]`$PrinterColor,
            [String]`$ScriptName = 'Get printers',
            [String]`$PaperSize = 'A4'
        )
"@ | Out-File -FilePath $testScript -Encoding utf8 -Force
                $actual = Get-DefaultParameterValuesHC -Path $testScript

                $expected = @{
                    ScriptName = 'Get printers'
                    PaperSize  = 'A4'
                }
                $actual.Keys | Should -HaveCount $expected.Keys.Count
                $actual.Keys | ForEach-Object { $actual[$_] | Should -Be $expected[$_] }
            }
            It 'from a function' {
                Function Test-Function {
                    Param (
                        [Parameter(Mandatory)]
                        [String]$PrinterName,
                        [Parameter(Mandatory)]
                        [String]$PrinterColor,
                        [String]$ScriptName = 'Get printers',
                        [String]$PaperSize = 'A4'
                    )
                }
    
                $actual = Get-DefaultParameterValuesHC -Path 'Test-Function'
    
                $expected = @{
                    ScriptName = 'Get printers'
                    PaperSize  = 'A4'
                }
                $actual.Keys | Should -HaveCount $expected.Keys.Count
                $actual.Keys | ForEach-Object { $actual[$_] | Should -Be $expected[$_] }
            }
        }
        Context 'should convert' {
            It 'an env variable to a string' {
                Function Test-Function {
                    Param (
                        [String]$userName = $env:USERNAME
                    )
                }

                $actual = Get-DefaultParameterValuesHC -Path 'Test-Function'

                $actual.userName | should -BeExactly $env:USERNAME
            }
            It 'an array of strings to an array of strings with env variables' {
                Function Test-Function {
                    Param (
                        [String[]]$ComputerNames = @($env:COMPUTERNAME, 'PC2')
                    )
                }

                $actual = Get-DefaultParameterValuesHC -Path 'Test-Function'

                $actual.ComputerNames[0] | should -BeExactly $env:COMPUTERNAME
                $actual.ComputerNames[1] | should -BeExactly 'PC2'
            }
        }
    }
}  -Tag test
Describe 'Remove-PowerShellWildcardCharsHC' {
    It "Remove character '['" {
        'Kiwi[And Apples' | Remove-PowerShellWildcardCharsHC | Should -BeExactly 'KiwiAnd Apples'
    }
    It "Remove character ']'" {
        'Kiwi]And Apples' | Remove-PowerShellWildcardCharsHC | Should -BeExactly 'KiwiAnd Apples'
    }
    It "Remove character '['" {
        'Kiwi*And Apples' | Remove-PowerShellWildcardCharsHC | Should -BeExactly 'KiwiAnd Apples'
    }
    It "Remove character '['" {
        'Kiwi?And Apples' | Remove-PowerShellWildcardCharsHC | Should -BeExactly 'KiwiAnd Apples'
    }
    It "Remove character '[ ] ? *'" {
        'Kiwi?And *?Apples[0]' | Remove-PowerShellWildcardCharsHC | Should -BeExactly 'KiwiAnd Apples0'
    }
    It "Remove nothing" {
        'KiwiAnd Apples' | Remove-PowerShellWildcardCharsHC | Should -BeExactly 'KiwiAnd Apples'
    }
}
Describe 'Parameter-ParameterInPositionAndMandatoryHC' {
    It 'parameter mandatory' {
        Function Get-Foo {
            Param (
                [Parameter(Mandatory = $true)]
                [String]$Name,
                [Parameter(Mandatory = $false)]
                [String]$Time
            )
        }

        Test-ParameterInPositionAndMandatoryHC -Collection ((Get-Command Get-Foo).Parameters) -Requirement @{
            1 = 'Name'
            2 = 'Time'
        } | Should -BeExactly 'Time'

        Function Get-Foo {
            Param (
                [Parameter(Mandatory = $false)]
                [String]$Name,
                [Parameter(Mandatory = $false)]
                [String]$Time
            )
        }

        Test-ParameterInPositionAndMandatoryHC -Collection ((Get-Command Get-Foo).Parameters) -Requirement @{
            1 = 'Name'
            2 = 'Time'
        } | Should -BeExactly 'Time', 'Name'

        Function Get-Foo {
            Param (
                [Parameter(Mandatory)]
                [String]$Name,
                [Parameter(Mandatory)]
                [String]$Time
            )
        }

        Test-ParameterInPositionAndMandatoryHC -Collection ((Get-Command Get-Foo).Parameters) -Requirement @{
            1 = 'Name'
            2 = 'Time'
        } | Should -BeNullOrEmpty
    }
    It 'parameter not present' {
        Function Get-Foo {
            Param (
                [Parameter(Mandatory)]
                [String]$Name,
                [Parameter(Mandatory = $false)]
                [String]$kiwi
            )
        }

        Test-ParameterInPositionAndMandatoryHC -Collection ((Get-Command Get-Foo).Parameters) -Requirement @{
            1 = 'Name'
            2 = 'NotThere'
        } | Should -BeExactly 'NotThere'

        Function Get-Foo {
            Param (
                [Parameter(Mandatory)]
                [String]$Name,
                [Parameter(Mandatory)]
                [String]$kiwi
            )
        }

        Test-ParameterInPositionAndMandatoryHC -Collection ((Get-Command Get-Foo).Parameters) -Requirement @{
            1 = 'Name'
            2 = 'NotThere'
        } | Should -BeExactly 'NotThere'

        Function Get-Foo {
            Param (
                [Parameter(Mandatory)]
                [String]$Name
            )
        }

        Test-ParameterInPositionAndMandatoryHC -Collection ((Get-Command Get-Foo).Parameters) -Requirement @{
            1 = 'Name'
            2 = 'NotThere'
        } | Should -BeExactly 'NotThere'
    }
    It 'parameter not in correct position' {
        Function Get-Foo {
            Param (
                [Parameter(Mandatory)]
                [String]$Name,
                [Parameter(Mandatory)]
                [String]$kiwi,
                [Parameter(Mandatory)]
                [String]$Time
            )
        }

        Test-ParameterInPositionAndMandatoryHC -Collection ((Get-Command Get-Foo).Parameters) -Requirement @{
            1 = 'Name'
            2 = 'Time'
        } | Should -BeExactly 'Time'
    }
}