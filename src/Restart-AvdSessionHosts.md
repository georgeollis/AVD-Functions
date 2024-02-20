## Restart-AvdSessionHosts

### Synopsis
This function restarts all virtual machines in a host pool.

### Description
The function will restart all active running virtual machines in a host pool. This is useful for troubleshooting and scheduling purposes. This function requires both Azure PowerShell and Azure CLI to work properly.

### Parameters

- `HostPoolName`: The name of the host pool where the virtual machine should be deployed.
- `HostPoolResourceGroupName`: The resource group of the host pool.
- `ForceTurnOn`: If set to true, any virtual machines currently deallocated in the pool will be turned on. This is useful when you need to ensure all virtual machines are running.

### Notes
- Version: 1.0
- Author: George Oll


### Example
This example restarts all active running virtual machines in the host pool named “MyHostPool” in the resource group “myResourceGroup”.
This function is designed to be used with Azure and the Azure PowerShell module. Please ensure you have the necessary permissions and the Azure PowerShell module installed before running this function. If the function encounters an error while trying to run the command, it will write an error message to the console. The Azure CLI is also required for this function to work properly.



```powershell
Restart-AvdSessionHosts -HostPoolName "MyHostPool" -HostPoolResourceGroupName "myResourceGroup" -Verbose
