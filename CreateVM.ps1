param (
    [string]$ResourceGroup      = "my-rg",
    [string]$Location           = "eastus",
    [string]$VmName             = "Win2025-CIS-VM",
    [string]$GalleryName        = "myImageGallery",
    [string]$ImageDefinition    = "win2025-cis",
    [string]$ImageVersion       = "1.0.0",
    [string]$VnetName           = "myVnet",
    [string]$SubnetName         = "default",
    [string]$AdminUsername      = "azureuser",
    [string]$AdminPassword      = "P@ssw0rd123!",  # ❗ Replace securely
    [string]$VmSize             = "Standard_D2s_v3"
)

# Get VNet & Subnet
$vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroup
$subnet = $vnet.Subnets | Where-Object { $_.Name -eq $SubnetName }

# Create NIC
$nic = New-AzNetworkInterface -Name \"${VmName}-nic\" `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -IpConfigurationName \"ipconfig1\" `
    -SubnetId $subnet.Id

# Get SIG Image
$image = Get-AzGalleryImageVersion -ResourceGroupName $ResourceGroup `
    -GalleryName $GalleryName `
    -GalleryImageDefinitionName $ImageDefinition `
    -GalleryImageVersionName $ImageVersion

# Credentials
$securePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($AdminUsername, $securePassword)

# VM Configuration
$vmConfig = New-AzVMConfig -VMName $VmName -VMSize $VmSize | 
    Set-AzVMOperatingSystem -Windows -ComputerName $VmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate |
    Set-AzVMSourceImage -Id $image.Id |
    Add-AzVMNetworkInterface -Id $nic.Id

# Create the VM
New-AzVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vmConfig
