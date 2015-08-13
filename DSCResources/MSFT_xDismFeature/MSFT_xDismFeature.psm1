function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $DismFeatures = Get-DismFeatures

    if($DismFeatures."$Name" -eq $null)
    {
        Throw "Unknown feature!"
    }
    
    if($DismFeatures."$Name" -eq "Enabled")
    {
        $returnValue = @{
            Ensure = "Present"
            Name = $Name
        }
    }
    else
    {
        $returnValue = @{
            Ensure = "Absent"
            Name = $Name
        }
    }

    $returnValue
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $false)]
        [System.Boolean]
        $EnableAllParentFeatures = $true
    )

    switch($Ensure)
    {
        "Present"
        {
            $dismParameters = @("/Online", "/Enable-Feature", "/FeatureName:$Name", "/Quiet", "/NoRestart")
            if ($EnableAllParentFeatures) {
                $dismParameters += "/All"
            }
            $dismOutput = & dism.exe $dismParameters
        }
        "Absent"
        {
            $dismParameters = @("/Online", "/Disable-Feature", "/FeatureName:$Name", "/Quiet", "/NoRestart")
            $dismOutput = & dism.exe $dismParameters
        }
    }

    # If exit code is different than 0 (success) and 3010 (restart required), it means dism.exe has failed
    if($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
        throw "dism.exe failed with code $LASTEXITCODE. Output: $dismOutput"
    }

    if(Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
    {
        $global:DSCMachineStatus = 1
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $false)]
        [System.Boolean]
        $EnableAllParentFeatures = $true
    )

    $result = ((Get-TargetResource -Name $Name).Ensure -eq $Ensure)
    
    $result
}


function Get-DismFeatures
{
    $DismGetFeatures = & dism.exe /Online /Get-Features
    $DismFeatures = @{}
    foreach($Line in $DismGetFeatures)
    {
        switch($Line.Split(":")[0].Trim())
        {
            "Feature Name"
            {
                $FeatureName = $Line.Split(":")[1].Trim()
            }
            "State"
            {
                $DismFeatures += @{$FeatureName = $Line.Split(":")[1].Trim()}         
            }
        }
    }

    $DismFeatures
}


Export-ModuleMember -Function *-TargetResource

