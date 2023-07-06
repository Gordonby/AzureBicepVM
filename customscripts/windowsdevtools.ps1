Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install azcopy -y
choco install vscode -y
choco install pwsh -y
choco install azure-cli -y
choco install kubernetes-cli -y
choco install git -y
choco install kubernetes-helm -y
