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
  Version:        1.0
  Author:         David Comerford
  Creation Date:  12-10-2016
  Purpose/Change: Initial script development

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
Add-PSSnapin VMware.VimAutomation.Core -WarningAction SilentlyContinue

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

Function Display-Clusters {
    Write-Host $dashedline
    Write-Host "Clusters"
    Write-Host $dashedline
    Get-Cluster | Select Name -ExpandProperty Name
}

Function Display-Datastores($cluster) {
    Write-Host $dashedline
    Write-Host "Datastores"
    Write-Host $dashedline
    Get-Datastore -Location $cluster | where {$_.Extensiondata.Summary.MultipleHostAccess} | Select Name
}

Function Display-Templates($cluster) {
    Write-Host $dashedline
    Write-Host "Templates"
    Write-Host $dashedline
    Get-Template -Location $cluster | Select Name -ExpandProperty Name
    
}

Function Display-Folders {
    Write-Host $dashedline
    Write-Host "Folders"
    Write-Host $dashedline
    Get-Folder -Type VM | Select Name -ExpandProperty Name
}

Function Get-Least-Busy-VMHost($cluster) {
    Get-VMHost -Location $cluster | Sort $_.CPuUsageMhz -Descending | Select -First 1
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Connect-VMwareServer -VMServer $VMServer

# List clusters
Display-Clusters
Write-Host
$cluster = Read-Host "Which cluster will we deploy to?"

# List datastores in a cluster
Write-Host
Display-Datastores($cluster)
Write-Host
$datastore = Read-Host "Which datastore will we use?"

# List templates in a cluster
Write-Host
Display-Templates($cluster)
Write-Host
$template = Read-Host "Which template will we use?"

# List folders for destination
Write-Host
Display-Folders
Write-Host
$folder = Read-Host "Which folder will I deploy into?"

# Ask for number of VMs to create
Write-Host 
Write-Host
$vmcount = Read-Host "How many VMs do you want?"

# Ask for VM name. We'll append a number to it later
Write-Host
$nameprefix = Read-Host "VM name?"


# Summary and confirm
Write-Host
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
FOR ($i=1; $i -le $vmcount; $i++) {
    
    # find the least busy host
    $targetvmhost = Get-Least-Busy-VMHost($cluster)

    # print some stuff
    Write-Host -ForegroundColor Cyan "Creating $nameprefix$i on host $targetvmhost..."

    # Create VM
    New-VM -VMHost $targetvmhost -Name $nameprefix$i -Datastore $datastore -Location $folder -Template $template | Out-Null
}

# Disconnect the session
Disconnect-VIServer -Server $VMserver -Confirm:$false -force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
Write-Host
Write-Host "Disconnected from $Server"