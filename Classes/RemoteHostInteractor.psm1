using module "..\Classes\Logger.psm1"
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version 3.0

class RemoteHostInteractor {
    [AllowNull()][PSCredential]$Credential
    [bool]$UseSSL
    [bool]$IgnoreSSLCert

    [ValidateNotNull()][Logger]$Logger
    [ValidateNotNullOrEmpty()][string]$RemoteHelperFunctionsFileContent
    [ValidateNotNull()][System.Collections.Generic.Dictionary[string, System.Management.Automation.Runspaces.PSSession]] $HostsSessions

    RemoteHostInteractor([PSCustomObject]$config, [Logger]$logger) {
        $this.Credential = $config.Credential
        $this.UseSSL = $config.UseSSL
        $this.IgnoreSSLCert = $config.IgnoreSSLCert

        $this.Logger = $logger
        $this.RemoteHelperFunctionsFileContent = Get-Content "$PSScriptRoot\RemoteHelperFunctions.ps1" -Raw
        $this.HostsSessions = @{}
    }

    [void]ExecuteRemotely([ScriptBlock]$scriptBlock, [object[]]$params, [string[]]$hostNamesList) {
        if ([RemoteHostInteractor]::IsLocalHost($hostNamesList)) {
            $this.Logger.Debug("Executing script block locally params=$([Logger]::DisplayArray($params))")
            $this.Logger.Trace("============================================================={")
            $output = & $scriptBlock @params
            $this.Logger.Trace($output)
        } else {
            $this.Logger.Debug("Executing script block remotely on hosts $([Logger]::DisplayArray($hostNamesList)), params=$([Logger]::DisplayArray($params))")
            $sessions = $this.GetOrCreateSessions($hostNamesList)
            $this.Logger.Trace("============================================================={")
            $output = Invoke-Command -Session $sessions -ScriptBlock $scriptBlock -ArgumentList $params
            $this.Logger.Trace($output)
        }
        $this.Logger.Trace("}=============================================================")
    }

    [void]CopyToRemote([string]$localPath, [string]$toRemotePath, [string[]]$hostNamesList) {
        if ([RemoteHostInteractor]::IsLocalHost($hostNamesList)) {
            $this.Logger.Debug("Copying locally '$localPath' to '$toRemotePath'")
            Copy-Item -Path "$localPath" -Destination "$toRemotePath" -Force -Recurse
        } else {
            $this.Logger.Debug("Copying remotely '$localPath' to '$toRemotePath' on hosts $([Logger]::DisplayArray($hostNamesList))")
            $sessions = $this.GetOrCreateSessions($hostNamesList)
            Copy-Item -ToSession $sessions -Path "$localPath" -Destination "$toRemotePath" -Force -Recurse
        }
    }

    [System.Management.Automation.Runspaces.PSSession[]]GetOrCreateSessions([string[]]$hostNamesList) {
        $this.Logger.Debug("Getting or creating WinRM sessions to $([Logger]::DisplayArray($hostNamesList))")
        $sessions = @()
        foreach ($hostName in $hostNamesList) {
            if ($this.HostsSessions.ContainsKey($hostName)) {
                $this.Logger.Debug("Using existing WinRM session to '$hostName'")
                $sessions += $this.HostsSessions[$hostName]
            } else {
                $this.Logger.Debug("Creating WinRM session to '$hostName'")
                $sessions += $this.CreateSession($hostName)
            }
        }
        return $sessions
    }

    [System.Management.Automation.Runspaces.PSSession]CreateSession([string]$hostName) {
        $params = @{
            ComputerName = $hostName
        }
        if ($null -ne $this.Credential) {
            $this.Logger.Trace("Using credential: UserName='$($this.Credential.UserName)'")
            $params.Credential = $this.Credential
        }
        if ($this.UseSSL) {
            $this.Logger.Trace("Using SSL")
            $params.UseSSL = $true
            if ($this.IgnoreSSLCert) {
                $this.Logger.Trace("Ignoring certificate checks")
                $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
                $params.SessionOption = $sessionOption
            }
        }
        $session = New-PSSession @params

        $this.Logger.Trace("Loading helper functions to created session")
        Invoke-Command -Session $session -ScriptBlock ([ScriptBlock]::Create($this.RemoteHelperFunctionsFileContent))
        $this.HostsSessions.Add($hostName, $session)
        return $session
    }

    [void]CloseConnections() {
        $this.Logger.Debug("Removing existing WinRM sessions")
        $this.HostsSessions.Values | Remove-PSSession
        $this.HostsSessions.Clear()
    }

    static [bool]IsLocalHost([string[]]$hostNamesList) {
        if (($hostNamesList | Measure-Object).Count -eq 1 -and
            $hostNamesList[0] -eq "localhost") {
            return $true
        } else {
            return $false
        }
    }
}
