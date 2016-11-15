#requires -version 2
<#
.SYNOPSIS
  Creates lots of clones of a specified template

.DESCRIPTION
  Do you have a need for loads of clones from a single template?
  And do you hate clicking around a lot and wish a single script to do the job?
  Well step right up, this script is for you!!!

.PARAMETER <Parameter_Name>
  <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS Server
  Mandatory. The vCenter Server or ESXi Host the script will connect to, in the format of IP address or FQDN.

.INPUTS Username
  Mandatory. The user account used to connect to the vCenter Server. Usually in the form of user.name@domain

.OUTPUTS
  Various tells you it worked!? It's great, you'll see

.NOTES
  Author:         David Comerford
  Last Update:    15-11-2016
  Github:         https://github.com/davidcomerford/vsphere-clone-army

#>

#---------------------------------------------------------[Script Parameters]------------------------------------------------------

param(
  [Parameter(Mandatory=$true, Position=0, HelpMessage="vCenter hostname or IP")][string]$VMServer,
  [Parameter(Mandatory=$true, Position=1, HelpMessage="Username for vCenter")][string]$user
  )

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = 'SilentlyContinue'

#Import Modules & Snap-ins
Add-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Any Global Declarations go here
$dashedline = "---------------------------"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Connect-VMwareServer {
  Param ([Parameter(Mandatory=$true)][string]$VMServer)

  Begin {
    Write-Host "Connecting to VMware environment [$VMServer]..."
  }

  Process {
    Try {
      $passwordin = Read-Host -AsSecureString -Prompt "Enter password for $user@$VMServer"
      $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordin))

      Connect-VIServer -Server $VMServer -User $user -Password $password -WarningAction SilentlyContinue -ErrorAction Stop
    }

    Catch {
      Write-Host -BackgroundColor Red "Error: $($_.Exception)"
      Break
    }
  }

  End {
    If ($?) {
      Write-Host 'Completed Successfully.'
      Write-Host ' '
    }
  }
}


Function GetItem($list) {
    foreach ($item in $list) {
	    Write-Host $list.IndexOf($item): $item
    }
    Write-Host
    $selection = Read-Host "Enter selection"
    return $list[$selection]
}


Function Display-Folders {
    Write-Host $dashedline
    Write-Host "Folders"
    Write-Host $dashedline
    Get-Folder -Type VM | Select Name -ExpandProperty Name
}

Function Get-Least-Busy-VMHost($cluster) {
    Get-VMHost -Location $cluster | Sort-Object CPuUsageMhz | Select -First 1
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Connect-VMwareServer -VMServer $VMServer

# List clusters
Write-Host -ForegroundColor White $dashedline
Write-Host -ForegroundColor White Pick a Cluster 
Write-Host -ForegroundColor White $dashedline

$clusterlist = Get-Cluster
$cluster = GetItem($clusterlist)
Write-Host -ForegroundColor Yellow "Selected: $cluster"


# List datastores in a cluster
Write-Host -ForegroundColor White $dashedline
Write-Host -ForegroundColor White Pick a Datastore
Write-Host -ForegroundColor White $dashedline

$datastorelist = Get-Cluster $cluster | Get-VMHost | Select -first 1 | Get-Datastore | where {$_.Extensiondata.Summary.MultipleHostAccess} 
$datastore = GetItem($datastorelist)
Write-Host -ForegroundColor Yellow "Selected: $datastore"


# List templates in a cluster
Write-Host -ForegroundColor White $dashedline
Write-Host -ForegroundColor White Template to deploy
Write-Host -ForegroundColor White $dashedline

$templatelist = Get-Template
$template = GetItem($templatelist)
Write-Host -ForegroundColor Yellow "Selected: $template"


# List folders for destination
Write-Host -ForegroundColor White $dashedline
Write-Host -ForegroundColor White Destination Folder
Write-Host -ForegroundColor White $dashedline

$folderlist = Get-Folder -Type VM
$folder = GetItem($folderlist)
Write-Host -ForegroundColor Yellow "Selected: $folder"


# Ask for number of VMs to create
Write-Host
$vmcount = Read-Host "How many VMs do you want?"

# Ask for VM name. We'll append a number to it later
Write-Host
$nameprefix = Read-Host "VM name?"

# Ask for starting vM number.
Write-Host
[int]$startnumber = Read-Host "First VM number?"

# Ask if the new VM should be powered on
Write-Host
$poweronafter = Read-Host "Power them on once deployed? [y/n]"


# Summary and confirm
Write-Host
Write-Host -ForegroundColor Green $dashedline
Write-Host -ForegroundColor Green Summary
Write-Host -ForegroundColor Green $dashedline
Write-Host
Write-Host "Cluster: $cluster"
Write-Host "Datastore: $datastore"
Write-Host "Template: $template"
Write-Host "Quantity: $vmcount"
Write-Host "Name: $nameprefix"
Write-Host
Write-Host -ForegroundColor Yellow "Start? [y/n]" -NoNewline

$proceed = Read-Host
  if ($proceed -eq "n") {
    Write-Host "Exiting"
    exit
   }


# Loop and create
$targetnumber = $startnumber+$vmcount

FOR ($i=$startnumber; $i -lt $targetnumber; $i++) {
    #
    $vmnumberpadded = "{0:D2}" -f $i
    
    # New VMs name
    $vmname = "$nameprefix$vmnumberpadded"

    # find the least busy host
    $targetvmhost = Get-Least-Busy-VMHost($cluster)

    # print some stuff
    Write-Host -ForegroundColor Cyan "Creating $vmname on host $targetvmhost..."

    # Create VM
    New-VM -VMHost $targetvmhost -Name $vmname -Datastore $datastore -Location $folder -Template $template 

    IF($poweronafter -eq "y") {
        start-VM -VM $vmname
    }
}

# Disconnect the session
Disconnect-VIServer -Server $VMserver -Confirm:$false -force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
Write-Host
Write-Host "Disconnected from $VMserver"