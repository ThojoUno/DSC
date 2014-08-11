#Pull computer objects for AD

function GetComputers {
    import-module activedirectory
    Get-ADComputer -SearchBase "OU=Servers,OU=HQ,DC=contoso,DC=com" -Filter *
}
$computers = GetComputers


#Pull list of computers and GUIDs into hash table
$ConfigData = @{
    AllNodes = @(
        foreach ($node in $computers) {
            @{NodeName = $node.Name; NodeGUID = $node.objectGUID;}
        }
    )
}

Configuration TestConfig {

    Node $Allnodes.NodeGUID {
            
        WindowsFeature TelnetClient {
            Ensure = "Present"
            Name = "Telnet-Client"
        } 
        
        Registry DisableUAC {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system"
            ValueName = "EnableLUA"
            ValueType = "DWord"
            ValueData = "0"
        }
        
        Registry IESecRegAdm {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
            ValueName = "IsInstalled"
            ValueType = "DWord"
            ValueData = "0"
        }

        Registry IESecRegUsr {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
            ValueName = "IsInstalled"
            ValueType = "DWord"
            ValueData = "0"
        }

        Registry IEEnableFileDLReg {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3"
            ValueName = "1803"
            ValueType = "DWord"
            ValueData = "0"
        }

        Registry IEEnableActXContrlsReg {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3"
            ValueName = "1405"
            ValueType = "DWord"
            ValueData = "0"
        }

        #Turn on automatic updates

        Registry AUOptions {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
            ValueName = "AUOptions"
            ValueType = "DWord"
            ValueData = "4"
        }
        
        Registry AUOptionsReboot {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
            ValueName = "NoAutoRebootWithLoggedOnUsers"
            ValueType = "DWord"
            ValueData = "0"
        }

        Registry AUOptionsNAU {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
            ValueName = "NoAutoUpdate"
            ValueType = "DWord"
            ValueData = "0"
        }
        
        Registry AUOptionsSchDay {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
            ValueName = "ScheduledInstallDay"
            ValueType = "DWord"
            ValueData = "7"
        }

        Registry AUOptionsSchTime {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
            ValueName = "ScheduledInstallTime"
            ValueType = "DWord"
            ValueData = "22"
        }

    }
}

TestConfig -ConfigurationData $ConfigData -OutputPath "$Env:Temp\TestConfig"

write-host "Creating checksums..."
New-DSCCheckSum -ConfigurationPath "$Env:Temp\TestConfig" -OutPath "$Env:Temp\TestConfig" -Verbose -Force

write-host "Copying configurations to pull service configuration store..."
$SourceFiles = "$Env:Temp\TestConfig\*.mof*"
$TargetFiles = "$env:SystemDrive\Program Files\WindowsPowershell\DscService\Configuration"
Move-Item $SourceFiles $TargetFiles -Force
Remove-Item "$Env:Temp\TestConfig\"


Configuration SimpleMetaConfigurationForPull
{ 

    Node $allnodes.NodeName
    {
    
        LocalConfigurationManager 
        { 
            ConfigurationID = "$($Node.NodeGUID)"
            RefreshMode = "PULL";
            DownloadManagerName = "WebDownloadManager";
            RebootNodeIfNeeded = $true;
            RefreshFrequencyMins = 5;
            ConfigurationModeFrequencyMins = 10; 
            ConfigurationMode = "ApplyAndAutoCorrect";
            DownloadManagerCustomData = @{ServerUrl = "http://DC01.contoso.com:8080/PSDSCPullServer.svc"; AllowUnsecureConnection = “TRUE”}
        }
    } 
}  

SimpleMetaConfigurationForPull -ConfigurationData $ConfigData -OutputPath "$Env:Temp\PullDSCCfg"

Set-DscLocalConfigurationManager -Path "$Env:Temp\PullDSCCfg"


