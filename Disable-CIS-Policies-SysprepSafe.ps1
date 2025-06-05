# Disable Sysprep-blocking CIS policies

Write-Host "🔧 Disabling Sysprep-blocking CIS policies..."

# Disable FIPS Mode
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy" -Name "Enabled" -Value 0 -Force

# Enable RemoteRegistry service
Set-Service -Name "RemoteRegistry" -StartupType Automatic
Start-Service -Name "RemoteRegistry"

# Enable Windows Installer
Set-Service -Name "MSIServer" -StartupType Manual

# Disable ClearPageFileAtShutdown
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "ClearPageFileAtShutdown" -Value 0 -Force

# Set RestrictAnonymous to allow network access
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -Value 0 -Force

# Reactivate Administrator account
net user Administrator /active:yes

Write-Host "✅ Sysprep-safe policy configuration applied."