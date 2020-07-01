$succ = $false
Write-Host "Getting release information..." -ForegroundColor Yellow
$latest_release = (Invoke-WebRequest "https://api.github.com/repos/dust120125/checkout_and_deploy/releases/latest").Content | ConvertFrom-Json
$succ = $?
if ($succ)
{
    $version = $latest_release.tag_name
    $download_url = $latest_release.assets[0].browser_download_url
    $filename = $latest_release.assets[0].name
}

if ($succ)
{
    Write-Host "Version: $version" -ForegroundColor Yellow
    Write-Host "Downloading..." -ForegroundColor Yellow
    Invoke-WebRequest $download_url -OutFile $filename
    $succ = $?
}

if ($succ)
{
    Write-Host "UnZip..." -ForegroundColor Yellow
    Expand-Archive $filename -DestinationPath ./ -Force
    $succ = $?

    Write-Host "Remove zip file..." -ForegroundColor Yellow
    Remove-Item $filename
}

Write-Host ""
if ($succ)
{
    Write-Host "Install completed" -BackgroundColor DarkGreen -ForegroundColor Yellow
}
else
{
    Write-Host "Install failed" -BackgroundColor DarkRed -ForegroundColor Yellow
}

Write-Host "Press any key to exit..." -ForegroundColor Gray
cmd /c Pause | Out-Null