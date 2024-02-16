<#
PowerShell core.
PSVersion                      7.4.1
PSEdition                      Core

Required minimum installs

2.46.0                Azure CLI
5.0.1                 Az.Monitor
6.15.0                Az.Resources
7.4.0                 Az.Network
7.1.1                 Az.Compute
4.3.0                 Az.DesktopVirtualization


Author:               George Ollis

#> 


Function Stop-AvdDeployment {
    param (
        [Parameter(Mandatory = $true)][int]$seconds
    )

    $finishTime = (Get-Date).AddSeconds($seconds)
    while ($finishTime -gt (Get-Date)) {


        $secondsLeft = $finishTime.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)

    }
    Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining 0 -Completed
}

Function Deploy-AvdSessionHosts {
    <#
  .SYNOPSIS
  Deploys session host VMs

  .DESCRIPTION
  This function will deploy session host virtual machines for Azure Virtual Desktop.

  .PARAMETER VirtualMchineCount
  How many virtual machines do you want to deploy?

  .PARAMETER RandomAvailabilityZone
  Will select random AZ's between 1-3 for high availability within a region.

  .PARAMETER VirtualMachinePrefixName
  Virtual machine prefix names. 

  .PARAMETER EnableAzureMonitorAgent
  If true - will deploy the Azure Montior Agent on the virtual machine.

  .PARAMETER HostPoolName
  The name of the host pool the virtual machine should be deployed into.

  .PARAMETER HostPoolResourceGroupName
  The resource group of the host pool

  .PARAMETER ResourceGroupName
  The resource group the virtual machine should be deployed into.

  .PARAMETER SubnetId
  The subnet resource Id the virtual machine should be deployed into.

  .PARAMETER DomainJoinProperties
  Object for domain join properties.

  .PARAMETER VirtualMachineSize
  The size of the virtual machine being deployed.

  .PARAMETER VirtualMachineDiskType
  The disk SKU for the virtual machines. Allowed values.

  .PARAMETER SourceImageId
  The source image resource Id of the image being used for deployment.

  .PARAMETER VirtualMachineLocation
  The location of the virtual machine. Defaults to the region of the host pool.

  .PARAMETER VirtualMachineUsername
  The local administrator username. Defaults to avdadmin.

  .PARAMETER VirtualMachinePassword
  The local administrator password. Automatically generated if not provided.

  .PARAMETER Tags
  Tags that will be deployed to all resources. Virtual machines, disks, and network interfaces.

  .PARAMETER DataCollectionRuleId
  The data collection rule Id that should be assigned to the virtual machine.

  .PARAMETER CustomPowerShellExtensions
  String PowerShell scripts that can be used to run custom scripts post session host deployment.


  .EXAMPLE
   Deploy-AvdSessionHosts `
    -VirtualMachineCount 5 `
    -RandomAvailabilityZone $true `
    -VirtualMachinePrefixName "avdprod" `
    -EnableAzureMonitorAgent $true `
    -HostPoolName "azcprd-intl-hp01" `
    -HostPoolResourceGroupName "rg-avd-uks-service-objects-dw-01" `
    -ResourceGroupName "AVD_VM" `
    -SubnetId "/subscriptions/***********/resourceGroups/avd-prd-rg/providers/Microsoft.Network/virtualNetworks/azc-uks-avd-prd-vnet01/subnets/avd" `
    -VirtualMachineSize "Standard_D8s_v5" `
    -SourceImageId "/subscriptions/***********/resourceGroups/rg-avd-uks-shared-resources-dw-01/providers/Microsoft.Compute/galleries/azcprdcg01/images/gold_image/versions/2024.2.3" `
    -DataCollectionRuleId "/subscriptions/***********/resourceGroups/rg-avd-uks-monitoring-dw-01/providers/Microsoft.Insights/dataCollectionRules/azcprd-dcr-01" `
    -Verbose `
    -VirtualMachineDiskType "Premium_LRS" `
    -DomainJoinProperties @{
       Enabled           = $true
       DomainName        = ""
       OUPath            = ""
       UserPrincipalName = ""
       Password          = ""
     }

  .NOTES
  Version:        1.0
  Author:         George Ollis
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][int]$VirtualMachineCount,
        [Parameter(Mandatory = $false)][bool]$RandomAvailabilityZone,
        [Parameter(Mandatory = $true)]
        [ValidateLength(4, 10)][string]$VirtualMachinePrefixName = "avdvm",
        [Parameter(Mandatory = $false)][bool]$EnableAzureMonitorAgent = $false,
        [Parameter(Mandatory = $true)][string]$HostPoolName,
        [Parameter(Mandatory = $true)][string]$HostPoolResourceGroupName,
        [Parameter(Mandatory = $true)][string]$ResourceGroupName,
        [Parameter(Mandatory = $true)][string]$SubnetId,
        [Parameter(Mandatory = $false)]
        [hashtable]$DomainJoinProperties = @{
            Enabled           = [bool]$false
            DomainName        = [string]
            OUPath            = [string]
            UserPrincipalName = [string]
            Password          = [string]
        },
        [Parameter(Mandatory = $true)]
        [string]$VirtualMachineSize,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Standard_LRS", "Premium_LRS", "StandardSSD_LRS", "UltraSSD_LRS", "Premium_ZRS", "StandardSSD_ZRS", "PremiumV2_LRS")]
        [string]$VirtualMachineDiskType, 
        [Parameter(Mandatory = $false)][string]$VirtualMachineLocation,
        [Parameter(Mandatory = $true)][string]$SourceImageId,
        [Parameter(Mandatory = $false)][string]$VirtualMachineUsername = "avdadmin",
        [Parameter(Mandatory = $false)][securestring]$VirtualMachinePassword = (ConvertTo-SecureString (( -join ([char[]](33..122) | Get-Random -Count 16))) -AsPlainText -Force),
        [Parameter(Mandatory = $false)][Array]$Tags,
        [Parameter(Mandatory = $false)][string]$DataCollectionRuleId,
        [Parameter(Mandatory = $false)][System.Collections.ArrayList]$CustomPowerShellExtensions = @()
    )        

    begin {
        Write-Verbose "$($DataCollectionRuleId)"

        $RequiredModules = @("Az.Resources", "Az.Compute", "Az.Network", "Az.DesktopVirtualization", "Az.Monitor")
        $RequiredModules.ForEach({
                try {
                    Write-Verbose "Checking required modules installed $($_)"
                    Get-Module -ListAvailable $_ -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Error "Module depedencies not found. Cannot find $($_)"
                }
            })

        try {
            $checkAz = (az version | ConvertFrom-Json -ErrorAction Stop | Select-Object @{name = "cliVersion"; e = { $($_.'azure-cli') } })
            Write-Verbose "Message: Azure CLI installation found. Running $($checkAz.cliVersion)"
        }
        catch {
            Write-Error "Error: Cannot find Azure CLI install. Please ensure Azure CLI is installed."
        }

    }

    Process {
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

        Write-Verbose -Message "IMPORTANT: $($VirtualMachineCount) session hosts will be deployed and joined to the hostpool."

        try {
            $HostPoolGet = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $HostPoolResourceGroupName -ErrorAction Stop
            $HostPoolName = $HostPoolGet.Name
            $HostPoolResourceGroupName = $HostPoolGet.Id.Split("/")[4]
        }
        catch {
            Write-Error "Error: Unable to find Host Pool and Host Pool Resource Group."
            Return
        }

        if (Get-AzWvdScalingPlan | Where-Object { $_.HostPoolReference.HostPoolArmPath -contains $HostPoolGet.Id }) {
            Write-Verbose "Message: Scaling rule detected. Disabling the scaling plan temporarily."
            $HostPoolScalingPlanName = (Get-AzWvdScalingPlan | Where-Object { $_.HostPoolReference.HostPoolArmPath -contains $HostPoolGet.Id }).Name
            $HostPlanScalingPlanWasEnabled = $true
            Update-AzWvdScalingPlan -ResourceGroupName $HostPoolResourceGroupName -Name $HostPoolScalingPlanName -HostPoolReference @(@{'hostPoolArmPath' = $HostPoolGet.Id; 'scalingPlanEnabled' = $false }) | Out-Null 
        }
    
        try {
            $HostPoolRegistrationToken = New-AzWvdRegistrationInfo -ResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -ExpirationTime (Get-Date).AddDays(14) -ErrorAction Stop
            Write-Verbose "Success: Token has been generated."
        }
        catch {
            Write-Error "Error: Unable to generate registration token for AVD Host Pool. Resource Group: $HostPoolResourceGroupName ; Host pool: $HostPoolName"
            return
        }

        try {
            $Network = Get-AzResource -ResourceId $SubnetId -ErrorAction Stop
            $SubnetId = $Network.ResourceId
            Write-Verbose "Success: Subnet located: $SubnetId"
        }
        catch {
            Write-Error "Error: Unable to find subnet: $SubnetId"
        }

        try {
            $Image = Get-AzResource -ResourceId $SourceImageId -ErrorAction Stop
            $SourceImageId = $Image.ResourceId
            Write-Verbose "Success: Source image Id located: $SourceImageId"
        }
        catch {
            Write-Error "Error: Unable to find a source image id $($SourceImageId)."
        }

        if (!$VirtualMachineLocation) {
            Write-Verbose "Message: No location was provided during runtime. Default will be the same as the host pool: $($HostPoolGet.Location)"
            $VirtualMachineLocation = $HostPoolGet.Location
        }

        $SessionHostDeploymentConfig = [System.Collections.ArrayList]@()
        foreach ($VMInstane in 1..[int]$VirtualMachineCount) {
        
            if ($RandomAvailabilityZone) {
                $VMAvailabilityZone = Get-Random -Minimum 1 -Maximum 4
                Write-Verbose "Message: Selecting random availability zone: AZ: $VMAvailabilityZone"
            }

            $VirtualMachineRandom = -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ })
            $VirtualMachineName = $VirtualMachinePrefixName + $VirtualMachineRandom

            $DefaultTags = @(
                "HostPoolName=$($HostPoolName)",
                "HostPoolResoureGroupName=$HostPoolResourceGroupName"
                "CreationDate=$((Get-Date).ToString())"
            )
            $AllTags = @($DefaultTags + $Tags)

            $SessionHostConfig = [PSCustomObject]@{
                AvailabilityZone       = @{$true = $VMAvailabilityZone; $false = $null }[$RandomAvailabilityZone -eq $true]
                SubnetId               = $SubnetId
                ResourceGroupName      = $ResourceGroupName
                HostPoolName           = $HostPoolName
                HostResourceGroupName  = $HostPoolResourceGroupName
                SourceImageId          = $SourceImageId
                VirtualMachineLocation = $VirtualMachineLocation
                VirtualMachineName     = $VirtualMachineName
                VirtualMachineDiskType = $VirtualMachineDiskType
                VirtualMachineSize     = $VirtualMachineSize
                VirtualMachineUsername = $VirtualMachineUsername
                VirtualMachinePassword = (ConvertTo-SecureString $VirtualMachinePassword -AsPlainText -Force)
                Tags                   = $AllTags
                RegistrationToken      = ($HostPoolRegistrationToken.Token)
                VirtualMachineInstance = $VMInstane
            }

            $SessionHostDeploymentConfig.Add($SessionHostConfig) | Out-Null

            Write-Verbose ""
            Write-Verbose "Message: Configuration for the following session host..."
            Write-Verbose "##########!$VirtualMachineName - Configuration!##########"
            Write-Verbose "Virtual Machine Name: $($SessionHostConfig.VirtualMachineName)"
            Write-Verbose "Location: $($SessionHostConfig.VirtualMachineLocation)"
            Write-Verbose "HostPoolName: $($SessionHostConfig.HostPoolName)"
            Write-Verbose "HostPoolResourceGroupName: $($SessionHostConfig.HostResourceGroupName)"
            Write-Verbose "ResourceGroupName: $($SessionHostConfig.ResourceGroupName)"
            Write-Verbose "Instance: $VMInstane"
            Write-Verbose "##########!$VirtualMachineName - Configuration!##########"
            Write-Verbose ""
        }

        $SessionHostDeploymentConfig | Foreach-Object -ThrottleLimit $VirtualMachineCount -Parallel {
            Write-Verbose "Message: Attempting creation of $($PsItem.VirtualMachineName)"

            try {
              
                az vm create `
                    --resource-group $PSItem.ResourceGroupName `
                    --name $PSItem.VirtualMachineName `
                    --size $PSItem.VirtualMachineSize `
                    --computer-name $PSItem.VirtualMachineName `
                    --location $PSItem.VirtualMachineLocation `
                    --image $PSItem.SourceImageId `
                    --admin-username $PSItem.VirtualMachineUsername `
                    --admin-password $PSItem.VirtualMachinePassword `
                    --subnet $PSItem.SubnetId `
                    --zone $PSItem.AvailabilityZone `
                    --os-disk-size-gb 127 `
                    --storage-sku $PSItem.VirtualMachineDiskType `
                    --public-ip-address "" `
                    --nsg "" `
                    --tags $PsItem.Tags `
                    --os-disk-name "os-disk-$($PsItem.VirtualMachineName)" `
                    --only-show-errors `
                    --license-type "Windows_Client" `
                    --assign-identity [system] | Out-Null

                Write-Verbose "Message: Deployed virtual machine $($PSItem.VirtualMachineName)"
            }
            catch {
                Write-Error "Error: Deployment of session hosts has failed. Please review the logs generated."
            }
        }


        if ($DomainJoinProperties.Enabled) {

            Write-Verbose "Message: Pausing for 60 seconds..."
            Stop-AvdDeployment -Seconds 60
            Write-Verbose "Message: Attempting to join virtual machines to the domain..."
            Write-Verbose "`Domain join properties: UserPrincipalName: $($DomainJoinProperties.UserPrincipalName), DomainName: $($DomainJoinProperties.DomainName), OUPath: $($DomainJoinProperties.OUPath)"

            try {
                $Password = $(ConvertTo-SecureString $DomainJoinProperties.Password -AsPlainText -Force -ErrorAction Stop) 
                $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainJoinProperties.UserPrincipalName, $Password -ErrorAction Stop
            }
            catch {
                Write-Error "Error: Unable to set credential object for password. $($_.Exception.Message)"
            }

            $SessionHostDeploymentConfig | ForEach-Object -ThrottleLimit $VirtualMachineCount -Parallel {

                try {
    
                    Set-AzVMADDomainExtension `
                        -DomainName $using:DomainJoinProperties.DomainName `
                        -Credential $using:Credential `
                        -ResourceGroupName $PsItem.ResourceGroupName `
                        -VMName $PsItem.VirtualMachineName `
                        -Name "ADDSDomainJoin" `
                        -Location $PSItem.VirtualMachineLocation `
                        -OUPath $using:DomainJoinProperties.OUPath `
                        -JoinOption 0x00000003 `
                        -Restart `
                        -Verbose `
                        -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Error "Error: Unable to join domain. $($_.Exception.Message)"
                    Return
                }
    
    
    
            }

        }

        Write-Verbose "Message: Pausing for 60 seconds..."
        Write-Verbose "Message: Attempting to register virtual machines with the correct AVD Host Pool"
        Stop-AvdDeployment -Seconds 60

        $SessionHostDeploymentConfig | Foreach-Object -ThrottleLimit $VirtualMachineCount -Parallel {
            Write-Verbose "Message: Configuring $($PSItem.VirtualMachineName) for HostPool $($PsItem.HostPoolName) "
            try {

                $avdDscSettings = @{
                    Name               = "Microsoft.PowerShell.DSC"
                    Type               = "DSC" 
                    Publisher          = "Microsoft.Powershell"
                    typeHandlerVersion = "2.73"
                    SettingString      = "{
                        ""modulesUrl"":'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip',
                        ""ConfigurationFunction"":""Configuration.ps1\\AddSessionHost"",
                        ""Properties"": {
                            ""hostPoolName"": ""$($PsItem.HostPoolName)"",
                            ""registrationInfoToken"": ""$($PsItem.RegistrationToken)""
                        }
                    }"
                    VMName             = $PsItem.VirtualMachineName
                    ResourceGroupName  = $PsItem.ResourceGroupName
                    location           = $PsItem.VirtualMachineLocation
                    ErrorAction        = "Stop"
                } 

                Set-AzVMExtension @avdDscSettings | Out-Null
                Write-Verbose "Message: Session host $($PsItem.VirtualMachineName) has been registered with Host Pool: $($Psitem.HostPoolName)"
            
            }
            catch {
                Write-Error "Error: Joining host pools has failed. Virtual machine $($PSItem.VirtualMachineName)"
                Return
            }
        }


        if ($EnableAzureMonitorAgent) {
            
            Write-Verbose "Message: Pausing for 60 seconds..."
            Write-Verbose "Message: Azure Monitor Agent has been set to true. Attempting installation..."
            Stop-AvdDeployment -Seconds 60

            $SessionHostDeploymentConfig | Foreach-Object -ThrottleLimit $VirtualMachineCount -Parallel {
                
                try {
                    Set-AzVMExtension `
                        -ExtensionName "AzureMonitorWindowsAgent" `
                        -ExtensionType "AzureMonitorWindowsAgent" `
                        -Publisher "Microsoft.Azure.Monitor" `
                        -ResourceGroupName $PsItem.ResourceGroupName `
                        -VmName $PsItem.VirtualMachineName `
                        -Location ($PsItem.VirtualMachineLocation).toString() `
                        -TypeHandlerVersion 1.0 `
                        -ErrorAction SilentlyContinue | Out-Null
                }
                catch {
                    Write-Error "Error: Installation of Azure Monitor Agent has failed. $($_.Exception.Message)"
                }
            }

        }

        if ($DataCollectionRuleId) {
                Write-Verbose "Message: Data collection rule Id provided. $DataCollectionRuleId"
                
            try {
                Write-Verbose "Message: Getting the data collection rule."
                $DataCollection = Get-AzResource -Id $DataCollectionRuleId -ErrorAction Stop -Verbose
                Write-Verbose "Message: Data rule found collection $($DataCollection.ResourceId)"

                if ($DataCollection.ResourceId) {

                    Foreach ($VirtualMachine in $SessionHostDeploymentConfig) {

                        Write-Verbose "$($VirtualMachine.VirtualMachineName)"
                        Write-Verbose "$($DataCollection.ResourceId)"
                        Write-Verbose "$($VirtualMachine.ResourceGroupName)"  

                        New-AzDataCollectionRuleAssociation `
                             -AssociationName  "avdVmAssoc" `
                             -ResourceUri (Get-AzVm -Name $VirtualMachine.VirtualMachineName -ResourceGroupName $VirtualMachine.ResourceGroupName).Id `
                             -DataCollectionRuleId $DataCollection.ResourceId `
                             -ErrorAction SilentlyContinue `
                             -Verbose | Out-Null

                    }

                }

            }
            catch {
                Write-Error "Error: Unable to find the data collection rule. $($_.Exception.Message)"
            }
        }

        if ($CustomPowerShellExtensions) {

            Write-Verbose "Message: Custom script string provided. Attempting to run the scripts on the local machines."

            $SessionHostDeploymentConfig | Foreach-Object -ThrottleLimit $VirtualMachineCount -Parallel {
                
                Foreach ($script in $using:CustomPowerShellExtensions) {

                    Write-Verbose "Message: Running the following script on $($PsItem.VirtualMachineName): $script"

                    try {
                        Invoke-AzVMRunCommand `
                            -ResourceGroupName $PsItem.ResourceGroupName `
                            -VmName $PsItem.VirtualMachineName `
                            -ScriptString $script `
                            -CommandId "RunPowerShellScript" `
                            -ErrorAction SilentlyContinue `
                            -Verbose | Out-Null
                    }
                    catch {
                        Write-Error "Error: Custom script has failed. $($_.Exception.Message)"
                    }
                }

               
            }
        }

        if ($HostPlanScalingPlanWasEnabled) {
            
            Write-Verbose "Message: Enabling the scaling plan. $HostPoolScalingPlanName"
            
            Update-AzWvdScalingPlan `
                -ResourceGroupName $HostPoolResourceGroupName `
                -Name  $HostPoolScalingPlanName `
                -HostPoolReference @(
                @{
                    'hostPoolArmPath'    = $HostPoolGet.Id;
                    'scalingPlanEnabled' = $true
                }
            ) | Out-Null 
        }

        $stopWatch.Stop()
        Write-Verbose "Message: Deployment completed. Total run duration in minutes $($stopWatch.Elapsed.TotalMinutes)"
        return $SessionHostDeploymentConfig

    }
    
}


function Remove-AvdSessionHosts {
    <#
  .SYNOPSIS
  Deletes session hosts and removes metadata

  .DESCRIPTION 
  This function will do the following: 
  - Delete all virtual machines and supporting resources.
  - Disables the scaling plan on the hostpool
  - Remove virtual machines from the host pool.
  - Notify users that they will be logged out in the specified time.
  - Enables the scaling plan on the hostpool


  .PARAMETER HostPoolName
  The name of the host pool the virtual machine should be deployed into.

  .PARAMETER HostPoolResourceGroupName
  The resource group of the host pool

  .PARAMETER PauseUserLogOffInMinutes
  If user accounts are logged in - how long should the function pause and send notifications. Defaults to 2 minutes.

  .PARAMETER UserLogOffMessage
  The message to send to users when asking them to log off. Not required.

  .PARAMETER UserLogOffMessageTitle
  The title of the message being sent to users.


  .EXAMPLE
  Remove-AvdSessionHosts -HostPoolName "MyHostPool" -ResourceGroupName "myResourceGroup" -Verbose


  .NOTES
  Version:        1.0
  Author:         George Ollis
#>



    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$HostPoolName,
        [Parameter(Mandatory = $true)][string]$HostPoolResourceGroupName,
        [Parameter(Mandatory = $false)][int]$PauseUserLogOffInMinutes = 2,
        [Parameter(Mandatory = $false)][string]$UserLogOffMessage,
        [Parameter(Mandatory = $false)][string]$UserLogOffMessageTitle

    )
    

    Begin {

        $RequiredModules = @("Az.Resources", "Az.Compute", "Az.Network", "Az.DesktopVirtualization", "Az.Monitor")
        $RequiredModules.ForEach({
                try {
                    Write-Verbose "Checking required modules installed $($_)"
                    Get-Module -ListAvailable $_ -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Error "Module depedencies not found. Cannot find $($_)"
                    Return
                }
            })
    
    }

    process {

        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $HostPoolGet = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $HostPoolResourceGroupName -ErrorAction Stop
            $HostPoolName = $HostPoolGet.Name
            $HostPoolResourceGroupName = $HostPoolGet.Id.Split("/")[4]
        }
        catch {
            Write-Error "Error: Unable to find Host Pool and Host Pool Resource Group."
            Return
        }

        if (Get-AzWvdScalingPlan | Where-Object { $_.HostPoolReference.HostPoolArmPath -contains $HostPoolGet.Id }) {
            Write-Verbose "Message: Scaling rule detected. Disabling the scaling plan temporarily."
            $HostPoolScalingPlanName = (Get-AzWvdScalingPlan | Where-Object { $_.HostPoolReference.HostPoolArmPath -contains $HostPoolGet.Id }).Name
            $HostPlanScalingPlanWasEnabled = $true
            Update-AzWvdScalingPlan -ResourceGroupName $HostPoolResourceGroupName -Name $HostPoolScalingPlanName -HostPoolReference @(@{'hostPoolArmPath' = $HostPoolGet.Id; 'scalingPlanEnabled' = $false }) | Out-Null 
        }

        try {
            $AvdSessionHosts = Get-AzWvdSessionHost -ResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -ErrorAction Stop | 
            Select-Object name, ResourceId, @{name = "Status"; e = { $_.Status } }, 
            @{name = "HostPoolName"; e = { $($_.Name).Split("/")[0] } }, 
            @{name = "SessionHost"; e = { $($_.Name).Split("/")[1] } }
        }
        catch {
            Write-Error "Error: Unable to get session hosts for $HostPoolName."
            Return
        }

        try {
            $AvdUserSessions = Get-AzWvdUserSession -HostPoolName $HostPoolName -ResourceGroupName $HostPoolResourceGroupName -ErrorAction Stop | 
            Select-Object @{name = "HostPoolName"; e = { $($_.Name).split("/")[0] } }, 
            @{name = "SessionHost"; e = { $($_.Name).split("/")[1] } }, 
            @{name = "UserSessionId"; e = { $($_.Name).split("/")[2] } }
        }
        catch {
            Write-Error "Error: Unable to get user sessions for $HostPoolName."
            Return
        }


        if ($AvdUserSessions) {

            $TimeNow = Get-Date
            $FutureTime = (Get-Date).AddMinutes($PauseUserLogOffInMinutes)

            if (!$UserLogOffMessage) {
                $UserLogOffMessage = "
                `nThe virtual machine will be deleted at $FutureTime.
                `nPlease ensure that you save your work and log out. Essential maintenance is being applied to all sessions in $PauseUserLogOffInMinutes minute(s). 
                `nOnce logged out, please allow up to 10 minutes and try again. If you do not log out in the time specified, you will be automatically logged out."
            }

            if (!$UserLogOffMessageTitle) {
                $UserLogOffMessageTitle = "Important notification!"
            }

            While ($TimeNow -lt $FutureTime) {
                $TimeNow = Get-Date
                Foreach ($AvdUserSession in $AvdUserSessions) {
                    Write-Verbose "Message: Sending notification to user $($AvdUserSession.UserSessionId) on $($AvdUserSession.SessionHost)"
                    
                    Send-AzWvdUserSessionMessage `
                        -HostPoolName $HostPoolName `
                        -ResourceGroupName $HostPoolResourceGroupName `
                        -UserSessionId $AvdUserSession.UserSessionId `
                        -SessionHostName $AvdUserSession.SessionHost `
                        -MessageBody $UserLogOffMessage `
                        -MessageTitle $UserLogOffMessageTitle `
                        -ErrorAction "SilentlyContinue"
                }

                Stop-AvdDeployment(60)
    
            }
                  
            foreach ($user in $AvdUserSessions) {
                            
                if ($user.SessionHost -in $AvdSessionHosts.SessionHost) {

                    Send-AzWvdUserSessionMessage `
                        -HostPoolName $HostPoolName `
                        -ResourceGroupName $HostPoolResourceGroupName `
                        -UserSessionId $user.UserSessionId `
                        -SessionHostName $user.SessionHost `
                        -MessageBody "You are being logged out in 10 seconds..." `
                        -MessageTitle "Critical notification!" `
                        -ErrorAction "SilentlyContinue"

                    Stop-AvdDeployment -seconds 10

                    Remove-AzWvdUserSession `
                        -HostPoolName $HostPoolName `
                        -ResourceGroupName $HostPoolResourceGroupName `
                        -Id $user.UserSessionId `
                        -SessionHostName $user.SessionHost `
                        -Force
            
                    Write-Verbose "Message: Removing user session $($user.UserSessionId) on session host $($user.SessionHost)"
                }
            }


        }

        if ($AvdSessionHosts) {
            
            $AvdSessionHosts | ForEach-Object {

                try {
                    $VirtualMachine = Get-AzVm -ResourceId $PsItem.ResourceId -ErrorAction Stop
                }
                catch {
                    Write-Error "Error: Unable to get virtual machine. $($_.Exception.Message)"
                }

                try {
                    Write-Verbose "Message: Deleting session host: $($PsItem.SessionHost)"
                    Remove-AzVM -Id $VirtualMachine.Id -ForceDeletion $true -ErrorAction Stop -Force | Out-Null
                }
                catch {
                    Write-Error "Error: Unable to delete $($PSItem.SessionHost). $($_.Exception.Message)"
                    Write-Error "Error: Stopping script and returning."
                    Return
                }


                foreach ($nicUri in $VirtualMachine.NetworkProfile.NetworkInterfaces.Id) {
                    try {
                        $nic = Get-AzNetworkInterface -ResourceGroupName $VirtualMachine.ResourceGroupName -Name $nicUri.Split('/')[-1] -ErrorAction SilentlyContinue
                        Write-Verbose "Message: Deleting network interface card $($nic.Id)"
                        Remove-AzNetworkInterface -Name $nic.Name -ResourceGroupName $VirtualMachine.ResourceGroupName -Force -ErrorAction SilentlyContinue | Out-Null
                        Write-Verbose "Message: Deleted $($nic.Id)"
                    }
                    catch {
                        Write-Error "Error: Unable to delete network interface card $($nic.Id)" 
                    }
                }


                foreach ($osDiskResourceId in $VirtualMachine.StorageProfile.OsDisk.ManagedDisk.Id) {
                    try {
                        Write-Verbose "Message: Deleting os disk $osDiskResourceId."
                        $osDisk = Get-AzResource -ResourceId $osDiskResourceId
                        Remove-AzResource -ResourceId $OsDisk.Id -Force -ErrorAction SilentlyContinue | Out-Null
                        Write-Verbose "Message: Deleted $osDiskResourceId"
                    }
                    catch {
                        Write-Error "Error: Unable to os disk. Please remove manually." 
                    }
                }

                try {
                    Write-Verbose "Message: Removing $($PsItem.SessionHost) from Azure Virtual Desktop Hostpool."
                    Remove-AzWvdSessionHost -HostPoolName $HostPoolName `
                        -Name $PsItem.SessionHost `
                        -ResourceGroupName $HostPoolResourceGroupName `
                        -Force `
                        -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Verbose "Error: Unable to remove session host $($PsItem.SessionHost) from $HostPoolName. $($_.Exception.Message)"
                }               
            
            }

            if ($HostPlanScalingPlanWasEnabled) {
            
                Write-Verbose "Message: Enabling the scaling plan. $HostPoolScalingPlanName"
                
                Update-AzWvdScalingPlan `
                    -ResourceGroupName $HostPoolResourceGroupName `
                    -Name  $HostPoolScalingPlanName `
                    -HostPoolReference @(
                    @{
                        'hostPoolArmPath'    = $HostPoolGet.Id;
                        'scalingPlanEnabled' = $true
                    }
                ) | Out-Null 
            }

            $stopWatch.Stop()
            Write-Verbose "Message: Sessions hosts deleted. Total run duration in minutes $($stopWatch.Elapsed.TotalMinutes)"


        }
    }
}

