Param([Bool]$CheckUpdate)
$_ConfigFile = "./config.ini"

function Write-Config
{
    Param([String]$Version)
    if (Test-Path $_ConfigFile -PathType Leaf)
    {
        $config = Get-Content $_ConfigFile | ConvertFrom-Json
        $config | Add-Member -MemberType NoteProperty -Name 'version' -Value $Version -Force
    }
    else
    {
        $config = @{ version = $Version; check_update = $true }
    }
    Set-Content ($config | ConvertTo-Json) -Path $_ConfigFile
}

if (!$CheckUpdate)
{
    Write-Host ""
    Write-Host "***********************************************" -ForegroundColor Green
    Write-Host "***********************************************" -ForegroundColor Green
    Write-Host "**** This script will get latest release   ****" -ForegroundColor Green
    Write-Host "**** information of `"checkout_and_deploy`", ****" -ForegroundColor Green
    Write-Host "**** then downlaod the latest release      ****" -ForegroundColor Green
    Write-Host "***********************************************" -ForegroundColor Green
    Write-Host "***********************************************" -ForegroundColor Green
    Write-Host ""
}

$succ = $false
Write-Host "Getting release information...`n" -ForegroundColor Yellow
$latest_release = (Invoke-WebRequest "https://api.github.com/repos/dust120125/checkout_and_deploy/releases/latest").Content | ConvertFrom-Json
$succ = $?
if ($succ)
{
    $version = $latest_release.tag_name
    $body = ($latest_release.body.split("`n") | % {
        "    $_"
    }) -Join "`n"
    $download_url = $latest_release.assets[0].browser_download_url
    $filename = $latest_release.assets[0].name
}

if (Test-Path $_ConfigFile -PathType Leaf)
{
    $_config = cat $_ConfigFile | ConvertFrom-Json
    $oldVersion = $_config.version
    if ($null -ne $oldVersion)
    {
        Write-Host "Current version: $oldVersion" -ForegroundColor Yellow
    }
}

if ($succ)
{
    Write-Host "Latest version: $version" -ForegroundColor Yellow
    if ($version -eq $oldVersion)
    {
        Write-Host "Your version is up to date`n" -ForegroundColor Green
        if ($CheckUpdate)
        {
            exit 2
        }
    }

    Write-Host "Release note:" -ForegroundColor Yellow
    Write-Host $body
    $install = Read-Host -Prompt "`nInstall latest version ? (y/n)"
    if ($install -ne 'y')
    {
        exit 2
    }
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
    Write-Config -Version $version
    Write-Host "Install completed" -BackgroundColor DarkGreen -ForegroundColor Yellow
}
else
{
    Write-Host "Install failed" -BackgroundColor DarkRed -ForegroundColor Yellow
}

if (!$CheckUpdate)
{
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    cmd /c Pause | Out-Null
}

if ($succ)
{
    exit 0
}
else
{
    exit 1
}