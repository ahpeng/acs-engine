<#
    .SYNOPSIS
        Provisions VM as a Kubernetes agent.

    .DESCRIPTION
        Provisions VM as a Kubernetes agent.
#>
[CmdletBinding(DefaultParameterSetName="Standard")]
param(
    [string]
    [ValidateNotNullOrEmpty()]
    $MasterIP,

    [parameter()]
    [ValidateNotNullOrEmpty()]
    $KubeDnsServiceIp,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $MasterFQDNPrefix,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $Location,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $AgentKey,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $AzureHostname,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $AADClientId,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $AADClientSecret
)

$global:CACertificate = "{{WrapAsVariable "caCertificate"}}"
$global:AgentCertificate = "{{WrapAsVariable "clientCertificate"}}"
$global:DockerServiceName = "Docker"
$global:KubeDir = "c:\k"
$global:KubeBinariesSASURL = "{{WrapAsVariable "kubeBinariesSASURL"}}"
$global:WindowsPackageSASURLBase = "{{WrapAsVariable "windowsPackageSASURLBase"}}"
$global:KubeBinariesVersion = "{{WrapAsVariable "kubeBinariesVersion"}}"
$global:WindowsTelemetryGUID = "{{WrapAsVariable "windowsTelemetryGUID"}}"
$global:KubeletStartFile = $global:KubeDir + "\kubeletstart.ps1"
$global:KubeProxyStartFile = $global:KubeDir + "\kubeproxystart.ps1"

$global:TenantId = "{{WrapAsVariable "tenantID"}}"
$global:SubscriptionId = "{{WrapAsVariable "subscriptionId"}}"
$global:ResourceGroup = "{{WrapAsVariable "resourceGroup"}}"
$global:SubnetName = "{{WrapAsVariable "subnetName"}}"
$global:MasterSubnet = "{{WrapAsVariable "subnet"}}"
$global:SecurityGroupName = "{{WrapAsVariable "nsgName"}}"
$global:VNetName = "{{WrapAsVariable "virtualNetworkName"}}"
$global:RouteTableName = "{{WrapAsVariable "routeTableName"}}"
$global:PrimaryAvailabilitySetName = "{{WrapAsVariable "primaryAvailabilitySetName"}}"
$global:KubeClusterCIDR = "{{WrapAsVariable "kubeClusterCidr"}}"
$global:KubeServiceCIDR = "{{WrapAsVariable "kubeServiceCidr"}}"
$global:KubeNetwork = "l2bridge"

$global:UseManagedIdentityExtension = "{{WrapAsVariable "useManagedIdentityExtension"}}"
$global:UseInstanceMetadata = "{{WrapAsVariable "useInstanceMetadata"}}"

$global:CNIPath = [Io.path]::Combine("$global:KubeDir", "cni")
$global:NetworkMode = "L2Bridge"
$global:CNIConfig = [Io.path]::Combine($global:CNIPath, "config", "`$global:NetworkMode.conf")
$global:CNIConfigPath = [Io.path]::Combine("$global:CNIPath", "config")
$global:WindowsCNIKubeletOptions = " --network-plugin=cni --cni-bin-dir=$global:CNIPath --cni-conf-dir=$global:CNIConfigPath"
$global:HNSModule = [Io.path]::Combine("$global:KubeDir", "hns.psm1")

$global:VolumePluginDir = [Io.path]::Combine("$global:KubeDir", "volumeplugins")
#azure cni
$global:NetworkPolicy = "{{WrapAsVariable "networkPolicy"}}"
$global:VNetCNIPluginsURL = "{{WrapAsVariable "vnetCniWindowsPluginsURL"}}"

$global:AzureCNIDir = [Io.path]::Combine("$global:KubeDir", "azurecni")
$global:AzureCNIBinDir = [Io.path]::Combine("$global:AzureCNIDir", "bin")
$global:AzureCNIConfDir = [Io.path]::Combine("$global:AzureCNIDir", "netconf")
$global:AzureCNIKubeletOptions = " --network-plugin=cni --cni-bin-dir=$global:AzureCNIBinDir --cni-conf-dir=$global:AzureCNIConfDir"
$global:AzureCNIEnabled = $false


{{if IsAzureStackCloud}}

