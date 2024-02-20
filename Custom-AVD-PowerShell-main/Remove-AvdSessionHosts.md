## Remove-AvdSessionHosts

### Synopsis
This function deletes session hosts and removes metadata.

### Description
This function will do the following:
- Delete all virtual machines and supporting resources.
- Disable the scaling plan on the host pool.
- Remove virtual machines from the host pool.
- Notify users that they will be logged out in the specified time.
- Enable the scaling plan on the host pool.

This function requires both Azure PowerShell and Azure CLI to work properly.

### Parameters

- `HostPoolName`: The name of the host pool the virtual machine should be deployed into.
- `HostPoolResourceGroupName`: The resource group of the host pool.
- `PauseUserLogOffInMinutes`: If user accounts are logged in, this is how long the function should pause and send notifications. Defaults to 2 minutes.
- `UserLogOffMessage`: The message to send to users when asking them to log off. Not required.
- `UserLogOffMessageTitle`: The title of the message being sent to users.
- `DomainRemoveProperties`: An object for domain remove properties.

### Notes
- Version: 1.0
- Author: George Ollis

### Example
This example removes session hosts from the host pool “MyHostPool” in the resource group “myResourceGroup”.

This function is designed to be used with Azure and the Azure PowerShell module. Please ensure you have the necessary permissions and the Azure PowerShell module installed before running this function. If the function encounters an error while trying to run the command, it will write an error message to the console. The Azure CLI is also required for this function to work properly.

```powershell
Remove-AvdSessionHosts -HostPoolName "MyHostPool" -ResourceGroupName "myResourceGroup" -Verbose
