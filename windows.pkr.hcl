// Packer template to create a Windows Server 2022 image in Azure using WinRM and Shared Image Gallery (SIG)

variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}
variable "resource_group" {}
variable "location" {}
variable "gallery_name" {}
variable "image_definition" {}
variable "image_version" { default = "1.0.0" }

source "azure-arm" "win2022" {
  client_id            = var.client_id
  client_secret        = var.client_secret
  tenant_id            = var.tenant_id
  subscription_id      = var.subscription_id

  os_type              = "Windows"
  image_publisher      = "MicrosoftWindowsServer"
  image_offer          = "WindowsServer"
  image_sku            = "2022-Datacenter"
  location             = var.location
  vm_size              = "Standard_D2s_v3"

  communicator         = "winrm"
  winrm_use_ssl        = true
  winrm_insecure       = true
  winrm_username       = "packer"
  winrm_password       = "P@ssw0rd1234!"

  winrm_timeout        = "30m"
  winrm_use_ntlm       = true

  azure_tags = {
    environment = "packer"
  }

  shared_image_gallery_name        = var.gallery_name
  shared_image_gallery_image_definition = var.image_definition
  shared_image_gallery_image_version    = var.image_version
  shared_image_gallery_destination      = {
    resource_group = var.resource_group
    location       = var.location
    replication_regions = [ var.location ]
  }
}

build {
  sources = ["source.azure-arm.win2022"]

  # Pre-run script to configure WinRM on guest VM
  provisioner "powershell" {
    inline = [
      "winrm quickconfig -quiet",
      "Set-Item -Path WSMan:\\localhost\\Service\\AllowUnencrypted -Value $false",
      "Set-Item -Path WSMan:\\localhost\\Service\\Auth\\Basic -Value $true",
      "$cert = New-SelfSignedCertificate -DnsName 'packerhost' -CertStoreLocation Cert:\\LocalMachine\\My",
      "New-Item -Path WSMan:\\Localhost\\Listener -Transport HTTPS -Address * -CertificateThumbprint $cert.Thumbprint -Force",
      "Set-Item WSMan:\\localhost\\Client\\TrustedHosts -Value '*' -Force",
      "Enable-PSRemoting -Force",
      "New-NetFirewallRule -DisplayName 'WinRM HTTPS' -Name 'WinRMHTTPS' -Protocol TCP -LocalPort 5986 -Action Allow"
    ]
  }

  # Setup system prior to hardening
  provisioner "powershell" {
    elevated_user     = "packer"
    elevated_password = "P@ssw0rd1234!"
    inline = [
      "New-Item -Path C:\\Temp -ItemType Directory -Force",
      "[Environment]::SetEnvironmentVariable('TEMP', 'C:\\Temp', 'Machine')",
      "[Environment]::SetEnvironmentVariable('TMP', 'C:\\Temp', 'Machine')",

      "Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0",
      "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"
    ]
  }

  # Delay CIS Hardening to the end
  provisioner "powershell" {
    elevated_user     = "packer"
    elevated_password = "P@ssw0rd1234!"
    inline = [
      "Write-Host '--- BEGIN: Apply CIS Hardening ---'",
      "# Insert your CIS script or command here, e.g.:",
      "# & C:\\Tools\\Apply-CIS.ps1",
      "Write-Host '--- END: Apply CIS Hardening ---'"
    ]
  }

  # Final step: run Sysprep to generalize and shut down
  provisioner "powershell" {
    elevated_user     = "packer"
    elevated_password = "P@ssw0rd1234!"
    inline = [
      "Start-Process -FilePath 'C:\\Windows\\System32\\Sysprep\\Sysprep.exe' -ArgumentList '/oobe /generalize /shutdown /quiet' -Wait"
    ]
  }
}  
