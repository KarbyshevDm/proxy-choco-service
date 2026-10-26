$ErrorActionPreference = 'Stop'

# Версия пакета (CHOCOLATEY_PACKAGE_VERSION подставляется Chocolatey в момент установки)
$packageVersion = $env:ChocolateyPackageVersion
if ([string]::IsNullOrEmpty($packageVersion)) {
    $packageVersion = $env:CHOCOLATEY_PACKAGE_VERSION
}
if ([string]::IsNullOrEmpty($packageVersion)) {
    throw "Версия пакета не определена (переменная CHOCOLATEY_PACKAGE_VERSION пустая)."
}

# Ссылка на установщик берётся из GitHub Release, тег совпадает с версией пакета (vX.Y.Z)
$repositoryUrl = 'https://github.com/KarbyshevDm/proxy-choco-service'
$tagName       = 'v' + $packageVersion
$url64bit      = "$repositoryUrl/releases/download/$tagName/proxy-choco.exe"

# CHECKSUM подставляется CI при сборке пакета (см. .github/workflows/release.yml).
# Если строка пуста/заглушка - устанавливаем без проверки (не рекомендуется для production).
$checksum     = '__INSTALLER_SHA256__'
$checksumType = 'sha256'

$packageArgs = @{
    packageName    = 'proxy-choco'
    url64bit       = $url64bit
    fileType       = 'EXE'
    softwareName   = 'proxy-choco*'
    silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
    validExitCodes = @(0, 3010)
}

if ($checksum -and $checksum -ne '__INSTALLER_SHA256__') {
    $packageArgs['checksum']       = $checksum
    $packageArgs['checksumType']   = $checksumType
}

Install-ChocolateyPackage @packageArgs
