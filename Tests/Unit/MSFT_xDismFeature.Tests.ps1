#region HEADER

$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
    (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) ) {
    & git @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))
}
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath (Join-Path -Path 'DSCResource.Tests' -ChildPath 'TestHelper.psm1')) -Force

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'xDismFeature' `
    -DSCResourceName 'MSFT_xDismFeature' `
    -TestType Unit

#endregion HEADER

function Invoke-TestCleanup {
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}

# Begin Testing
try {
    InModuleScope 'MSFT_xDismFeature' {
        #region Set variables for testing
        $TestEnabledFeature1 = 'Feature1'
        $TestDisabledFeature1 = 'Feature2'
        $TestUnknownStateFeature1 = 'Feature3'
        $TestNonExistenceFeature1 = 'FeatureX'

        $TestSourcePath1 = 'Z:\TestFolder'

        $ValidDismGetFeaturesOutput = @"

Deployment Image Servicing and Management tool
Version: 10.0.17134.1

Image Version: 10.0.17134.48

Features listing for package : Microsoft-Windows-Foundation-Package~31bf3856ad364e35~amd64~~10.0.17134.1

Feature Name : $TestEnabledFeature1
State : Enabled

Feature Name : $TestDisabledFeature1
State : Disabled

The operation completed successfully.
"@
        #endregion Set variables for testing

        #region Tests for Get-TargetResource
        Describe 'xDismFeature/Get-TargetResource' {

            Mock Get-DismFeatures {
                return @{
                    $TestEnabledFeature1      = 'Enabled'
                    $TestDisabledFeature1     = 'Disabled'
                    $TestUnknownStateFeature1 = 'Unknown'
                }
            }

            Context 'Feature does not exist' {

                It 'Should throw exception with "Unknown feature!" message.' {
                    { Get-TargetResource -Name $TestNonExistenceFeature1 } | Should -Throw 'Unknown feature!'
                }

            }

            Context 'Feature exists and is enabled' {

                It 'Should return the "Present" hashtable' {
                    $getTargetResult = Get-TargetResource -Name $TestEnabledFeature1
                    $getTargetResult.Ensure | Should -Be 'Present'
                    $getTargetResult.Name | Should -Be $TestEnabledFeature1
                }

            }

            Context 'Feature exists and is disabled' {

                It 'Should return the "Absent" hashtable' {
                    $getTargetResult = Get-TargetResource -Name $TestDisabledFeature1
                    $getTargetResult.Ensure | Should -Be 'Absent'
                    $getTargetResult.Name | Should -Be $TestDisabledFeature1
                }

            }

            Context 'Feature exists but the status is neither enabled nor disabled' {

                It 'Should return the "Absent" hashtable' {
                    $getTargetResult = Get-TargetResource -Name $TestUnknownStateFeature1
                    $getTargetResult.Ensure | Should -Be 'Absent'
                    $getTargetResult.Name | Should -Be $TestUnknownStateFeature1
                }
                
            }
        }
        #endregion Tests for Get-TargetResource

        #region Tests for Set-TargetResource
        Describe 'xDismFeature/Set-TargetResource' {

            Mock Invoke-Dism {}

            Context 'Ensure set to "Present" and Source parameter not specified' {

                It 'Should call dism.exe with correct arguments' {
                    { Set-TargetResource -Ensure 'Present' -Name $TestDisabledFeature1 } | Should -Not -Throw
                        
                    Assert-MockCalled -CommandName Invoke-Dism -Times 1 -Exactly -Scope It `
                        -ParameterFilter {
                            $DismParameters -contains "/Online" -and `
                            $DismParameters -contains "/Enable-Feature" -and `
                            $DismParameters -contains "/FeatureName:$TestDisabledFeature1" -and `
                            $DismParameters -notcontains "/Source:$TestSourcePath1"
                    }
                }
            }

            Context 'Ensure set to "Present" and Source parameter specified' {

                It 'Should call dism.exe with correct arguments' {
                    { Set-TargetResource -Ensure 'Present' -Name $TestDisabledFeature1 -Source $TestSourcePath1 } | Should -Not -Throw
                        
                    Assert-MockCalled -CommandName Invoke-Dism -Times 1 -Exactly -Scope It `
                        -ParameterFilter {
                            $DismParameters -contains "/Online" -and `
                            $DismParameters -contains "/Enable-Feature" -and `
                            $DismParameters -contains "/FeatureName:$TestDisabledFeature1" -and `
                            $DismParameters -contains "/Source:$TestSourcePath1" -and `
                            $DismParameters -contains "/LimitAccess"
                    }
                }
            }

            Context 'Ensure set to "Absent"' {

                It 'Should call dism.exe with correct arguments' {
                    { Set-TargetResource -Ensure 'Absent' -Name $TestDisabledFeature1 } | Should -Not -Throw
                    
                    Assert-MockCalled -CommandName Invoke-Dism -Times 1 -Exactly -Scope It `
                        -ParameterFilter {
                            $DismParameters -contains "/Online" -and `
                            $DismParameters -contains "/Disable-Feature" -and `
                            $DismParameters -contains "/FeatureName:$TestDisabledFeature1"
                    }
                }
            }

            Context '$global:DSCMachineStatus' {

                AfterEach {
                    Remove-Variable DSCMachineStatus -Scope Global -Force -ErrorAction SilentlyContinue
                }

                It 'Should set $global:DSCMachineStatus to 1 when "RebootPending" reg key is exist' {
                    Mock Test-Path { return $true } -ParameterFilter {$Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'}

                    { Set-TargetResource -Ensure 'Absent' -Name $TestDisabledFeature1 } | Should -Not -Throw
                    $global:DSCMachineStatus | Should -Be 1
                }

                It 'Should not set $global:DSCMachineStatus when "RebootPending" reg key is not exist' {
                    Mock Test-Path { return $false } -ParameterFilter {$Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'}

                    { Set-TargetResource -Ensure 'Absent' -Name $TestDisabledFeature1 } | Should -Not -Throw
                    $global:DSCMachineStatus | Should -BeNullOrEmpty
                }
            }
        }
        #endregion Tests for Set-TargetResource

        #region Tests for Set-TargetResource
        Describe 'xDismFeature/Test-TargetResource' {

            Mock Get-TargetResource {
                return @{
                    Ensure = 'Present'
                    Name   = $TestEnabledFeature1
                }
            } -ParameterFilter {$Name -eq $TestEnabledFeature1}

            Mock Get-TargetResource {
                return @{
                    Ensure = 'Absent'
                    Name   = $TestDisabledFeature1
                }
            } -ParameterFilter {$Name -eq $TestDisabledFeature1}

            Context 'Feature is in the desired state' {

                It 'Should return $true when Ensure set to Present and Feature is enabled' {
                    $testTargetResult = Test-TargetResource -Ensure 'Present' -Name $TestEnabledFeature1
                    $testTargetResult | Should -Be $true
                }

                It 'Should return $true when Ensure set to Absent and Feature is disabled' {
                    $testTargetResult = Test-TargetResource -Ensure 'Absent' -Name $TestDisabledFeature1
                    $testTargetResult | Should -Be $true
                }

            }

            Context 'Feature is not in the desired state' {

                It 'Should return $false when Ensure set to Present and Feature is disabled' {
                    $testTargetResult = Test-TargetResource -Ensure 'Present' -Name $TestDisabledFeature1
                    $testTargetResult | Should -Be $false
                }

                It 'Should return $false when Ensure set to Absent and Feature is enabled' {
                    $testTargetResult = Test-TargetResource -Ensure 'Absent' -Name $TestEnabledFeature1
                    $testTargetResult | Should -Be $false
                }

            }
        }
        #endregion Tests for Test-TargetResource

        #region Tests for Get-DismFeatures
        Describe 'xDismFeature/Get-DismFeatures' {

            Context 'Valid dism output' {

                It 'Should return the correct hashtable' {
                    Mock Invoke-Dism { return $ValidDismGetFeaturesOutput.Split("`n`r") }

                    $getDismFeaturesResult = Get-DismFeatures
                    $getDismFeaturesResult.Count | Should -Be 2
                    $getDismFeaturesResult[$TestEnabledFeature1] | Should -Be 'Enabled'
                    $getDismFeaturesResult[$TestDisabledFeature1] | Should -Be 'Disabled'
                }

            }

            Context 'Invalid dism output' {

                It 'Should return the empty hashtable' {
                    Mock Invoke-Dism { return "" }

                    $getDismFeaturesResult = Get-DismFeatures
                    $getDismFeaturesResult | Should -BeOfType System.Collections.Hashtable
                    $getDismFeaturesResult.Count | Should -Be 0
                }

            }
        }
        #endregion Tests for Get-DismFeatures
    }
}
finally {
    Invoke-TestCleanup
}

