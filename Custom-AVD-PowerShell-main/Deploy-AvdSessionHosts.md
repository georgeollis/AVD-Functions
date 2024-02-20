## Deploy-AvdSessionHosts

### Synopsis
This function deploys session host VMs for Azure Virtual Desktop.

### Description
The function will deploy session host virtual machines based on the parameters provided.

### Parameters

- `VirtualMachineCount`: The number of virtual machines you want to deploy.
- `RandomAvailabilityZone`: If set to true, the function will select random Availability Zones between 1-3 for high availability within a region.
- `VirtualMachinePrefixName`: The prefix for the virtual machine names.
- `EnableAzureMonitorAgent`: If set to true, the Azure Monitor Agent will be deployed on the virtual machine.
- `HostPoolName`: The name of the host pool the virtual machine should be deployed into.
- `HostPoolResourceGroupName`: The resource group of the host pool.
- `ResourceGroupName`: The resource group the virtual machine should be deployed into.
- `SubnetId`: The subnet resource Id the virtual machine should be deployed into.
- `DomainJoinProperties`: An object for domain join properties.
- `VirtualMachineSize`: The size of the virtual machine being deployed.
- `VirtualMachineDiskType`: The disk SKU for the virtual machines.
- `SourceImageId`: The source image resource Id of the image being used for deployment.
- `VirtualMachineLocation`: The location of the virtual machine. Defaults to the region of the host pool.
- `VirtualMachineUsername`: The local administrator username. Defaults to avdadmin.
- `VirtualMachinePassword`: The local administrator password. Automatically generated if not provided.
- `Tags`: Tags that will be deployed to all resources. Virtual machines, disks, and network interfaces.
- `DataCollectionRuleId`: The data collection rule Id that should be assigned to the virtual machine.
- `CustomPowerShellExtensions`: String PowerShell scripts that can be used to run custom scripts post session host deployment.

### Example

This example deploys 5 session host VMs with the prefix “avdprod” into the host pool “azcprd-intl-hp01” in the resource group “rg-avd-uks-service-objects-dw-01”. The VMs are deployed into the specified subnet and use the specified image for deployment. The Azure Monitor Agent is enabled, and the VMs are joined to a domain.

### Notes

- Version: 1.0
- Author: George Ollis
- This function is designed to be used with Azure and the Azure PowerShell module. Please ensure you have the necessary permissions and the Azure PowerShell module installed before running this function. If the function encounters an error while trying to run the command, it will write an error message to the console.

```powershell
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