$global:CloudName = "{{WrapAsVariable "cloudprofileName"}}"
$global:AzureStackManagementPortalURL = "{{WrapAsVariable "cloudprofileManagementPortalURL"}}"
$global:AzureStackPublishSettingsURL = "{{WrapAsVariable "cloudprofilePublishSettingsURL"}}"
$global:AzureStackServiceManagementEndpoint = "{{WrapAsVariable "cloudprofileServiceManagementEndpoint"}}"
$global:AzureStackResourceManagerEndpoint = "{{WrapAsVariable "cloudprofileResourceManagerEndpoint"}}"
$global:AzureStackActiveDirectoryEndpoint = "{{WrapAsVariable "cloudprofileActiveDirectoryEndpoint"}}"
$global:AzureStackGalleryEndpoint = "{{WrapAsVariable "cloudprofileGalleryEndpoint"}}"
$global:AzureStackKeyVaultEndpoint = "{{WrapAsVariable "cloudprofileKeyVaultEndpoint"}}"
$global:AzureStackGraphEndpoint = "{{WrapAsVariable "cloudprofileGraphEndpoint"}}"
$global:AzureStackStorageEndpointSuffix = "{{WrapAsVariable "cloudprofileStorageEndpointSuffix"}}"
$global:AzureStackSQLDatabaseDNSSuffix = "{{WrapAsVariable "cloudprofileSQLDatabaseDNSSuffix"}}"
$global:AzureStackTrafficManagerDNSSuffix = "{{WrapAsVariable "cloudprofileTrafficManagerDNSSuffix"}}"
$global:AzureStackKeyVaultDNSSuffix = "{{WrapAsVariable "cloudprofileKeyVaultDNSSuffix"}}"
$global:AzureStackServiceBusEndpointSuffix = "{{WrapAsVariable "cloudprofileServiceBusEndpointSuffix"}}"
$global:AzureStackServiceManagementVMDNSSuffix = "{{WrapAsVariable "cloudprofileServiceManagementVMDNSSuffix"}}"
$global:AzureStackResourceManagerVMDNSSuffix = "{{WrapAsVariable "cloudprofileResourceManagerVMDNSSuffix"}}"
$global:AzureStackContainerRegistryDNSSuffix = "{{WrapAsVariable "cloudprofileContainerRegistryDNSSuffix"}}"
$global:AzureStackLocation = "{{WrapAsVariable "cloudprofileLocation"}}"

{{end}}


filter Timestamp {"$(Get-Date -Format o): $_"}

function
Write-Log($message)
{
    $msg = $message | Timestamp
    Write-Output $msg
}

function Set-TelemetrySetting()
{
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "CommercialId" -Value $global:WindowsTelemetryGUID -Force
}

function Resize-OSDrive()
{
    $osDrive = ((Get-WmiObject Win32_OperatingSystem).SystemDrive).TrimEnd(":")
    $size = (Get-Partition -DriveLetter $osDrive).Size
    $maxSize = (Get-PartitionSupportedSize -DriveLetter $osDrive).SizeMax
    if ($size -lt $maxSize)
    { 
        Resize-Partition -DriveLetter $osDrive -Size $maxSize
    }
}

function
Get-KubeBinaries()
{
    $zipfile = "c:\k.zip"
    Invoke-WebRequest -Uri $global:KubeBinariesSASURL -OutFile $zipfile
    Expand-Archive -path $zipfile -DestinationPath C:\
}

function
Install-Package($package)
{
    $pkgFile = [Io.path]::Combine($global:KubeDir, $package)
    $url = $global:WindowsPackageSASURLBase + $package
    Invoke-WebRequest -Uri $url -OutFile $pkgFile
    & "$pkgFile" /q /norestart

    $procName = [IO.Path]::GetFileNameWithoutExtension($package)
    Wait-Process -Name $procName
    Write-Log "$package installed"
}

function DownloadFileOverHttp($Url, $DestinationPath)
{
     $secureProtocols = @()
     $insecureProtocols = @([System.Net.SecurityProtocolType]::SystemDefault, [System.Net.SecurityProtocolType]::Ssl3)

     foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType]))
     {
         if ($insecureProtocols -notcontains $protocol)
         {
             $secureProtocols += $protocol
         }
     }
     [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols

    curl $Url -UseBasicParsing -OutFile $DestinationPath -Verbose
    Write-Log "$DestinationPath updated"
}
function Get-HnsPsm1()
{
    DownloadFileOverHttp "https://github.com/Microsoft/SDN/raw/master/Kubernetes/windows/hns.psm1" "$global:HNSModule"
}

function Update-WinCNI()
{
    $wincni = "wincni.exe"
    $wincniFile = [Io.path]::Combine($global:CNIPath, $wincni)
    DownloadFileOverHttp "https://github.com/Microsoft/SDN/raw/master/Kubernetes/windows/cni/wincni.exe" $wincniFile
}

function
Update-WindowsPackages()
{
    bcdedit /set TESTSIGNING on

    $packages = @("Windows10.0-KB123456-x64-InstallForTestingPurposesOnly.exe", "Windows10.0-KB999999-x64-InstallForTestingPurposesOnly.exe")
    foreach ($pkg in $packages)
    {
        Install-Package($pkg)
    }

    Update-WinCNI
    Get-HnsPsm1
}

{{if IsAzureStackCloud}}
function
Write-AzureStackCloudConfig()
{
    $azureStackConfigFile = $global:KubeDir + "\azurestackcloud.json"
    $azureStackConfig = @"
{
    "name": "$global:CloudName",
    "managementPortalURL": "$global:AzureStackManagementPortalURL",
    "publishSettingsURL": "$global:AzureStackPublishSettingsURL",
    "serviceManagementEndpoint": "$global:AzureStackServiceManagementEndpoint",
    "resourceManagerEndpoint": "$global:AzureStackResourceManagerEndpoint",
    "activeDirectoryEndpoint": "$global:AzureStackActiveDirectoryEndpoint",
    "galleryEndpoint": "$global:AzureStackGalleryEndpoint",
    "keyVaultEndpoint": "$global:AzureStackKeyVaultEndpoint",
    "graphEndpoint": "$global:AzureStackGraphEndpoint",
    "storageEndpointSuffix": "$global:AzureStackStorageEndpointSuffix",
    "sQLDatabaseDNSSuffix": "$global:AzureStackSQLDatabaseDNSSuffix",
    "trafficManagerDNSSuffix": "$global:AzureStackTrafficManagerDNSSuffix",
    "keyVaultDNSSuffix": "$global:AzureStackKeyVaultDNSSuffix",
    "serviceBusEndpointSuffix": "$global:AzureStackServiceBusEndpointSuffix",
    "serviceManagementVMDNSSuffix": "$global:AzureStackServiceManagementVMDNSSuffix",
    "resourceManagerVMDNSSuffix": "$global:AzureStackResourceManagerVMDNSSuffix",
    "containerRegistryDNSSuffix": "$global:AzureStackContainerRegistryDNSSuffix"
    }
"@
    $azureStackConfig | Out-File -encoding ASCII -filepath "$azureStackConfigFile"
}
{{end}}

function
Write-AzureConfig()
{
    $azureConfigFile = $global:KubeDir + "\azure.json"
    
    $azureConfig = @"
{
    {{if IsAzureStackCloud}}
    "cloud":"$global:CloudName",
    {{end}}
    "tenantId": "$global:TenantId",
    "subscriptionId": "$global:SubscriptionId",
    "aadClientId": "$AADClientId",
    "aadClientSecret": "$AADClientSecret",
    "resourceGroup": "$global:ResourceGroup",
    "location": "$Location",
    "subnetName": "$global:SubnetName",
    "securityGroupName": "$global:SecurityGroupName",
    "vnetName": "$global:VNetName",
    "routeTableName": "$global:RouteTableName",
    "primaryAvailabilitySetName": "$global:PrimaryAvailabilitySetName",
    "useManagedIdentityExtension": $global:UseManagedIdentityExtension,
    "useInstanceMetadata": $global:UseInstanceMetadata
}
"@
    
    $azureConfig | Out-File -encoding ASCII -filepath "$azureConfigFile"
}

function
Write-KubeConfig()
{
    $kubeConfigFile = $global:KubeDir + "\config"

    $kubeConfig = @"
---
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: "$global:CACertificate"
    server: https://${MasterIP}:443
  name: "$MasterFQDNPrefix"
contexts:
- context:
    cluster: "$MasterFQDNPrefix"
    user: "$MasterFQDNPrefix-admin"
  name: "$MasterFQDNPrefix"
current-context: "$MasterFQDNPrefix"
kind: Config
users:
- name: "$MasterFQDNPrefix-admin"
  user:
    client-certificate-data: "$global:AgentCertificate"
    client-key-data: "$AgentKey"
"@

    $kubeConfig | Out-File -encoding ASCII -filepath "$kubeConfigFile"
}

