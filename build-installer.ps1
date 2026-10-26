#Requires -Version 5.1
<#
.SYNOPSIS
    Automated Inno Setup installer build (local equivalent of .github/workflows/build-installer.yml).

.DESCRIPTION
    Steps:
      1. Check dotnet SDK and Inno Setup 6 (ISCC.exe)
      2. dotnet build (Release)
      3. dotnet publish service + CLI to .\publish\bin (SingleFile, SelfContained)
      4. Compile Setup/setup.iss with /D parameters
      5. Verify Installer\proxy-choco.exe

    ISCC.exe path is auto-detected; override with -IsccPath or $env:INNO_SETUP_PATH.

.EXAMPLE
    .\build-installer.ps1 -Version 1.2.3

.EXAMPLE
    .\build-installer.ps1                  # default version: 0.0.1
#>
[CmdletBinding()]
param(
    [string]$Version = "0.0.1",
    [string]$Name = "proxy-choco",
    [string]$Configuration = "Release",
    [string]$IsccPath = $env:INNO_SETUP_PATH,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
Set-Location $Root

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Invoke-Step {
    param([string]$StepName, [scriptblock]$Action)
    Write-Step $StepName
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Action
    $sw.Stop()
    Write-Host ("    done in {0:N1}s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor DarkGray
}

# --- 0. Validate version --------------------------------------------------
if ($Version -notmatch '^\d+\.\d+\.\d+') {
    throw "Invalid version '$Version'. Expected semver like 1.2.3"
}

# --- 1. Locate toolchain ----------------------------------------------------
Invoke-Step "Locate dotnet SDK and Inno Setup" {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw "dotnet SDK not found in PATH."
    }
    Write-Host ("    dotnet : {0}" -f ((Get-Command dotnet).Source))

    if (-not $IsccPath) {
        $candidates = @(
            "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
            "C:\Program Files\Inno Setup 6\ISCC.exe"
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { Set-Variable -Name IsccPath -Value $c -Scope Script; break }
        }
    }

    if (-not $IsccPath -or -not (Test-Path $IsccPath)) {
        throw "ISCC.exe (Inno Setup 6) not found. Install with: choco install innosetup -y, or pass -IsccPath / INNO_SETUP_PATH."
    }
    Write-Host ("    ISCC   : {0}" -f $IsccPath)
}

# --- 2. Build + publish -----------------------------------------------------
if (-not $SkipBuild) {
    Invoke-Step "dotnet build (solution)" {
        dotnet build PseudoConsoleGrpcService.sln -p:Configuration=$Configuration -v q
        if ($LASTEXITCODE -ne 0) { throw "dotnet build failed with code $LASTEXITCODE" }
    }

    Invoke-Step "dotnet publish (service + CLI -> publish/bin)" {
        $publishDir = Join-Path $Root "publish/bin"
        dotnet publish (Join-Path $Root "ProxyChocoGrpcService/ProxyChocoGrpcService.csproj") `
            -p:Configuration=$Configuration `
            -p:PublishSingleFile=true `
            -p:SelfContained=true `
            --output $publishDir
        if ($LASTEXITCODE -ne 0) { throw "publish ProxyChocoGrpcService failed with code $LASTEXITCODE" }

        dotnet publish (Join-Path $Root "ConsoleApp/ConsoleApp.csproj") `
            -p:Configuration=$Configuration `
            -p:PublishSingleFile=true `
            -p:SelfContained=true `
            --output $publishDir
        if ($LASTEXITCODE -ne 0) { throw "publish ConsoleApp failed with code $LASTEXITCODE" }

        foreach ($f in @("appsettings.json", "ProxyChocoGrpcService.exe", "$Name.exe")) {
            $p = Join-Path $publishDir $f
            if (-not (Test-Path $p)) { throw "Required file missing in publish/bin: $f" }
        }
        Write-Host "    publish/bin ready: appsettings.json, ProxyChocoGrpcService.exe, $Name.exe"
    }
}

# --- 3. Compile Inno Setup installer ---------------------------------------
$installerDir   = Join-Path $Root "Installer"
$sourceFilesDir = Join-Path $Root "publish/bin"
$setupIss       = Join-Path $Root "Setup/setup.iss"

Invoke-Step "Compile Inno Setup installer" {
    if (-not (Test-Path $sourceFilesDir)) {
        throw "publish/bin not found: $sourceFilesDir (was -SkipBuild used?)"
    }

    & $IsccPath $setupIss `
        "/DName=$Name" `
        "/DOutputFileName=$Name" `
        "/DVersion=$Version" `
        "/DOutputDirectory=$installerDir" `
        "/DSourceFilesDirectory=$sourceFilesDir"

    if ($LASTEXITCODE -ne 0) { throw "ISCC failed with code $LASTEXITCODE" }
}

# --- 4. Verify result ---------------------------------------------------------
$installerExe = Join-Path $installerDir "$Name.exe"
if (-not (Test-Path $installerExe)) {
    throw "Installer not found: $installerExe"
}

$item = Get-Item $installerExe
Write-Host ""
Write-Host "INSTALLER READY" -ForegroundColor Green
Write-Host ("    File    : {0}" -f $item.FullName)
Write-Host ("    Size    : {0:N0} bytes ({1:N1} MB)" -f $item.Length, ($item.Length / 1MB))
Write-Host ("    Built   : {0}" -f $item.LastWriteTime)
