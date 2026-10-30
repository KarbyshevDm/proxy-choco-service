$ErrorActionPreference = 'Stop'


$packageVersion = $env:ChocolateyPackageVersion


$repositoryUrl = 'https://github.com/KarbyshevDm/proxy-choco-service'
$tagName       = 'v' + $packageVersion
$url           = "$repositoryUrl/releases/download/$tagName/proxy-choco.exe"


$checksum     = '__INSTALLER_SHA256__'
$checksumType = 'sha256'

$packageArgs = @{
    packageName    = 'proxy-choco'
    url            = $url
    fileType       = 'EXE'
    softwareName   = 'proxy-choco*'
    silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
    validExitCodes = @(0, 3010)
    checksum       = $checksum
    checksumType   = $checksumType
}

Install-ChocolateyPackage @packageArgs

