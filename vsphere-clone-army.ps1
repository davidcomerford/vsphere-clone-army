﻿#requires -version 2
<#
.SYNOPSIS
  Creates lots of clones of a specified template

.DESCRIPTION
  <Brief description of script>

.PARAMETER <Parameter_Name>
  <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS Server
  Mandatory. The vCenter Server or ESXi Host the script will connect to, in the format of IP address or FQDN.

.INPUTS Credentials
  Mandatory. The user account credendials used to connect to the vCenter Server of ESXi Host.

.OUTPUTS
  <Outputs if any, otherwise state None>

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

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Connect-VMwareServer {
  Param ([Parameter(Mandatory=$true)][string]$VMServer)

  Begin {
    Write-Host "Connecting to VMware environment [$VMServer]..."
  }

  Process {
    Try {
      #$oCred = Get-Credential -Message 'Enter credentials to connect to vSphere Server or Host
      $passwordin = Read-Host -AsSecureString -Prompt "Enter password for $user@$vcenter"
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
    Write-Host "Clusters"
    Get-Cluster | Select Name -ExpandProperty Name
}

Function Display-Datastores($cluster) {
    Write-Host "Datastores"
    Get-Datastore -Location $cluster | where {$_.Extensiondata.Summary.MultipleHostAccess} | Select Name -ExpandProperty Name
}

Function Display-Templates($cluster) {
    Write-Host "Templates"
    Get-Template -Location $cluster | Select Name -ExpandProperty Name
    
}
<#
Function <FunctionName> {
  Param ()
  Begin {
    Write-Host '<description of what is going on>...'
  }
  Process {
    Try {
      <code goes here>
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
#>

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Connect-VMwareServer -VMServer $Server

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


# Ask for number of VMs to create
Write-Host 
Write-Host
$vmcount = Read-Host "How many VMs do you want?"

# Ask for VM name. We'll append a number to it later
Write-Host
$nameprefix = Read-Host "VM name?"

# Loop and create
FOR ($i=1; $i -le $vmcount; $i++) {
    Write-Host $nameprefix$i
}


# Disconnect the session
Disconnect-VIServer -Server $VMserver -Confirm:$false -force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
Write-Host
Write-Host "Disconnected from $Server"