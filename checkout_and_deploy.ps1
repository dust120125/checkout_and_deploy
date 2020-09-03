## Read Config ###
$_ConfigFile = "./config.ini"
if (Test-Path $_ConfigFile -PathType Leaf)
{
    $_config = cat $_ConfigFile | ConvertFrom-Json
}

### Check Update ###

if ($_config.check_update)
{
    ./install.ps1 -CheckUpdate $true
    if ($LASTEXITCODE -eq 0)
    {
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        cmd /c Pause | Out-Null
        exit
    }
    Write-Host ""
}

### functions ###

function Confirm
{
    Param([String]$Prompt)
    while ($true)
    {
        $tmp = Read-Host -Prompt "$Prompt (y/n)"
        if ($tmp -eq 'y')
        {
            return $true
        }
        elseif ($tmp -eq 'n')
        {
            return $false
        }
    }
}

$_GeneralEnv = $null
function Get-EnvCode
{
    Param([Hashtable]$EnvMap, [String]$Prompt)
    if ($null -ne $_GeneralEnv -and $EnvMap.ContainsKey($_GeneralEnv))
    {
        $_tmp = $EnvMap[$_GeneralEnv]
        if ($Prompt) {
            Write-Host "${Prompt}: $_tmp"
        }
        return $_tmp
    }
    else
    {
        if (!$Prompt)
        {
            $_input = Read-Host
        }
        else
        {
            $_input = Read-Host -Prompt $Prompt
        }
        return $_input
    }
}

### Start Process ###

$PSScriptName = (Get-Item $PSCommandPath).BaseName
$localStorge = ".\$PSScriptName"

Write-Host Projects:
dir $localStorge -Filter *.json | % { Write-Host $_.BaseName -ForegroundColor Yellow }
Write-Host ""
$input = Read-Host -Prompt "Choose project to ckeckout..."
Write-Host ""

$input = $input -split ":"
$proj = $input[0]
Write-Host "project: $proj" -ForegroundColor Yellow
if ($input.Length -gt 1)
{
    $_GeneralEnv = $input[1]
    Write-Host "general env: $_GeneralEnv`n" -ForegroundColor Yellow
}

$datetime = Get-Date -Format "yyyyMMddHHmmss"
$logFile = Join-Path $localStorge -ChildPath "log" | Join-Path -ChildPath "${proj}_$datetime.log"
Start-Transcript -Path $logFile | Out-Null

if (-Not(Test-Path "$localStorge\$proj`.json" -PathType Leaf))
{
    Write-Host ("Clone failed`nProject [$proj] is not exist.")
    cmd /c Pause | Out-Null
    exit
}

$conf = cat "$localStorge\$proj`.json" | ConvertFrom-Json

$checkout = Read-Host -Prompt "Checkout to "
Write-Host ""

if ($conf.build_deb -and ($conf.build_deb.debproj_beta -or $conf.build_deb.debproj_prod))
{
    $buildDeb = Confirm -Prompt "Build .deb file ?"
    if ($buildDeb)
    {
        $debIsProd = Confirm -Prompt "Is production build ?"
        $debVersion = (Read-Host -Prompt "Build version").Trim()
        $debRemark = (Read-Host -Prompt "Remark").Trim()
    }
}

$succ = $true

#Clean deploy directories
if ($conf.deploy)
{
    $conf.git | % {
        if ($_.deploy_dest)
        {
            $ddest = Join-Path -Path $conf.deploy -ChildPath $_.deploy_dest
        }
        else
        {
            $ddest = $conf.deploy
        }
        if (Test-Path $ddest)
        {
            Remove-Item $ddest -Recurse -Force
        }
        New-Item -ItemType directory $ddest | Out-Null
    }
}

$conf.git | % {
    if (!$succ)
    {
        break
    }
    $path = $_.path
    Write-Host ""; Write-Host "";
    Write-Host "#### Processing $path ####" -ForegroundColor Black -BackgroundColor Yellow

    cd $PSScriptRoot
    if ($conf.deploy)
    {
        $deploy_dest_full = (Get-Item (Join-Path -Path $conf.deploy -ChildPath $_.deploy_dest)).FullName
    }
    if ($_.before_deploy)
    {
        $before_deploy_full = (Get-Item (Join-Path -Path $localStorge -ChildPath $_.before_deploy)).FullName
    }

    $need_remote = $_.remote
    $new_clone = $false
    if (-Not(Test-Path $path))
    {
        $new_clone = $true
        Write-Host "#### $path not found, auto clone git repository ####" -ForegroundColor Red -BackgroundColor Yellow
        git clone $need_remote $path
    }

    cd $path
    if ($_.deploy_src)
    {
        if (-Not(Test-Path $_.deploy_src))
        {
            New-Item -ItemType directory $_.deploy_src | Out-Null
        }
        $deploy_src_full = (Get-Item ($_.deploy_src)).FullName
    }
    else
    {
        $deploy_src_full = (Get-Item (".")).FullName
    }

    if (-Not($new_clone))
    {
        Write-Host "#### '$path' ckeck git repository ####" -ForegroundColor Yellow
        git status | Out-Null
        if (!$?)
        {
            Write-Host "#### Not a git repository, auto clean and clone ####" -ForegroundColor Red -BackgroundColor Yellow
            $new_clone = $true
        }
        else
        {
            $old_remote = git config --get remote.origin.url
            Write-Host "need $need_remote" -ForegroundColor Green
            if ($need_remote -ne $old_remote)
            {
                Write-Host "found $old_remote" -ForegroundColor Red
                Write-Host "#### Git repository not match, auto clean and clone ####" -ForegroundColor Red -BackgroundColor Yellow
                $new_clone = $true
            }
            else
            {
                Write-Host "found $old_remote" -ForegroundColor Green
            }
        }

        if ($new_clone)
        {
            cd $PSScriptRoot
            Remove-Item $path -Recurse -Force
            git clone $need_remote $path
        }
    }

    cd (Join-Path -Path $PSScriptRoot -ChildPath $path)
    if ($new_clone -and $_.after_clone)
    {
        Write-Host "#### New clone detected, run 'after_clone' script ####"  -ForegroundColor Yellow
        Write-Host "Script: " -NoNewline -ForegroundColor Yellow
        Write-Host "$( $_.after_clone )"  -ForegroundColor Cyan
        Invoke-Expression $_.after_clone
    }

    Write-Host ""
    git fetch --force
    git fetch --tags --force
    $tags = git tag
    #    $branches = git branch -r | % { $_.TrimStart() }
    if ($tags -and $tags.Contains($checkout))
    {
        Write-Host "#### '$path' ckeckout to tag($checkout) ####" -ForegroundColor Yellow
        git checkout --force $checkout
    }
    else
    {
        Write-Host "#### '$path' tag($checkout) not found ####" -ForegroundColor Yellow
        Write-Host "#### '$path' ckeckout to remote branch(origin/$checkout) ####" -ForegroundColor Yellow
        git checkout --force "origin/$checkout"
    }

    if ($succ = $?)
    {
        git submodule init
        if ($succ = $?)
        {
            git submodule sync
            git submodule update
        }
        if ($before_deploy_full)
        {
            . $before_deploy_full | Out-Default
            $succ = $?
            Write-Host ""
        }

        cd $PSScriptRoot
        if ($succ -and $deploy_dest_full)
        {
            $from = Join-Path -Path $deploy_src_full -ChildPath "*"
            $dest = Join-Path -Path $deploy_dest_full -ChildPath ""
            if ($_.exclude -and ($_.exclude -is [array]))
            {
                $excludeStr = ($_.exclude | % { "'$_'" }) -Join ', '
                Write-Host "Copy $from to $dest " -NoNewline -ForegroundColor Yellow
                Write-Host "(Exclude: $excludeStr)" -ForegroundColor Magenta
                Copy-Item $from -Destination $dest -Recurse -Force -Exclude $_.exclude
            }
            else
            {
                Write-Host "Copy $from to $dest" -ForegroundColor Yellow
                Copy-Item $from -Destination $dest -Recurse -Force
            }
        }
        else
        {
            Write-Host "#### After deploy ####" -ForegroundColor Yellow
            $scriptFile = (Get-Item (Join-Path -Path $localStorge -ChildPath $conf.after_deploy)).FullName
            cd $path
            . $scriptFile | Out-Default
        }
        $succ = $?
    }
}

Write-Host ''
if ($succ -and $conf.deploy -and $conf.after_deploy)
{
    Write-Host "#### After deploy ####" -ForegroundColor Yellow
    $scriptFile = (Get-Item (Join-Path -Path $localStorge -ChildPath $conf.after_deploy)).FullName
    cd (Join-Path -Path $PSScriptRoot -ChildPath $conf.deploy)
    . $scriptFile | Out-Default
    $succ = $?
}

cd $PSScriptRoot
Write-Host ""

if ($succ -and $buildDeb)
{
    Write-Host "#### Build .deb ####" -ForegroundColor Black -BackgroundColor Yellow
    $debmaker = "$localStorge\winmakedeb\winmakedeb.exe"
    if (-Not(Test-Path $debmaker))
    {
        Write-Host "#### WinMakeDeb.exe Not Found ####" -ForegroundColor Red -BackgroundColor Yellow
    }
    else
    {
        $debmakerDir = (Get-Item $debmaker).Directory.FullName
        if ($debIsProd)
        {
            $debproj = (Get-Item $conf.build_deb.debproj_prod).FullName
            $deboutput_path = $conf.build_deb.output_path_prod
        }
        else
        {
            $debproj = (Get-Item $conf.build_deb.debproj_beta).FullName
            $deboutput_path = $conf.build_deb.output_path_beta
        }

        if ($deboutput_path -eq "")
        {
            $deboutput_path = "./"
        }
        if (-not(Test-Path $deboutput_path))
        {
            New-Item -ItemType directory $deboutput_path | Out-Null
        }
        $deboutput_path = (Get-Item $deboutput_path).FullName
        $deboutput_name = $conf.build_deb.output_name
        $deboutput = Join-Path -Path $deboutput_path -ChildPath $deboutput_name

        cd $debmakerDir
        $params = @("`"$debproj`"", "--version", "`"$debVersion`"", "--path", "`"$deboutput`"")
        if ($debIsProd)
        {
            $params += "--production"
        }
        if ($debRemark)
        {
            $debRemark = $debRemark -Replace '"', '""'
            $params += "--remark"
            $params += "`"$debRemark`""
        }
        $paramsStr = $params -Join " "
        echo "./winmakedeb.exe $paramsStr"
        $makedebProcess = Start-Process -FilePath "./winmakedeb.exe" -ArgumentList $params -Wait -NoNewWindow -PassThru
        if ($makedebProcess.ExitCode -ne 0)
        {
            $succ = $false
        }
    }
}

cd $PSScriptRoot
Write-Host ""
if ($succ)
{
    Write-Host "Process completed" -BackgroundColor DarkGreen -ForegroundColor Yellow
}
else
{
    Write-Host "Process failed" -BackgroundColor DarkRed -ForegroundColor Yellow
}

Write-Host "Press any key to exit..." -ForegroundColor Gray
Stop-Transcript | Out-Null
cmd /c Pause | Out-Null
