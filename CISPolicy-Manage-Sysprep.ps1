$logRoot = "C:\Packer"
$logFile = "$logRoot\CIS_Sysprep_Debug.log"
$lgpoBackupPath = "$logRoot\LGPO_Backup"

# Ensure log directory exists
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
"==== CIS Sysprep Preparation Log: $(Get-Date) ====" | Out-File $logFile

function Log {
    param ($msg)
    Write-Host $msg
    $msg | Out-File -FilePath $logFile -Append
}

Log "`n[INFO] Backing up current LGPO settings..."
& "$env:windir\System32\LGPO.exe" /b $lgpoBackupPath

Log "[INFO] Temporarily disabling known blocking CIS policies..."

# Disable FIPS Algorithm
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -Name Enabled -Value 0 -Force
Log "→ FIPS disabled"

# Enable shutdown without logon
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Value 1 -Force
Log "→ Shutdown without logon enabled"

# Allow Ctrl+Alt+Del
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableCAD" -Value 0 -Force
Log "→ Ctrl+Alt+Del requirement disabled"

# Enable root cert auto update
New-Item -Path "HKLM:\Software\Policies\Microsoft\SystemCertificates\AuthRoot" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\SystemCertificates\AuthRoot" -Name "DisableRootAutoUpdate" -Value 0 -Force
Log "→ Root Certificate Auto Update enabled"

# Remove "deny log on locally" entries for Administrators
$secpolPath = "$env:TEMP\secpol.cfg"
secedit /export /cfg $secpolPath > $null

$content = Get-Content $secpolPath
$content = $content -replace "SeDenyInteractiveLogonRight =.*", "SeDenyInteractiveLogonRight ="
$content = $content -replace "SeDenyNetworkLogonRight =.*", "SeDenyNetworkLogonRight ="

$content | Out-File $secpolPath -Encoding ASCII
secedit /configure /db secedit.sdb /cfg $secpolPath /quiet

Log "→ Cleared deny logon policies"

# Run Sysprep
Log "[INFO] Running Sysprep..."
$sysprepCmd = "C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /quiet /quit"
Start-Process -FilePath $sysprepCmd -Wait -PassThru

Start-Sleep -Seconds 5

# Capture Sysprep log
$sysprepLog = "C:\Windows\System32\Sysprep\Panther\setupact.log"
if (Test-Path $sysprepLog) {
    Log "`n==== Sysprep Log Start ===="
    Get-Content $sysprepLog | Out-File -Append -FilePath $logFile
    Log "==== Sysprep Log End ===="
} else {
    Log "[ERROR] Sysprep log not found."
}

# Restore original LGPO
Log "[INFO] Restoring original LGPO policies..."
& "$env:windir\System32\LGPO.exe" /g $lgpoBackupPath
Log "→ LGPO restored"

Log "`n[COMPLETE] CIS Policy handling for Sysprep is done."