function Restart-AvdSessionHosts {
    <#
  .SYNOPSIS
  Restarts all virtual machines in a host pool.

  .DESCRIPTION
  The function will restart all active running virtual machines in a hostpool. Used for troubleshooting and schedules.

  .PARAMETER HostPoolName
  The name of the host pool the virtual machine should be deployed into.

  .PARAMETER HostPoolResourceGroupName
  The resource group of the host pool

  .PARAMETER ForceTurnOn
  Setting force turn on to true will turn on any virtual machines currently deallocated in the pool. Useful when need to ensure all virtual machines are running.

  .EXAMPLE
  Restart-AvdSessionHosts -HostPoolName "MyHostPool" -HostPoolResourceGroupName "myResourceGroup" -Verbose

  .NOTES
  Version:        1.0
  Author:         George Ollis
#>

    param (
        [Parameter(Mandatory = $true)][string]$HostPoolName,
        [Parameter(Mandatory = $true)][string]$HostPoolResourceGroupName,
        [Parameter(Mandatory = $false)][bool]$ForceTurnOn = $false
    )

    begin {


        $RequiredModules = @("Az.Resources", "Az.Compute", "Az.Network", "Az.DesktopVirtualization", "Az.Monitor")
        $RequiredModules.ForEach({
                try {
                    Write-Verbose "Checking required modules installed $($_)"
                    Get-Module -ListAvailable $_ -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Error "Module depedencies not found. Cannot find $($_)"
                }
            })

        try {
            $checkAz = (az version | ConvertFrom-Json -ErrorAction Stop | Select-Object @{name = "cliVersion"; e = { $($_.'azure-cli') } })
            Write-Verbose "Message: Azure CLI installation found. Running $($checkAz.cliVersion)"
        }
        catch {
            Write-Error "Error: Cannot find Azure CLI install. Please ensure Azure CLI is installed."
        }
    }

    process {
        try {
            $HostPoolGet = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $HostPoolResourceGroupName -ErrorAction Stop
            $HostPoolName = $HostPoolGet.Name
            $HostPoolResourceGroupName = $HostPoolGet.Id.Split("/")[4]
        }
        catch {
            Write-Error "Error: Unable to find Host Pool and Host Pool Resource Group."
            Return
        }
    
        if (Get-AzWvdScalingPlan | Where-Object { $_.HostPoolReference.HostPoolArmPath -contains $HostPoolGet.Id }) {
            Write-Verbose "Message: Scaling rule detected. Disabling the scaling plan temporarily."
            $HostPoolScalingPlanName = (Get-AzWvdScalingPlan | Where-Object { $_.HostPoolReference.HostPoolArmPath -contains $HostPoolGet.Id }).Name
            $HostPlanScalingPlanWasEnabled = $true
            Update-AzWvdScalingPlan -ResourceGroupName $HostPoolResourceGroupName -Name $HostPoolScalingPlanName -HostPoolReference @(@{'hostPoolArmPath' = $HostPoolGet.Id; 'scalingPlanEnabled' = $false }) | Out-Null 
        }

        try {
            Write-Verbose "Message: Attempting to get Host Pool properties $($HostPoolName)"
            $AvdSessionHosts = Get-AzWvdSessionHost -ResourceGroupName $HostPoolResourceGroupName -HostPoolName $HostPoolName -ErrorAction Stop | 
            Select-Object name, ResourceId, @{name = "Status"; e = { $_.Status } }, 
            @{name = "HostPoolName"; e = { $($_.Name).Split("/")[0] } }, 
            @{name = "SessionHost"; e = { $($_.Name).Split("/")[1] } }
        }
        catch {
            Write-Error "Error: Unable to get session hosts for $HostPoolName."
            Return
        }

        If ($AvdSessionHosts) {

            Write-Verbose "HostPoolName: $($HostPoolName)"
            Write-Verbose "HostPoolResourceGroupName: $($HostPoolName)"
            Write-Verbose "ForceTurnOn: $($ForceTurnOn)"

            if ($ForceTurnOn) {

                $AvdSessionHosts | ForEach-Object {

                    try {
                        Write-Verbose "Message: Getting virtual machine object properties."
                        $VM = Get-AzVM -ResourceId $PsItem.ResourceId -Status | Select-Object @{name = "VMStatus"; e = { $($_.statuses.displayStatus[1]) } }, name, resourceGroupName -ErrorAction Stop
                        Write-Verbose "Message: Virtual machine located $($VM.Name)"
                    }
                    catch {
                        Write-Error "Error: Unable to locate virtual machine $($sessionHost.ResourceId)"
                    }
    
                    Write-Verbose "Message: Force Turn On set to true. Turning on deallocated virtual machines."
                    
                    if ($VM.VMStatus -eq "VM deallocated") {
                        Write-Verbose "Message: Starting $($VM.Name)..."
                        Start-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -AsJob | Out-Null
                        
                        while ((Get-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Status | Select-Object @{name = "VMStatus"; e = { $($_.statuses.displayStatus[1]) } }).VMStatus -ne "VM running") {
                            Write-Verbose "Message: Pausing deployment. Waiting for $($VM.Name) to turn online."
                            Stop-AvdDeployment -seconds 10
                        }
                        
                        Write-Verbose "Message: $($VM.Name) started."
                    }
                }

            }

            $AvdSessionHosts | ForEach-Object {

                try {
                    Write-Verbose "Message: Getting virtual machine object properties."
                    $VM = Get-AzVM -ResourceId $PsItem.ResourceId -Status | Select-Object @{name = "VMStatus"; e = { $($_.statuses.displayStatus[1]) } }, name, resourceGroupName -ErrorAction Stop
                    Write-Verbose "Message: Virtual machine located $($VM.Name)"
                }
                catch {
                    Write-Error "Error: Unable to locate virtual machine $($sessionHost.ResourceId)"
                }

                if ($VM.VMStatus -eq "VM running") {
                    Write-Verbose "Virtual machine $($VM.Name) is running. Attempting to restart"
                    try {
                        Restart-AZvM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName | Out-Null
                        Write-Verbose "$($VM.Name) is restarting..."
                    }
                    catch {
                        Write-Error "Message: Unable to restart the virtual machine $($_.Exception.Message)"
                    }
                }
            }
        }

        if ($HostPlanScalingPlanWasEnabled) {
            
            Write-Verbose "Message: Enabling the scaling plan. $HostPoolScalingPlanName"
                
            Update-AzWvdScalingPlan `
                -ResourceGroupName $HostPoolResourceGroupName `
                -Name  $HostPoolScalingPlanName `
                -HostPoolReference @(
                @{
                    'hostPoolArmPath'    = $HostPoolGet.Id;
                    'scalingPlanEnabled' = $true
                }
            ) | Out-Null 
        }
    }
}

function Remove-AcgImageVersions {
<#
  .SYNOPSIS
  Remove old image versions in the Azure Compute Gallery.

  .DESCRIPTION
  Function will delete image versions based on the imageVersionsKeep parameter.

  .PARAMETER AzureComputeGalleryName
  The name of the Azure Compute Gallery.

  .PARAMETER AzureComputeGalleryResourceGroupName
  The name of the resource group where the Azure Compute Gallery Resource

  .PARAMETER AzureComputeGalleryImageName
  The version of the image in the Azure Compute Gallery name.

  .PARAMETER VersionsToKeep
  The number of image versions to keep. Always deletes the oldest versions.

  .EXAMPLE
  Remove-AcgImageVersions -AzureComputeGalleryName "GalleryName" -AzureComputeGalleryResourceGroupName "MyResourceGroup" -AzureComputeGalleryImageName "image_version" -Verbose

  .NOTES
  Version:        1.0
  Author:         George Ollis
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$AzureComputeGalleryName,
        [Parameter(Mandatory = $true)][string]$AzureComputeGalleryResourceGroupName,
        [Parameter(Mandatory = $true)][string]$AzureComputeGalleryImageName,
        [Parameter(Mandatory = $false)][int]$VersionsToKeep = 5
    )
    
    begin {
        $RequiredModules = @("Az.Resources", "Az.Compute", "Az.Network", "Az.DesktopVirtualization", "Az.Monitor")
        $RequiredModules.ForEach({
                try {
                    Write-Verbose "Checking required modules installed $($_)"
                    Get-Module -ListAvailable $_ -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Error "Module depedencies not found. Cannot find $($_)"
                }
            })

        try {
            $checkAz = (az version | ConvertFrom-Json -ErrorAction Stop | Select-Object @{name = "cliVersion"; e = { $($_.'azure-cli') } })
            Write-Verbose "Message: Azure CLI installation found. Running $($checkAz.cliVersion)"
        }
        catch {
            Write-Error "Error: Cannot find Azure CLI install. Please ensure Azure CLI is installed."
        }

    }
    
    process {

        try {
            Write-Verbose "Message: Locating Azure Compute Gallery and Image Name."

            $imageVersions = az sig image-version list `
                --gallery-name $AzureComputeGalleryName `
                --resource-group $AzureComputeGalleryResourceGroupName `
                --gallery-image-name $AzureComputeGalleryImageName `
                --query "reverse(sort_by([].{name:name, date:publishingProfile.publishedDate}, &date))" `
            | Out-String | ConvertFrom-Json -ErrorAction Stop | Sort-Object -Property Date -Descending | Select-Object -Skip $VersionsToKeep 

            if ($imageVersions) {
                Write-Verbose "Message: Image versions detected that can be deleted."

                $imageVersions.ForEach({
                        Write-Verbose "Message: Found an image version to be deleted. Deleting old image version: $($_.name) with Date: $($_.date)"
                        az sig image-version delete `
                            --gallery-image-name $AzureComputeGalleryImageName `
                            --gallery-image-version $($_.name) `
                            --gallery-name $AzureComputeGalleryName `
                            --resource-group $AzureComputeGalleryResourceGroupName
                        Write-Verbose "Message: Image version $($_.name) has been deleted."
                    }
                        
                )
            }

        }
        catch {
            Write-Error "Error: Unable to remove images. $($_.Exception.Message)"
        }
     
    }
    
}
