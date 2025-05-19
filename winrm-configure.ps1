$cert = New-SelfSignedCertificate -DnsName "packer-winrm" -CertStoreLocation Cert:\LocalMachine\My
$thumbprint = $cert.Thumbprint

winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname='packer-winrm';CertificateThumbprint='$thumbprint'}"
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="false"}'

Set-Service WinRM -StartupType Automatic
Start-Service WinRM

New-NetFirewallRule -DisplayName "Allow WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow