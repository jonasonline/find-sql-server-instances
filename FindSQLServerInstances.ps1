Import-Module ServerManager

if ((Test-Path config.ini) -eq $false) {
    Get-Content -Path "config.template.ini" | Out-File -FilePath "config.ini"
    Write-Warning "Created new configuration file from template"
    exit
} 
Get-Content "config.ini" | foreach-object -begin {$ScriptConfiguration=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $ScriptConfiguration.Add($k[0], $k[1..($k.Count - 1)].Replace("`"", "") -join "=") } }
$ErrorLogPath = $ScriptConfiguration.ErrorLogPath
$OutputPath = $ScriptConfiguration.OutputPath

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

$OUPaths = $OUPaths.Split(";")
New-Item -ItemType file -Force -Path $OutputPath | Out-Null
ForEach ($OUPath in $OUPaths) {
    Get-ADComputer -SearchBase $OUPath -Filter {(enabled -eq "true") -and -(OperatingSystem -Like "Windows *")} -SearchScope OneLevel -ResultPageSize 10000 -Server $DomainName | ForEach-Object{try{$currentDate = Get-Date; $recentError = $null; Get-Service -ComputerName $_.Name -ErrorVariable recentError -ErrorAction SilentlyContinue | Where-Object {$_.name -eq "MSSQLSERVER" -or $_.name -like "MSSQL$*" -or $_.displayName -like "SQL Server (*"};}catch{Write-Warning $_;Out-File -FilePath $ErrorLogPath -Append -InputObject $currentDate; Out-File -FilePath $ErrorLogPath -Append -InputObject $_};}| Select-Object MachineName, DisplayName, Status | Export-Csv -NoClobber -NoTypeInformation -Path $OutputPath -Append
}
