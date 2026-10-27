$ErrorActionPreference = 'Stop'

# Версия пакета (Chocolatey подставляет CHOCOLATEY_PACKAGE_VERSION в момент установки)
$packageVersion = $env:CHOCOLATEY_PACKAGE_VERSION
if ([string]::IsNullOrEmpty($packageVersion)) {
    throw "Версия пакета не определена (переменная CHOCOLATEY_PACKAGE_VERSION пустая)."
}

# Ссылка на установщик берётся из GitHub Release, тег совпадает с версией пакета (vX.Y.Z)
$repositoryUrl = 'https://github.com/KarbyshevDm/proxy-choco-service'
$tagName       = 'v' + $packageVersion
$url64bit      = "$repositoryUrl/releases/download/$tagName/proxy-choco.exe"

# $checksum подставляется CI при сборке пакета (см. .github/workflows/release.yml):
# строка выше заменяется на строку с реальным SHA256 установщика.
# Chocolatey требует проверку чексума при скачивании удалённого файла,
# поэтому в опубликованном .nupkg переменная $checksum всегда содержит
# реальный хеш — это гарантируется проверкой в CI (Fail if placeholder remains).
$checksum     = '__INSTALLER_SHA256__'
$checksumType = 'sha256'

$packageArgs = @{
    packageName    = 'proxy-choco'
    url64bit       = $url64bit
    fileType       = 'EXE'
    softwareName   = 'proxy-choco*'
    silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
    validExitCodes = @(0, 3010)
    checksum       = $checksum
    checksumType   = $checksumType
}

Install-ChocolateyPackage @packageArgs
