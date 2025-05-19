# Example minimal hardening (extend as needed)
Net User Guest /active:no
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

# Avoid breaking WinRM
Set-Service WinRM -StartupType Automatic
winrm set winrm/config/service/auth '@{Basic="true"}'
Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM" -Recurse -ErrorAction SilentlyContinue