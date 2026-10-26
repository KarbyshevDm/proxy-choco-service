$ErrorActionPreference = 'SilentlyContinue'

# Останавливаем службу до обновления/удаления, чтобы файлы не были заняты
Stop-Service -Name 'ProxyChocoService' -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Stop-Process -Name 'ProxyChocoGrpcService' -Force -ErrorAction SilentlyContinue
Stop-Process -Name 'proxy-choco' -Force -ErrorAction SilentlyContinue
