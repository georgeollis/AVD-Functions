## Remove-AvdSessionHostFromDomain

### Synopsis
This function removes a specified Azure Virtual Desktop (AVD) Session Host from a domain.

### Description
The function uses the Invoke-AzVMRunCommand cmdlet to run a script on the specified virtual machine. The script is expected to remove the virtual machine from the domain.

### Parameters

- `VirtualMachineName`: The name of the virtual machine to be removed from the domain.
- `ResourceGroupName`: The name of the resource group where the virtual machine is located.
- `DomainUserName`: The username of the domain user who has the necessary permissions to remove the machine from the domain.
- `DomainPassword`: The password of the domain user.
- `LocalScriptPath`: The local path to the script that will be run on the virtual machine to remove it from the domain.

### Notes
Author: George Ollis
Version: 1.0

This function is designed to be used with Azure and the Azure PowerShell module. Please ensure you have the necessary permissions and the Azure PowerShell module installed before running this function. Also, make sure the script at the LocalScriptPath is designed to remove a machine from a domain and can accept the DomainUserName and DomainPassword parameters. If the function encounters an error while trying to run the command, it will write an error message to the console.


### Example

```powershell
Remove-AvdSessionHostFromDomain -VirtualMachineName "vm1" -ResourceGroupName "rg1" -DomainUserName "user1" -DomainPassword "password1" -LocalScriptPath "C:\\Scripts\\RemoveFromDomain.ps1"

This example removes the virtual machine named “vm1” in the resource group “rg1” from the domain. The script at “C:\Scripts\RemoveFromDomain.ps1” is run on the virtual machine to perform the removal.
