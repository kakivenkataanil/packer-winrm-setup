// Packer template to create a Windows Server 2022 image in Azure with WinRM and RDP enabled for debugging

variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}
variable "resource_group" {}
variable "location" {}
variable "gallery_name" {}
variable "image_definition" {}

source "azure-arm" "win2022" {
  client_id            = var.client_id
  client_secret        = var.client_secret
  tenant_id            = var.tenant_id
  subscription_id      = var.subscription_id

  managed_image_name   = "win2022-debug"
  managed_image_resource_group_name = var.resource_group

  os_type              = "Windows"
  image_publisher      = "MicrosoftWindowsServer"
  image_offer          = "WindowsServer"
  image_sku            = "2022-Datacenter"
  location             = var.location
  vm_size              = "Standard_D2s_v3"

  communicator         = "winrm"
  winrm_use_ssl        = true
  winrm_insecure       = true
  winrm_use_ntlm       = true
  winrm_username       = "packer"
  winrm_password       = "P@ssw0rd1234!"

  azure_tags = {
    environment = "packer"
  }
}

build {
  sources = ["source.azure-arm.win2022"]

  provisioner "powershell" {
    inline = [
      "[Environment]::SetEnvironmentVariable('TEMP', 'C:\\Windows\\Temp', 'Machine')",
      "[Environment]::SetEnvironmentVariable('TMP', 'C:\\Windows\\Temp', 'Machine')"
    ]
  }

  provisioner "powershell" {
    inline = [
      "winrm quickconfig -quiet",
      "winrm set winrm/config/service/auth @{Basic=\"true\"}",
      "winrm set winrm/config/service @{AllowUnencrypted=\"false\"}",
      "$cert = New-SelfSignedCertificate -DnsName 'localhost' -CertStoreLocation 'cert:\\LocalMachine\\My'",
      "$thumb = $cert.Thumbprint",
      "if ((winrm enumerate winrm/config/listener | findstr HTTPS) -ne $null) { winrm delete winrm/config/Listener?Address=*+Transport=HTTPS }",
      "winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=\"localhost\"; CertificateThumbprint=\"$thumb\"}"
    ]
  }

  provisioner "powershell" {
    inline = [
      "# Enable RDP",
      "Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0",
      "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"
    ]
  }

  provisioner "powershell" {
    inline = [
      "# Open WinRM HTTPS port",
      "New-NetFirewallRule -Name 'WinRM HTTPS' -DisplayName 'WinRM HTTPS' -Enabled True -Protocol TCP -LocalPort 5986 -Action Allow"
    ]
  }

  provisioner "powershell" {
    inline = [
      "Write-Host 'You can now connect to the VM using WinRM or RDP with the username packer and password.'"
    ]
  }

  provisioner "powershell" {
    inline = [
      "& C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown"
    ]
  }

  post-processor "azure-arm" {
    inline = [
      "az sig image-version create --resource-group ${var.resource_group} \\",
      "  --gallery-name ${var.gallery_name} --gallery-image-definition ${var.image_definition} \\",
      "  --gallery-image-version 1.0.0 --managed-image win2022-debug --location ${var.location} --replica-count 1"
    ]
  }
}
