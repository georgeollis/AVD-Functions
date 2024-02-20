## Remove-AcgImageVersions

### Synopsis
This function removes old image versions in the Azure Compute Gallery.

### Description
The function will delete image versions based on the `VersionsToKeep` parameter.

### Parameters

- `AzureComputeGalleryName`: The name of the Azure Compute Gallery.
- `AzureComputeGalleryResourceGroupName`: The name of the resource group where the Azure Compute Gallery Resource is located.
- `AzureComputeGalleryImageName`: The version of the image in the Azure Compute Gallery name.
- `VersionsToKeep`: The number of image versions to keep. Always deletes the oldest versions.

### Notes

- Version: 1.0
- Author: George Ollis



### Example

This example removes old image versions from the Azure Compute Gallery named “GalleryName” in the resource group “MyResourceGroup”. The image version “image_version” is used for the operation.

This function is designed to be used with Azure and the Azure PowerShell module. Please ensure you have the necessary permissions and the Azure PowerShell module installed before running this function.

```powershell
Remove-AcgImageVersions -AzureComputeGalleryName "GalleryName" -AzureComputeGalleryResourceGroupName "MyResourceGroup" -AzureComputeGalleryImageName "image_version" -Verbose


