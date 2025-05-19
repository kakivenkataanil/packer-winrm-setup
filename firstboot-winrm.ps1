[System.Environment]::SetEnvironmentVariable("TEMP", "C:\Windows\Temp", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("TMP", "C:\Windows\Temp", [System.EnvironmentVariableTarget]::Machine)

$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*packer-winrm*" }
if (-not $cert) {
    $cert = New-SelfSignedCertificate -DnsName "packer-winrm" -CertStoreLocation "Cert:\LocalMachine\My"
}
$thumbprint = $cert.Thumbprint

winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname='packer-winrm';CertificateThumbprint='$thumbprint'}"
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="false"}'

Set-Service WinRM -StartupType Automatic
Start-Service WinRM

New-NetFirewallRule -DisplayName "Allow WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow