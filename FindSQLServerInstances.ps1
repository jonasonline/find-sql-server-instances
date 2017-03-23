Import-Module ServerManager

if ((Test-Path -Path "config.json") -eq $false -or $Init -eq $true) {
    Get-Content -Path ".\config.jsontemplate.json" | Out-File -FilePath "config.json"
}
$ScriptConfiguration = (Get-Content "config.json") -Join "`n" | ConvertFrom-Json

$ADPowershellModule = Get-WindowsFeature RSAT-AD-PowerShell
if ($ADPowershellModule.Installed -eq $false) {
    Write-Host "Adding Active Directory Powershell module"
    Add-WindowsFeature RSAT-AD-PowerShell
}

$OUPaths = $ScriptConfiguration.OUPaths
if ($OUPaths -eq $null) {
    Write-Error "Missing OU paths in configurationfile."
    exit
}

$DomainName = $ScriptConfiguration.DomainName
if ($DomainName -eq $null) {
    Write-Error "Missing Domain name in configurationfile."
    exit
}

New-Item -ItemType file -Force -Path $ScriptConfiguration.OutputPath | Out-Null
ForEach ($OUPath in $ScriptConfiguration.OUPaths) {
    $server = $nil 
    if ($OUPath.Server) {
        $server = $OUPath.Server 
    } else {
        $server = $ScriptConfiguration.DomainName
    }
    if ($ScriptConfiguration.OperatingSystemSearchText -eq $null) {
        $operatingSystemSearchPattern = "Windows Server*"   
    } else {
        $operatingSystemSearchPattern = $ScriptConfiguration.OperatingSystemSearchText
    }
    Get-ADComputer -SearchBase $OUPath.Path -Filter {(enabled -eq $true) -and (OperatingSystem -Like $operatingSystemSearchPattern)} -SearchScope $OUPath.SearchScope -ResultPageSize 10000 -Server $server | ForEach-Object{try{$currentDate = Get-Date; $recentError = $null; Get-Service -ComputerName $_.Name -ErrorVariable recentError -ErrorAction SilentlyContinue | Where-Object {$_.name -eq "MSSQLSERVER" -or $_.name -like "MSSQL$*" -or $_.displayName -like "SQL Server (*"};}catch{Write-Warning $_;Out-File -FilePath $ScriptConfiguration.ErrorLogPath -Append -InputObject $currentDate; Out-File -FilePath $ScriptConfiguration.ErrorLogPath -Append -InputObject $_};}| Select-Object MachineName, DisplayName, Status | Export-Csv -NoClobber -NoTypeInformation -Path $ScriptConfiguration.OutputPath -Append
}
