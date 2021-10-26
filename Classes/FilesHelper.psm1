using module "..\Classes\Logger.psm1"
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version 3.0

class FilesHelper {
    [ValidateNotNull()][Logger]$Logger

    FilesHelper([Logger]$logger) {
        $this.Logger = $logger
    }

    [void]EnsureExists([string]$path) {
        $this.Logger.Trace("Ensuring that path '$path' exists")
        if (-not (Test-Path -Path $path)) {
            throw "Path '$path' doesn't exist"
        }
    }

    [void]CreateDirIfNotExists([string]$path) {
        if (-not (Test-Path -Path $path)) {
            $this.Logger.Trace("Creating directory '$path'")
            New-Item -ItemType Directory -Path $path -Force
        }
    }
    [void]DeleteIfExists([string]$path) {
        if (Test-Path -Path $path) {
            $this.Logger.Trace("Deleting '$path'")
            Remove-Item -Recurse -Force $path
        }
    }

    [void]CopyToDir([string]$path, [string]$toDir) {
        if (Test-Path -Path $path) {
            $this.Logger.Trace("Copying '$path' to directory '$toDir'")
            $this.CreateDirIfNotExists($toDir)
            Copy-Item -Path $path -Destination $toDir -Force -Recurse
        } else {
            throw "Path '$path' not found during copy"
        }
    }

    [void]CopyIfExistsToDir([string]$path, [string]$toDir) {
        if (Test-Path -Path $path) {
            $this.Logger.Trace("Copying if exists '$path' to directory '$toDir'")
            $this.CreateDirIfNotExists($toDir)
            Copy-Item -Path $path -Destination $toDir -Force -Recurse
        } else {
            $this.Logger.Trace("Path '$path' not found during copy")
        }
    }

    [void]CopyFileToPath([string]$filePath, [string]$toPath) {
        if (Test-Path -Path $toPath -PathType Container) {
            throw "Copy file target path '$toPath' already exists and it's a directory"
        }

        if (Test-Path -Path $filePath) {
            $this.Logger.Trace("Copying file '$filePath' to path '$toPath'")
            $this.CreateDirIfNotExists((Split-Path -Path $toPath -Parent))
            Copy-Item -Path $filePath -Destination $toPath -Force
        } else {
            throw "File path '$filePath' not found during copy"
        }
    }
}
