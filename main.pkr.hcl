source "azure-arm" "win2022-cis" {
  client_id                    = var.client_id
  client_secret                = var.client_secret
  subscription_id             = var.subscription_id
  tenant_id                   = var.tenant_id

  managed_image_resource_group_name = var.resource_group
  managed_image_name                = "win2022-cis-hardened"

  os_type                   = "Windows"
  image_publisher          = "MicrosoftWindowsServer"
  image_offer              = "WindowsServer"
  image_sku                = "2022-datacenter"
  location                 = var.location
  vm_size                  = "Standard_D2s_v3"

  communicate_via_winrm    = true
  winrm_use_ssl            = true
  winrm_insecure           = true
  winrm_timeout            = "10m"
  winrm_username           = "packer"
  winrm_password           = "P@ckerP@ss123!"
}

build {
  sources = ["source.azure-arm.win2022-cis"]

  provisioner "powershell" {
    scripts = ["winrm-configure.ps1"]
  }

  provisioner "powershell" {
    scripts = ["cis-hardening.ps1"]
  }

  provisioner "powershell" {
    inline = [
      "New-Item -Path C:\\Scripts -ItemType Directory -Force",
      "Copy-Item -Path .\\firstboot-winrm.ps1 -Destination C:\\Scripts\\firstboot-winrm.ps1",

      "$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Bypass -File C:\\Scripts\\firstboot-winrm.ps1'",
      "$trigger = New-ScheduledTaskTrigger -AtStartup",
      "Register-ScheduledTask -TaskName 'ReEnableWinRM' -Action $action -Trigger $trigger -RunLevel Highest -User 'SYSTEM'"
    ]
  }

  provisioner "powershell" {
    inline = [
      "wevtutil sl Microsoft-Windows-WinRM/Operational /e:true",
      "C:\\Windows\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown"
    ]
  }
}