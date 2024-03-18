#Requires -Modules Pester
#Requires -Version 5.1

BeforeDiscovery {
    # used by inModuleScope
    $testModule = $PSCommandPath.Replace('.Tests.ps1', '.psm1')
    $testModuleName = $testModule.Split('\')[-1].TrimEnd('.psm1')

    Remove-Module $testModuleName -Force -Verbose:$false -EA Ignore
    Import-Module $testModule -Force -Verbose:$false
}
Describe 'Get-DefaultParameterValuesHC' {
    InModuleScope $testModuleName {
        Context 'should retrieve the default values' {
            It 'from a script file' {
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

                $actual.Keys | Should -HaveCount 2
                $actual.ScriptName | Should -Be 'Get printers'
                $actual.PaperSize | Should -Be 'A4'
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

                $actual.Keys | Should -HaveCount 2
                $actual.ScriptName | Should -Be 'Get printers'
                $actual.PaperSize | Should -Be 'A4'
            }
        }
        Context 'should not retrieve the default value when' {
            It 'the parameter is Mandatory' {
                Function Test-Function {
                    Param (
                        [Parameter(Mandatory)]
                        [String]$PrinterName = 'NotValidName',
                        [String]$PaperSize = 'A4'
                    )
                }

                $actual = Get-DefaultParameterValuesHC -Path 'Test-Function'

                $actual.Keys | Should -HaveCount 1
                $actual.PaperSize | Should -Be 'A4'
            }
            It 'there are no default values' {
                Function Test-Function {
                    Param (
                        [Parameter(Mandatory)]
                        [String]$PrinterName = 'NotValidName',
                        [String]$PaperSize
                    )
                }

                $actual = Get-DefaultParameterValuesHC -Path 'Test-Function'

                $actual | Should -BeNullOrEmpty
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

                $actual.userName | Should -BeExactly $env:USERNAME
                $actual.userName | Should -BeOfType [String]
            }
            It 'an array of strings to an array of strings with env variables' {
                Function Test-Function {
                    Param (
                        [String[]]$ComputerNames = @($env:COMPUTERNAME, 'PC2')
                    )
                }

                $actual = Get-DefaultParameterValuesHC -Path 'Test-Function'

                $actual.ComputerNames | Should -HaveCount 2
                $actual.ComputerNames[0] | Should -BeExactly $env:COMPUTERNAME
                $actual.ComputerNames[1] | Should -BeExactly 'PC2'
            }
            It 'a hashtable to hashtable' {
                Function Test-Function {
                    Param (
                        [HashTable]$Settings = @{ Duplex = 'Yes' }
                    )
                }

                $actual = Get-DefaultParameterValuesHC -Path 'Test-Function'

                $actual.Settings | Should -BeOfType [HashTable]
            }`
        }
    }
}
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
Describe 'Show-MenuHC' {
    InModuleScope -ModuleName $testModuleName {
        Context 'the mandatory parameters are' {
            It '<_>' -ForEach @( 'Items' ) {
            (Get-Command Show-MenuHC).Parameters[$_].Attributes.Mandatory |
                Should -BeTrue
            }
        }
        Context 'the quit selector' {
            Describe 'when used' {
                BeforeAll {
                    Mock Write-Host
                    Mock Read-Host { 'Q' }

                    $testParams = @{
                        Items           = @('banana', 'kiwi')
                        QuitSelector    = @{ 'Q' = 'Quit' }
                        DisplayTemplate = '{0}) {1}'
                    }
                    $testResult = Show-MenuHC @testParams
                }
                It 'display a line to leave the menu' {
                    Should -Invoke Write-Host -Times 1 -Exactly -Scope Describe -ParameterFilter {
                        $Object -eq 'Q) Quit'
                    }
                }
                It 'return nothing from the function' {
                    $testResult | Should -BeNullOrEmpty
                }
            }
            Describe 'when not used' {
                BeforeAll {
                    Mock Write-Host
                    Mock Read-Host { '1' }

                    $testParams = @{
                        Items           = @('banana', 'kiwi')
                        QuitSelector    = $null
                        DisplayTemplate = '{0}) {1}'
                    }
                    $testResult = Show-MenuHC @testParams
                }
                It 'the user cannot leave the menu without selecting something' {
                    Should -Invoke Write-Host -Times 2 -Exactly -Scope Describe
                    Should -Invoke Write-Host -Times 2 -Exactly -Scope Describe -ParameterFilter {
                        $Object -match 'banana|kiwi'
                    }
                }
            }
        }
        Context 'selected properties' {
            BeforeAll {
                Mock Write-Host
                Mock Read-Host { '1' }

                $testParams = @{
                    Items           = @(
                        [PSCustomObject]@{ Name = 'banana'; Color = 'yellow' }
                        [PSCustomObject]@{ Name = 'kiwi'; Color = 'green' }
                    )
                    QuitSelector    = $null
                    DisplayTemplate = '{0}) {1}'
                    Properties      = 'name'
                }
                $testResult = Show-MenuHC @testParams
            }
            It 'are only visible in the menu' {
                Should -Invoke Write-Host -Times 2 -Exactly -Scope Context
                Should -Invoke Write-Host -Times 1 -Exactly -Scope Context -ParameterFilter {
                    $Object -eq '1) @{Name=banana}'
                }
                Should -Invoke Write-Host -Times 1 -Exactly -Scope Context -ParameterFilter {
                    $Object -eq '2) @{Name=kiwi}'
                }
            }
            It 'do not change the return value of the function' {
                $testResult | Should -HaveCount 1
                $testResult.Name | Should -Be 'banana'
                $testResult.Color | Should -Be 'yellow'
                $testResult | Should -BeOfType [PSCustomObject]
            }
        }
        Context 'when the items to display are' {
            BeforeDiscovery {
                $testCases = @(
                    @{
                        testName          = 'HashTable'
                        testItems         = @(
                            [Ordered]@{
                                Name  = 'banana'
                                Color = 'yellow'
                            }
                            [Ordered]@{
                                Name  = 'kiwi'
                                Color = 'green'
                            }
                        )
                        testWriteHostCall = @(
                            '1) @{Name=banana; Color=yellow}',
                            '2) @{Name=kiwi; Color=green}'
                        )
                    }
                )
            }
            Context 'not piped to the function and of type' {
                Describe '<testName>' -ForEach $testCases {
                    BeforeAll {
                        Mock Write-Host {
                            Write-Verbose $Object
                        }
                        Mock Read-Host { '1' }

                        $testParams = @{
                            QuitSelector    = $null
                            DisplayTemplate = '{0}) {1}'
                            Items           = $testItems
                        }
                        $testResult = Show-MenuHC @testParams
                    }
                    It 'all items are displayed in the menu' {
                        Should -Invoke Write-Host -Times $testWriteHostCall.Count -Exactly -Scope Describe

                        foreach ($testCall in $testWriteHostCall) {
                            Should -Invoke Write-Host -Times 1 -Exactly -Scope Describe -ParameterFilter {
                                $Object -eq $testCall
                            }
                        }
                    }
                    It 'the selected value is returned' {
                        $testResult | Should -HaveCount 1
                        $testResult | Should -Be $testItems[0]
                    }
                    It 'the returned value is not altered' {
                        $testResult | Should -BeOfType $testItems[0].GetType()
                    }
                }
            }
            Context 'piped to the function and of type' {
                Describe '<testName>' -ForEach $testCases {
                    BeforeAll {
                        Mock Write-Host
                        Mock Read-Host { '1' }

                        $testParams = @{
                            QuitSelector    = $null
                            DisplayTemplate = '{0}) {1}'
                        }
                        $testResult = $testItems | Show-MenuHC @testParams
                    }
                    It 'all items are displayed in the menu' {
                        Should -Invoke Write-Host -Times $testWriteHostCall.Count -Exactly -Scope Describe

                        foreach ($testCall in $testWriteHostCall) {
                            Should -Invoke Write-Host -Times 1 -Exactly -Scope Describe -ParameterFilter {
                                $Object -eq $testCall
                            }
                        }
                    }
                    It 'the selected value is returned' {
                        $testResult | Should -HaveCount 1
                        $testResult | Should -Be $testItems[0]
                    }
                    It 'the returned value is not altered' {
                        $testResult | Should -BeOfType $testItems[0].GetType()
                    }
                }
            }
        }
    }
}