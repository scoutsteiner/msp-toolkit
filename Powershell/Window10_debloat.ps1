#requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RemoveOneDrive,
    [switch]$RemoveXboxApps
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$LogPath = Join-Path $env:SystemDrive 'Win10-Gaming-Debloat.log'
Start-Transcript -Path $LogPath -Append | Out-Null

Write-Host "Windows 10 gaming-laptop cleanup" -ForegroundColor Cyan
Write-Host "Log: $LogPath"

# Intentionally retained:
# Microsoft Store, StorePurchaseApp, DesktopAppInstaller, WebView2, Photos,
# Calculator, Notepad, Paint, codecs, .NET/VC runtimes, Defender, Windows Update,
# Gaming Services, and Xbox Identity Provider.
$AppsToRemove = @(
    'Microsoft.3DBuilder'
    'Microsoft.549981C3F5F10'             # Cortana app
    'Microsoft.BingFinance'
    'Microsoft.BingFoodAndDrink'
    'Microsoft.BingHealthAndFitness'
    'Microsoft.BingNews'
    'Microsoft.BingSports'
    'Microsoft.BingTravel'
    'Microsoft.BingWeather'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.Messaging'
    'Microsoft.Microsoft3DViewer'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MixedReality.Portal'
    'Microsoft.NetworkSpeedTest'
    'Microsoft.Office.OneNote'
    'Microsoft.People'
    'Microsoft.Print3D'
    'Microsoft.SkypeApp'
    'Microsoft.Wallet'
    'Microsoft.WindowsAlarms'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.YourPhone'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'MicrosoftTeams'
    'Microsoft.Todos'
    'MicrosoftCorporationII.MicrosoftFamily'
    'MicrosoftCorporationII.QuickAssist'
    'Clipchamp.Clipchamp'
    'king.com.BubbleWitch3Saga'
    'king.com.CandyCrushSaga'
    'king.com.CandyCrushSodaSaga'
    'king.com.FarmHeroesSaga'
    'king.com.*'
    'SpotifyAB.SpotifyMusic'
    'Disney.*'
    'Facebook.*'
    'Twitter.*'
)

if ($RemoveXboxApps) {
    $AppsToRemove += @(
        'Microsoft.GamingApp'
        'Microsoft.XboxApp'
        'Microsoft.XboxGameOverlay'
        'Microsoft.XboxGamingOverlay'
        'Microsoft.XboxSpeechToTextOverlay'
    )
}

function Remove-BundledApp {
    param([Parameter(Mandatory)][string]$Pattern)

    Get-AppxPackage -AllUsers -Name $Pattern -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "Removing installed package: $($_.Name)"
        if ($PSCmdlet.ShouldProcess($_.PackageFullName, 'Remove Appx package')) {
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
    }

    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $Pattern | ForEach-Object {
        Write-Host "Removing provisioned package: $($_.DisplayName)"
        if ($PSCmdlet.ShouldProcess($_.PackageName, 'Remove provisioned Appx package')) {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

# Best-effort restore point. This can fail when System Protection is disabled.
try {
    Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction Stop
    Checkpoint-Computer -Description 'Before Win10 gaming debloat' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    Write-Host 'Restore point created.' -ForegroundColor Green
} catch {
    Write-Warning "Restore point was not created: $($_.Exception.Message)"
}

$AppsToRemove | Sort-Object -Unique | ForEach-Object { Remove-BundledApp -Pattern $_ }

# Disable consumer-app suggestions, Start menu advertising, tips, and lock-screen ads.
$MachinePolicies = @{
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' = @{
        DisableWindowsConsumerFeatures = 1
        DisableSoftLanding              = 1
    }
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{
        AllowTelemetry = 1   # Security/basic level on editions that honor it
    }
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' = @{
        DisabledByGroupPolicy = 1
    }
}

foreach ($Path in $MachinePolicies.Keys) {
    New-Item -Path $Path -Force | Out-Null
    foreach ($Name in $MachinePolicies[$Path].Keys) {
        New-ItemProperty -Path $Path -Name $Name -Value $MachinePolicies[$Path][$Name] -PropertyType DWord -Force | Out-Null
    }
}

$UserSettings = @{
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' = @{
        ContentDeliveryAllowed           = 0
        OemPreInstalledAppsEnabled        = 0
        PreInstalledAppsEnabled           = 0
        PreInstalledAppsEverEnabled       = 0
        SilentInstalledAppsEnabled        = 0
        SoftLandingEnabled                = 0
        SubscribedContent-310093Enabled   = 0
        SubscribedContent-338387Enabled   = 0
        SubscribedContent-338388Enabled   = 0
        SubscribedContent-338389Enabled   = 0
        SystemPaneSuggestionsEnabled      = 0
    }
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' = @{
        Enabled = 0
    }
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' = @{
        ShowSyncProviderNotifications = 0
    }
}

foreach ($Path in $UserSettings.Keys) {
    New-Item -Path $Path -Force | Out-Null
    foreach ($Name in $UserSettings[$Path].Keys) {
        New-ItemProperty -Path $Path -Name $Name -Value $UserSettings[$Path][$Name] -PropertyType DWord -Force | Out-Null
    }
}

# Disable tailored experiences and suggested content for the current user.
New-Item -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force | Out-Null
New-ItemProperty -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableTailoredExperiencesWithDiagnosticData -Value 1 -PropertyType DWord -Force | Out-Null

# Disable background activity for removed/unused Store apps without disabling the Store.
New-Item -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Force | Out-Null
New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name GlobalUserDisabled -Value 1 -PropertyType DWord -Force | Out-Null

if ($RemoveOneDrive) {
    Write-Host 'Removing OneDrive...'
    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    $OneDriveSetup = if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    } else {
        "$env:SystemRoot\System32\OneDriveSetup.exe"
    }
    if (Test-Path $OneDriveSetup) {
        Start-Process -FilePath $OneDriveSetup -ArgumentList '/uninstall' -Wait
    }
    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Force | Out-Null
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name DisableFileSyncNGSC -Value 1 -PropertyType DWord -Force | Out-Null
}

# Clear temporary files using supported cleanup APIs/locations.
Get-ChildItem "$env:TEMP\*" -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Start-Process -FilePath "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList '/VERYLOWDISK' -Wait -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'Cleanup complete. Restart Windows before installing the game launchers.' -ForegroundColor Green
Write-Host 'Microsoft Store, WebView2, Gaming Services, Xbox Identity Provider, Defender, and Windows Update were retained.'
Stop-Transcript | Out-Null
