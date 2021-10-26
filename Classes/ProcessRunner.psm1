using module "..\Classes\Logger.psm1"
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version 3.0

class ProcessRunner {
    [ValidateNotNull()][Logger]$Logger

    ProcessRunner([Logger]$logger) {
        $this.Logger = $logger
    }

    [string]ExecuteProcess([string]$processPath, [string[]]$arguments, [int]$timeout) {
        $this.Logger.Debug("Executing process='$processPath', arguments=$([Logger]::DisplayArray($arguments)), timeout='$timeout'")

        $procinfo = New-Object System.Diagnostics.ProcessStartInfo
        $procinfo.FileName = $processPath
        $procinfo.RedirectStandardError = $true
        $procinfo.RedirectStandardOutput = $true
        $procinfo.UseShellExecute = $false
        $procinfo.Arguments = $arguments
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $procinfo

        $output = $this.ExecuteProcessReadingOutput($proc, $timeout)
        $this.Logger.Debug("ExitCode='$($proc.ExitCode)'")
        if ($proc.ExitCode -ne 0) {
            $this.Logger.Error("Total ProcessRunner output:`n$output")
            throw "ExecuteProcess failed: ExitCode='$($proc.ExitCode)'"
        }
        return $output
    }

    [string]ExecuteProcessReadingOutput([System.Diagnostics.Process]$proc, [int]$timeout) {
        $scopeRef = [PSCustomObject]@{
            Output = New-Object -TypeName System.Text.StringBuilder
            Logger = $this.Logger
        }
        $outputReceived = {
            if (![String]::IsNullOrEmpty($EventArgs.Data)) {
                $trimmedData = [ProcessRunner]::TrimOutput($EventArgs.Data)
                $Event.MessageData.Output.AppendLine($trimmedData)
                $Event.MessageData.Logger.Trace("ProcessRunner: $trimmedData")
            }
        }
        $outEvent = Register-ObjectEvent -InputObject $proc `
            -Action $outputReceived -EventName 'OutputDataReceived' `
            -MessageData $scopeRef
        $errEvent = Register-ObjectEvent -InputObject $proc `
            -Action $outputReceived -EventName 'ErrorDataReceived' `
            -MessageData $scopeRef

        $proc.Start() | Out-Null
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        if ($timeout -le 0) { $timeout = [int]::MaxValue }
        $timedOut = $false
        $counter = 0
        while (($counter -lt $timeout) -and (!$proc.HasExited)) {
            Start-Sleep -Seconds 1
            $counter++
        }
        if (!$proc.HasExited) {
            $proc.Kill()
            $timedOut = $true
            $this.Logger.Error("Total ProcessRunner output:`n$([ProcessRunner]::TrimOutput($scopeRef.Output.ToString()))")
        }

        Unregister-Event -SourceIdentifier $outEvent.Name
        Unregister-Event -SourceIdentifier $errEvent.Name

        if ($timedOut) {
            throw "Process exceeded timeout ($($timeout)s)."
        } else {
            return [ProcessRunner]::TrimOutput($scopeRef.Output.ToString())
        }
    }

    static [string]TrimOutput([string]$output) {
        return $output.ToString() -Replace '^\s*', '' -Replace '\s*$', ''
    }
}