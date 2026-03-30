$ScriptDir = $PSScriptRoot
$MsiPath   = Join-Path $ScriptDir "TeamViewer_Full.msi"
$LogPath   = Join-Path $ScriptDir "install.log"

Write-Host "Bestaande TeamViewer processen stoppen..."
Get-Process TeamViewer -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "Bestaande TeamViewer uninstall-string zoeken..."
$uninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$tv = foreach ($key in $uninstallKeys) {
    Get-ItemProperty $key -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "TeamViewer*" }
}

if ($tv) {
    foreach ($item in $tv) {
        Write-Host "Gevonden:" $item.DisplayName
        if ($item.UninstallString) {
            $cmd = $item.UninstallString

            if ($cmd -match 'MsiExec\.exe') {
                Write-Host "MSI uninstall uitvoeren..."
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd /qn" -Wait
            }
            else {
                Write-Host "EXE uninstall uitvoeren..."
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd /S" -Wait
            }
        }
    }
}
else {
    Write-Host "Geen bestaande TeamViewer installatie gevonden."
}

Start-Sleep -Seconds 3

if (-not (Test-Path $MsiPath)) {
    Write-Host "MSI niet gevonden: $MsiPath"
    Pause
    exit 1
}

Write-Host "Nieuwe MSI installatie starten..."
$proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$MsiPath`" /qn /L*v `"$LogPath`"" -Wait -PassThru

Write-Host "TeamViewer automatisch starten en instellen..." -ForegroundColor Cyan

# Service op automatisch zetten
try {
    Set-Service -Name "TeamViewer" -StartupType Automatic
} catch {
    Write-Host "Kon service niet aanpassen"
}

# Pad bepalen
$tvPath = "C:\Program Files\TeamViewer\TeamViewer.exe"
if (-not (Test-Path $tvPath)) {
    $tvPath = "C:\Program Files (x86)\TeamViewer\TeamViewer.exe"
}

# Direct starten + autostart instellen
if (Test-Path $tvPath) {
    Start-Process $tvPath

    try {
        New-ItemProperty `
            -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" `
            -Name "TeamViewer" `
            -Value "`"$tvPath`"" `
            -PropertyType String `
            -Force | Out-Null
    } catch {
        Write-Host "Kon autostart niet zetten"
    }
}

# Controle of TeamViewer draait
Start-Sleep -Seconds 5

if (-not (Get-Process TeamViewer -ErrorAction SilentlyContinue)) {
    Write-Host "TeamViewer draait niet, opnieuw starten..." -ForegroundColor Yellow

    $tvPath = "C:\Program Files\TeamViewer\TeamViewer.exe"
    if (-not (Test-Path $tvPath)) {
        $tvPath = "C:\Program Files (x86)\TeamViewer\TeamViewer.exe"
    }

    if (Test-Path $tvPath) {
        Start-Process $tvPath
    } else {
        Write-Host "TeamViewer exe niet gevonden!" -ForegroundColor Red
    }
}
else {
    Write-Host "TeamViewer draait al " -ForegroundColor Green
}

Write-Host "Exitcode: $($proc.ExitCode)"
Write-Host "Logbestand: $LogPath"
Pause
exit $proc.ExitCode