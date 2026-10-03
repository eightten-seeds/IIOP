$ErrorActionPreference = 'Stop'

$script:IiopRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:IiopLocalConfig = Join-Path $script:IiopRoot 'scripts\dev\local-secrets.ps1'

if (Test-Path -LiteralPath $script:IiopLocalConfig) {
    . $script:IiopLocalConfig
}

function Get-IiopRoot {
    return $script:IiopRoot
}

function Get-IiopRuntimeRoot {
    if ($env:IIOP_RUNTIME_ROOT) {
        if ([System.IO.Path]::IsPathRooted($env:IIOP_RUNTIME_ROOT)) {
            return [System.IO.Path]::GetFullPath($env:IIOP_RUNTIME_ROOT)
        }
        return [System.IO.Path]::GetFullPath((Join-Path $script:IiopRoot $env:IIOP_RUNTIME_ROOT))
    }
    return Join-Path $script:IiopRoot 'runtime-data\dev'
}

function Resolve-IiopExecutable {
    param(
        [string]$ExplicitPath,
        [string[]]$CommandNames = @(),
        [string[]]$Candidates = @()
    )

    if ($ExplicitPath) {
        if (Test-Path -LiteralPath $ExplicitPath) {
            return (Resolve-Path -LiteralPath $ExplicitPath).Path
        }
        throw "Configured executable does not exist: $ExplicitPath"
    }

    foreach ($name in $CommandNames) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Get-IiopJavaExecutable {
    $candidate = $null
    if ($env:JAVA_HOME) {
        $candidate = Join-Path $env:JAVA_HOME 'bin\java.exe'
        if (-not (Test-Path -LiteralPath $candidate)) {
            throw "JAVA_HOME does not contain bin\java.exe: $env:JAVA_HOME"
        }
        return (Resolve-Path -LiteralPath $candidate).Path
    }

    $java = Resolve-IiopExecutable -CommandNames @('java.exe', 'java')
    if (-not $java) {
        throw 'Java was not found. Install JDK 17 and configure JAVA_HOME or PATH.'
    }
    return $java
}

function Get-IiopMavenCommand {
    $maven = Resolve-IiopExecutable -CommandNames @('mvn.cmd', 'mvn')
    if (-not $maven) {
        throw 'Maven was not found. Install Maven and add mvn to PATH.'
    }
    return $maven
}

function Get-IiopNpmCommand {
    $npm = Resolve-IiopExecutable -CommandNames @('npm.cmd', 'npm')
    if (-not $npm) {
        throw 'npm was not found. Install Node.js and add npm to PATH.'
    }
    return $npm
}