function
New-InfraContainer()
{
    cd $global:KubeDir
    docker build -t kubletwin/pause .
}

function
Set-VnetPluginMode($mode)
{
    # Sets Azure VNET CNI plugin operational mode.
    $fileName  = [Io.path]::Combine("$global:AzureCNIConfDir", "10-azure.conflist")
    (Get-Content $fileName) | %{$_ -replace "`"mode`":.*", "`"mode`": `"$mode`","} | Out-File -encoding ASCII -filepath $fileName
}

function
Install-VnetPlugins()
{
    # Create CNI directories.
     mkdir $global:AzureCNIBinDir
     mkdir $global:AzureCNIConfDir

    # Download Azure VNET CNI plugins.
    # Mirror from https://github.com/Azure/azure-container-networking/releases
    $zipfile =  [Io.path]::Combine("$global:AzureCNIDir", "azure-vnet.zip")
    Invoke-WebRequest -Uri $global:VNetCNIPluginsURL -OutFile $zipfile
    Expand-Archive -path $zipfile -DestinationPath $global:AzureCNIBinDir
    del $zipfile

    # Windows does not need a separate CNI loopback plugin because the Windows
    # kernel automatically creates a loopback interface for each network namespace.
    # Copy CNI network config file and set bridge mode.
    move $global:AzureCNIBinDir/*.conflist $global:AzureCNIConfDir

    # Enable CNI in kubelet.
    $global:AzureCNIEnabled = $true
}

function
Set-AzureNetworkPolicy()
{
    # Azure VNET network policy requires tunnel (hairpin) mode because policy is enforced in the host.
    Set-VnetPluginMode "tunnel"
}

function
Set-NetworkConfig
{
    Write-Log "Configuring networking with NetworkPolicy:$global:NetworkPolicy"

    # Configure network policy.
    if ($global:NetworkPolicy -eq "azure") {
        Install-VnetPlugins
        Set-AzureNetworkPolicy
    }
}
 
function
Write-KubernetesStartFiles($podCIDR)
{
    mkdir $global:VolumePluginDir
    $KubeletArgList = @("--hostname-override=`$global:AzureHostname","--pod-infra-container-image=kubletwin/pause","--resolv-conf=""""""""","--kubeconfig=c:\k\config","--cloud-provider=azure","--cloud-config=c:\k\azure.json")
    $KubeletCommandLine = @"
c:\k\kubelet.exe --hostname-override=`$global:AzureHostname --pod-infra-container-image=kubletwin/pause --resolv-conf="" --allow-privileged=true --enable-debugging-handlers --cluster-dns=`$global:KubeDnsServiceIp --cluster-domain=cluster.local  --kubeconfig=c:\k\config --hairpin-mode=promiscuous-bridge --v=2 --azure-container-registry-config=c:\k\azure.json --runtime-request-timeout=10m  --cloud-provider=azure --cloud-config=c:\k\azure.json
"@

    if ([System.Version]$global:KubeBinariesVersion -lt [System.Version]"1.8.0")
    {
        # --api-server deprecates from 1.8.0
        $KubeletArgList += "--api-servers=https://`${global:MasterIP}:443"
        $KubeletCommandLine += " --api-servers=https://`${global:MasterIP}:443"
    }

    # more time is needed to pull windows server images
    $KubeletCommandLine += " --image-pull-progress-deadline=20m --cgroups-per-qos=false --enforce-node-allocatable=`"`""
    $KubeletCommandLine += " --volume-plugin-dir=`$global:VolumePluginDir"
     # Configure kubelet to use CNI plugins if enabled.
    if ($global:AzureCNIEnabled) {
        $KubeletCommandLine += $global:AzureCNIKubeletOptions
    } else {
        $KubeletCommandLine += $global:WindowsCNIKubeletOptions
    }

    $KubeletArgListStr = "`"" + ($KubeletArgList -join "`",`"") + "`""

    $KubeletArgListStr = "@`($KubeletArgListStr`)"

    {{if IsAzureStackCloud}}
    $azureStackConfigFilePath = (Join-Path (Join-Path "c:" "k") "azurestackcloud.json")
    {{end}}
    $kubeStartStr = @"
`$global:AzureHostname = "$AzureHostname"
`$global:MasterIP = "$MasterIP"
`$global:KubeDnsSearchPath = "svc.cluster.local"
`$global:KubeDnsServiceIp = "$KubeDnsServiceIp"
`$global:MasterSubnet = "$global:MasterSubnet"
`$global:KubeClusterCIDR = "$global:KubeClusterCIDR"
`$global:KubeServiceCIDR = "$global:KubeServiceCIDR"
`$global:KubeBinariesVersion = "$global:KubeBinariesVersion"
`$global:CNIPath = "$global:CNIPath"
`$global:NetworkMode = "$global:NetworkMode"
`$global:CNIConfig = "$global:CNIConfig"
`$global:HNSModule = "$global:HNSModule"
`$global:VolumePluginDir = "$global:VolumePluginDir"
`$global:NetworkPolicy="$global:NetworkPolicy" 
{{if IsAzureStackCloud}}
`$env:AZURE_ENVIRONMENT_FILEPATH= "$azureStackConfigFilePath"
{{end}}
"@

    if ($global:NetworkPolicy -eq "azure") {
        $global:KubeNetwork = "azure"
        $global:NetworkMode = "L2Tunnel"
        $kubeStartStr += @"
Write-Host "NetworkPolicy azure, starting kubelet."
$KubeletCommandLine

"@
    } else {
        $kubeStartStr += @"
        
function
Get-DefaultGateway(`$CIDR)
{
    return `$CIDR.substring(0,`$CIDR.lastIndexOf(".")) + ".1"
}

function
Get-PodCIDR()
{
    `$podCIDR = c:\k\kubectl.exe --kubeconfig=c:\k\config get nodes/`$(`$global:AzureHostname.ToLower()) -o custom-columns=podCidr:.spec.podCIDR --no-headers
    return `$podCIDR
}

function
Test-PodCIDR(`$podCIDR)
{
    return `$podCIDR.length -gt 0
}

function
Update-CNIConfig(`$podCIDR, `$masterSubnetGW)
{
    `$jsonSampleConfig =
"{
    ""cniVersion"": ""0.2.0"",
    ""name"": ""<NetworkMode>"",
    ""type"": ""wincni.exe"",
    ""master"": ""Ethernet"",
    ""capabilities"": { ""portMappings"": true },
    ""ipam"": {
        ""environment"": ""azure"",
        ""subnet"":""<PODCIDR>"",
        ""routes"": [{
        ""GW"":""<PODGW>""
        }]
    },
    ""dns"" : {
    ""Nameservers"" : [ ""<NameServers>"" ],
    ""Search"" : [ ""<Cluster DNS Suffix or Search Path>"" ]
    },
    ""AdditionalArgs"" : [
    {
        ""Name"" : ""EndpointPolicy"", ""Value"" : { ""Type"" : ""OutBoundNAT"", ""ExceptionList"": [ ""<ClusterCIDR>"", ""<MgmtSubnet>"" ] }
    },
    {
        ""Name"" : ""EndpointPolicy"", ""Value"" : { ""Type"" : ""ROUTE"", ""DestinationPrefix"": ""<ServiceCIDR>"", ""NeedEncap"" : true }
    }
    ]
}"

    `$configJson = ConvertFrom-Json `$jsonSampleConfig
    `$configJson.name = `$global:NetworkMode.ToLower()
    `$configJson.ipam.subnet=`$podCIDR
    `$configJson.ipam.routes[0].GW = `$masterSubnetGW
    `$configJson.dns.Nameservers[0] = `$global:KubeDnsServiceIp
    `$configJson.dns.Search[0] = `$global:KubeDnsSearchPath

    `$configJson.AdditionalArgs[0].Value.ExceptionList[0] = `$global:KubeClusterCIDR
    `$configJson.AdditionalArgs[0].Value.ExceptionList[1] = `$global:MasterSubnet
    `$configJson.AdditionalArgs[1].Value.DestinationPrefix  = `$global:KubeServiceCIDR

    if (Test-Path `$global:CNIConfig)
    {
        Clear-Content -Path `$global:CNIConfig
    }

    Write-Host "Generated CNI Config [`$configJson]"

    Add-Content -Path `$global:CNIConfig -Value (ConvertTo-Json `$configJson -Depth 20)
}

try
{
    `$masterSubnetGW = Get-DefaultGateway `$global:MasterSubnet
    `$podCIDR=Get-PodCIDR
    `$podCidrDiscovered=Test-PodCIDR(`$podCIDR)

    # if the podCIDR has not yet been assigned to this node, start the kubelet process to get the podCIDR, and then promptly kill it.
    if (-not `$podCidrDiscovered)
    {
        `$argList = $KubeletArgListStr

        `$process = Start-Process -FilePath c:\k\kubelet.exe -PassThru -ArgumentList `$argList

        # run kubelet until podCidr is discovered
        Write-Host "waiting to discover pod CIDR"
        while (-not `$podCidrDiscovered)
        {
            Write-Host "Sleeping for 10s, and then waiting to discover pod CIDR"
            Start-Sleep 10

            `$podCIDR=Get-PodCIDR
            `$podCidrDiscovered=Test-PodCIDR(`$podCIDR)
        }

        # stop the kubelet process now that we have our CIDR, discard the process output
        `$process | Stop-Process | Out-Null
    }

    # Turn off Firewall to enable pods to talk to service endpoints. (Kubelet should eventually do this)
    netsh advfirewall set allprofiles state off

    # startup the service
    `$hnsNetwork = Get-HnsNetwork | ? Name -EQ `$global:NetworkMode.ToLower()

    if (`$hnsNetwork)
    {
        # Kubelet has been restarted with existing network.
        # Cleanup all containers
        docker ps -q | foreach {docker rm `$_ -f}
        # cleanup network
        Write-Host "Cleaning up old HNS network found"
        Remove-HnsNetwork `$hnsNetwork
        Start-Sleep 10
    }

    Write-Host "Creating a new hns Network"
    ipmo `$global:HNSModule

    `$hnsNetwork = New-HNSNetwork -Type `$global:NetworkMode -AddressPrefix `$podCIDR -Gateway `$masterSubnetGW -Name `$global:NetworkMode.ToLower() -Verbose
    # New network has been created, Kubeproxy service has to be restarted
    Restart-Service Kubeproxy   

    Start-Sleep 10
    # Add route to all other POD networks
    Update-CNIConfig `$podCIDR `$masterSubnetGW

    $KubeletCommandLine
}
catch
{
    Write-Error `$_
} 

"@
    }
    
    $kubeStartStr | Out-File -encoding ASCII -filepath $global:KubeletStartFile

    $kubeProxyStartStr = @"
`$env:KUBE_NETWORK = "$global:KubeNetwork"
`$global:NetworkMode = "$global:NetworkMode"
`$global:HNSModule = "$global:HNSModule"
`$hnsNetwork = Get-HnsNetwork | ? Type -EQ `$global:NetworkMode.ToLower()
while (!`$hnsNetwork)
{
    Start-Sleep 10
    `$hnsNetwork = Get-HnsNetwork | ? Type -EQ `$global:NetworkMode.ToLower()
}

#
# cleanup the persisted policy lists
#
ipmo `$global:HNSModule
Get-HnsPolicyList | Remove-HnsPolicyList

$global:KubeDir\kube-proxy.exe --v=3 --proxy-mode=kernelspace --hostname-override=$AzureHostname --kubeconfig=$global:KubeDir\config
"@

    $kubeProxyStartStr | Out-File -encoding ASCII -filepath $global:KubeProxyStartFile
}

function
New-NSSMService
{
    # setup kubelet
    c:\k\nssm install Kubelet C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
    c:\k\nssm set Kubelet AppDirectory $global:KubeDir
    c:\k\nssm set Kubelet AppParameters $global:KubeletStartFile
    c:\k\nssm set Kubelet DisplayName Kubelet
    c:\k\nssm set Kubelet Description Kubelet
    c:\k\nssm set Kubelet Start SERVICE_AUTO_START
    c:\k\nssm set Kubelet ObjectName LocalSystem
    c:\k\nssm set Kubelet Type SERVICE_WIN32_OWN_PROCESS
    c:\k\nssm set Kubelet AppThrottle 1500
    c:\k\nssm set Kubelet AppStdout C:\k\kubelet.log
    c:\k\nssm set Kubelet AppStderr C:\k\kubelet.err.log
    c:\k\nssm set Kubelet AppStdoutCreationDisposition 4
    c:\k\nssm set Kubelet AppStderrCreationDisposition 4
    c:\k\nssm set Kubelet AppRotateFiles 1
    c:\k\nssm set Kubelet AppRotateOnline 1
    c:\k\nssm set Kubelet AppRotateSeconds 86400
    c:\k\nssm set Kubelet AppRotateBytes 1048576

    # setup kubeproxy
    c:\k\nssm install Kubeproxy C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
    c:\k\nssm set Kubeproxy AppDirectory $global:KubeDir
    c:\k\nssm set Kubeproxy AppParameters $global:KubeProxyStartFile
    c:\k\nssm set Kubeproxy DisplayName Kubeproxy
    c:\k\nssm set Kubeproxy DependOnService Kubelet
    c:\k\nssm set Kubeproxy Description Kubeproxy
    c:\k\nssm set Kubeproxy Start SERVICE_AUTO_START
    c:\k\nssm set Kubeproxy ObjectName LocalSystem
    c:\k\nssm set Kubeproxy Type SERVICE_WIN32_OWN_PROCESS
    c:\k\nssm set Kubeproxy AppThrottle 1500
    c:\k\nssm set Kubeproxy AppStdout C:\k\kubeproxy.log
    c:\k\nssm set Kubeproxy AppStderr C:\k\kubeproxy.err.log
    c:\k\nssm set Kubeproxy AppRotateFiles 1
    c:\k\nssm set Kubeproxy AppRotateOnline 1
    c:\k\nssm set Kubeproxy AppRotateSeconds 86400
    c:\k\nssm set Kubeproxy AppRotateBytes 1048576
}

function
Set-Explorer
{
    # setup explorer so that it is usable
    New-Item -Path HKLM:"\\SOFTWARE\\Policies\\Microsoft\\Internet Explorer"
    New-Item -Path HKLM:"\\SOFTWARE\\Policies\\Microsoft\\Internet Explorer\\BrowserEmulation"
    New-ItemProperty -Path HKLM:"\\SOFTWARE\\Policies\\Microsoft\\Internet Explorer\\BrowserEmulation" -Name IntranetCompatibilityMode -Value 0 -Type DWord
    New-Item -Path HKLM:"\\SOFTWARE\\Policies\\Microsoft\\Internet Explorer\\Main"
    New-ItemProperty -Path HKLM:"\\SOFTWARE\\Policies\\Microsoft\\Internet Explorer\\Main" -Name "Start Page" -Type String -Value http://bing.com
}

try
{
    # Set to false for debugging.  This will output the start script to
    # c:\AzureData\CustomDataSetupScript.log, and then you can RDP
    # to the windows machine, and run the script manually to watch
    # the output.
    if ($true) {
        Write-Log "Provisioning $global:DockerServiceName... with IP $MasterIP"

        Write-Log "apply telemetry data setting"
        Set-TelemetrySetting

        Write-Log "resize os drive if possible"
        Resize-OSDrive

        Write-Log "download kubelet binaries and unzip"
        Get-KubeBinaries

        # This is a workaround until Windows update
        Write-Log "apply Windows patch packages"
        Update-WindowsPackages

        Write-Log "Write azure config"
        Write-AzureConfig

        {{if IsAzureStackCloud}}
        Write-Log "Write azure stack config"
        Write-AzureStackCloudConfig
        {{end}}

        Write-Log "Write kube config"
        Write-KubeConfig

        Write-Log "Create the Pause Container kubletwin/pause"
        New-InfraContainer

        Write-Log "Configure networking"
        Set-NetworkConfig

        Write-Log "write kubelet startfile with pod CIDR of $podCIDR"
        Write-KubernetesStartFiles $podCIDR

        Write-Log "install the NSSM service"
        New-NSSMService

        Write-Log "Set Internet Explorer"
        Set-Explorer

        Write-Log "Setup Complete, reboot computer"
        Restart-Computer
    }
    else
    {
        # keep for debugging purposes
        Write-Log ".\CustomDataSetupScript.ps1 -MasterIP $MasterIP -KubeDnsServiceIp $KubeDnsServiceIp -MasterFQDNPrefix $MasterFQDNPrefix -Location $Location -AgentKey $AgentKey -AzureHostname $AzureHostname -AADClientId $AADClientId -AADClientSecret $AADClientSecret"
    }
}
catch
{
    Write-Error $_
}
