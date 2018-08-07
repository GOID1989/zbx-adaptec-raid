<#
    .SYNOPSIS
    Script with LLD support for getting data from Adaptec RAID Controller to Zabbix monitoring system.

    .DESCRIPTION
    The script may generate LLD data for Adaptec RAID Controllers, Logical Drives, Physical Drives.

    .NOTES
    Author: GOID1989
    Github: https://github.com/GOID1989/zbx-adaptec-raid
#>

Param (
[switch]$version = $false,
[ValidateSet("lld","health")][Parameter(Position=0, Mandatory=$True)][string]$action,
[ValidateSet("ad","ld","pd")][Parameter(Position=1, Mandatory=$True)][string]$part,
[string][Parameter(Position=2)]$ctrlid,
[string][Parameter(Position=3)]$partid
)

$cli = "C:\Program Files\Adaptec\Adaptec Storage Manager\arcconf.exe"

function LLDControllers()
{
    $response = & $cli "GETVERSION".Split() | Where-Object {$_ -match "^Controllers found"}
    $ctrl_count = ($response -replace 'Controllers found: ','').Trim()

    for($i = 1; $i -le $ctrl_count; $i++ ){
        [array]$response = & $cli "GETCONFIG $i AD".Split()

        $ctrl_model = (($response[6] -split ':')[1]).Trim()
        $ctrl_sn = (($response[7] -split ':')[1]).Trim()

        $ctrl_info = [string]::Format('{{"{{#CTRL.ID}}":"{0}","{{#CTRL.MODEL}}":"{1}","{{#CTRL.SN}}":"{2}"}},',$i,$ctrl_model, $ctrl_sn)
        $ctrl_json += $ctrl_info
    }

    $lld_data = '{"data":[' + $($ctrl_json -replace ',$') + ']}'
    return $lld_data
}

function LLDLogicalDrives()
{
    $response = & $cli "GETVERSION".Split() | Where-Object {$_ -match "^Controllers found"}
    $ctrl_count = ($response -replace 'Controllers found: ','').Trim()

    for($i = 1; $i -le $ctrl_count; $i++ ){
        $response = & $cli "GETCONFIG $i ad".Split() | Where-Object {$_ -match "Logical devices/Failed/Degraded"}
        $res = $response -match '[:\s](\d+)'
        $ld_count = $Matches[1]

        #Get IDs of logical devices
        [array]$response = & $cli "GETCONFIG $i ld".Split() | Where-Object {$_ -match "Logical device number"}

        foreach($logical_dev in $response){
            $res = ($logical_dev -match '\d+$')
            $ld_id = $Matches[0]

            [array]$response = & $cli "GETCONFIG $i ld $ld_id".Split() | Where-Object {$_ -match "Logical device name|RAID level"}

            $ld_name = ($response[0] -split ':')[1].Trim()
            $ld_raid = ($response[1] -split ':')[1].Trim()

            # If name of LD not set
            if($ld_name -eq "") { $ld_name = $ld_id }

            $ld_info = [string]::Format('{{"{{#CTRL.ID}}":"{0}","{{#LD.ID}}":"{1}","{{#LD.NAME}}":"{2}","{{#LD.RAID}}":"{3}"}},',$i,$ld_id, $ld_name,$ld_raid)
            $ld_json += $ld_info
        }
    }

    $lld_data = '{"data":[' + $($ld_json -replace ',$') + ']}'
    return $lld_data
}

function LLDPhysicalDrives()
{
    $response = & $cli "GETVERSION".Split() | Where-Object {$_ -match "^Controllers found"}
    $ctrl_count = ($response -replace 'Controllers found: ','').Trim()

    for($i = 1; $i -le $ctrl_count; $i++ ){
        [array]$response = & $cli "GETCONFIG $i pd".Split() | Where-Object {$_ -match "Device\s[#]\d+|Device is "}

        for($j = 0; $j -lt $response.Length;){
            if($response[$j+1] -match "Hard drive"){
                $pd_id = ($response[$j] -replace "Device #").Trim()

                $pd_info = [string]::Format('{{"{{#CTRL.ID}}":"{0}","{{#PD.ID}}":"{1}"}},',$i,$pd_id)
                $pd_json += $pd_info
            }
            $j = $j + 2
        }
    }
    $lld_data = '{"data":[' + $($pd_json -replace ',$') + ']}'
    return $lld_data
}

function GetControllerStatus()
{
    $response = & $cli "GETCONFIG $ctrlid ad".Split() | Where-Object {$_ -match "Controller Status"}
    $ctrl_status = ($response -split ':')[1].Trim()

    # Exctract Celsius value
        #$res = $response[9] -match '(\d+).*[C]'
        #$ctrl_temperature = $Matches[1]

    return $ctrl_status
}

function GetLogicalDriveStatus()
{
    $response = & $cli "GETCONFIG $ctrlid ld $partid".Split() | Where-Object {$_ -match "Status of logical device"}
    $ld_status = ($response -split ':')[1].Trim()
    return $ld_status
}

function GetPhysicalDriveStatus()
{
    [array]$response = & $cli "GETCONFIG $ctrlid pd".Split() | Where-Object {$_ -match "^\s+State\s+[:] "}

    $pd_status = ($response[$partid] -split ':')[1].Trim()
    return $pd_status
}

switch($action){
    "lld" {
        switch($part){
            "ad" { write-host $(LLDControllers) }
            "ld" { write-host $(LLDLogicalDrives)}
            "pd" { write-host $(LLDPhysicalDrives)}
        }
    }
    "health" {
        switch($part) {
            "ad" { write-host $(GetControllerStatus) }
            "ld" { write-host $(GetLogicalDriveStatus)}
            "pd" { write-host $(GetPhysicalDriveStatus)  }
        }
    }
    default {Write-Host "ERROR: Wrong argument: use 'lld' or 'health'"}
}
