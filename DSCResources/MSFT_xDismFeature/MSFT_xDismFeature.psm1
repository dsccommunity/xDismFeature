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
        [System.String]
        $Source
    )
    #Changing the state so delete the cache file as it will no longer be valid.
    Remove-DismFeaturesCache
    switch($Ensure)
    {
        "Present"
        {
            $dismParameters = @("/Online", "/Enable-Feature", "/FeatureName:$Name", "/Quiet", "/NoRestart")

            # Include sources directory if present
            if ($Source)
            {
                Write-Verbose "Source location set: ${Source}"

                $dismParameters += "/Source:${Source}"
                $dismParameters += "/LimitAccess"
            }

            & dism.exe $dismParameters
        }
        "Absent"
        {
            & dism.exe /Online /Disable-Feature /FeatureName:$Name /quiet /norestart
        }
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
        [System.String]
        $Source = $null
    )

    $result = ((Get-TargetResource -Name $Name).Ensure -eq $Ensure)
    
    $result
}


function Remove-DismFeaturesCache
{
    param([switch]$TidyUp)
    $CacheDirectory = $env:TEMP
    Get-ChildItem $env:Temp -Filter "xDismFeatures-Cache-$PID.json" | Remove-Item
    if($TidyUp){
        Get-ChildItem $env:TEMP -Filter "xDismFeatures-Cache-*.json" | Remove-Item
    }
}

function Get-DismFeatures
{
    # Takes between 1 and 10 seconds and a lot of disk IO to generate the list.
    # Therefore makes sense to cache it for a short time.
    # Have to use a temp file as PoSH variables don't persist.
    $DismCacheFilePath = "$env:TEMP\xDismFeatures-Cache-$PID.json"
    $DismFeatures = &{
        $ErrorActionPreference = "SilentlyContinue"
        if((Get-Item $DismCacheFilePath).LastWriteTimeUtc -lt [DateTime]::UtcNow.AddMinutes(-5)){
            Remove-Item $DismCacheFilePath 2>$null
        }
        Get-Content $DismCacheFilePath 2>$null | ConvertFrom-Json 2>$null
    }
    if($DismFeatures){
        Write-Verbose "Using cached DISM data"
        return $DismFeatures
    }
    Write-Verbose "Querying DISM..."

    Remove-DismFeaturesCache -TidyUp

    $DismGetFeatures = & dism.exe /Online /Get-Features
    $DismFeatures = @{}
    foreach($Line in $DismGetFeatures)
    {
        switch($Line.Split(":")[0].Trim())
        {
            "Error"
            {
                Throw "Dism.exe $Line"
            }
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
    $DismFeatures | ConvertTo-Json > $DismCacheFilePath
    Write-Verbose "Caching DISM data in $DismCacheFilePath"

    # This is to ensure that all runs get the same format.
    return ($DismFeatures | ConvertTo-Json | ConvertFrom-Json)
}


Export-ModuleMember -Function *-TargetResource

