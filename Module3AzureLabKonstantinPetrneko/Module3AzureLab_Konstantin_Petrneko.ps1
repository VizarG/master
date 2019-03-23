#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
<#                   Description
This script creates: a) resource group
                     b) storage account and upload files (name of storage is creating by function),
                     c) web app with one addition slot and service plan 
                     d) name of the web app is provided by the function from main arm template to web arm template 
#>
#how to run  .\Module3AzureLab_Konstantin_Petrneko.ps1
# Parameters for my script 
param (
    # Parameter for location of storage 
    [Parameter(Mandatory = $false)]
    [string]
    $Location = "eastus",
    # Parameter name of the container
    [Parameter(Mandatory = $false)]
    [string]
    $ContainerName = "quickstartblobs",
    # Parameter name of the resource group
    [Parameter(Mandatory = $false)]
    [string]
    $ResourceGroup = "myResourceGroup",
    # Parameter subscription to which you want to connect 
    [Parameter(Mandatory = $false)]
    [string]
    $Mysubscription = "Konstantin_Petrenko@epam.com"
)

# $Credentials = Get-Credential
# #connect to my subscription
# Connect-AzAccount -Subscription $Mysubscription -Credential $Credentials

#Start of creating of uniq name for the storage with nedeed lenght ps(you can set lenth that you want it's up to you)
function Get-RandomCharacters {

    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $false , HelpMessage = "enter the lenghts of the password ", ValueFromPipeline)]
        [int] $namelenght = 5,
        [Parameter(Mandatory = $false , HelpMessage = "enter the line of the paswword ")]
        [String] $str1 = 'abcdefghijklmnopqrstuvwxyz',
        [Parameter(Mandatory = $false , HelpMessage = "enter the line of the paswword ")]
        [String] $str2 = '1234567890'    
    )
    Begin {Write-Verbose "Start creating of unic name of the storage account"}
    Process {
        $random = 3..$namelenght | ForEach-Object { Get-Random -Maximum $str1.length } 
        $private:ofs = "" 
        $random2 = 1..2 | ForEach-Object { Get-Random -Maximum $str2.length } 
        $private:ofs = ""
        # delete space between characters 
        return [String]$str1[$random] + $str2[$random2]
    }
    End {Write-Verbose "End creating of unic name of the storage account"}
}
#End of creating of uniq name for the storage with nedeed lenght ps(you can set lenth that you want it's up to you)
$storageName = [string]@()
$storageName = 10 , 15  | Get-RandomCharacters 

#creating resourses in powershell :  a) resource group
#                                    b) storage account with blob,
#region
# this is the creating of new resourse group and checking if it exist
$GetArtResourceGroup = Get-AzResourceGroup -Name  $ResourceGroup -ErrorAction SilentlyContinue
if (!$GetArtResourceGroup) {
    Write-Host "Resource group '$ResourceGroup' does not exist.";
    Write-Host "Creating resource group '$ResourceGroup' in location '$Location'";
    New-AzResourceGroup -Name $ResourceGroup -Location $location
}
else {
    Write-Host "Using existing resource group '$ResourceGroup'";
}

# this is the creating of new storage account and checking if it exist
$GetStorageAccount = get-AzStorageAccount -Name $storageName[1] -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
if (!$GetStorageAccount) {
    Write-Host "Storrage account $storageName[1] does not exist.";
    Write-Host "Creating storage account $storageName[1] in resource group '$ResourceGroup'";
    $storageAccount = New-AzStorageAccount -Name ($storageName[1]).ToLower() `
        -ResourceGroupName $ResourceGroup `
        -SkuName Standard_LRS `
        -Location $Location
}
    
else {
    Write-Host "Using existing storage account $storageName[1]";
}
#get context of storage account    
$storageAccount = Get-AzStorageAccount  -ResourceGroupName $ResourceGroup 
$ctx = $storageAccount.Context

# new container in srorage 
$GetContainer = Get-AzStorageContainer -Name ($ContainerName).ToLower() -Context $ctx -ErrorAction SilentlyContinue
if (!$GetContainer) {
    Write-Host "Container '$ContainerName' does not exist.";
    Write-Host "Creating container '$ContainerName'";
    new-AzStoragecontainer -Name ($ContainerName).ToLower() -Context $ctx -Permission blob 
}

else {
    Write-Host "Using existing Container Name $ContainerName"
}
#endregion
# upload a files
#region
$files = Get-ChildItem -Path "$PSScriptRoot\linked" -Force 
foreach ($item in $files) {
 
    set-AzStorageblobcontent -File "$PSScriptRoot\linked\$item" `
        -Container $ContainerName `
        -Blob $item `
        -Context $ctx 

}
#endregion
# new sas token for container 
$sastoken = New-AzStorageContainerSASToken -Container $ContainerName `
    -Context $storageAccount.Context `
    -Permission r `
    -ExpiryTime (Get-Date).AddHours(2.0)
  
# set variables for parametr file 
#region
$storageUri = $ctx.BlobEndPoint + $ContainerName
# editing parameter file
$a = Get-Content  "$PSScriptRoot\parametrs.json" | ConvertFrom-Json  
$a.parameters.storageUri.value = $storageUri
$a.parameters.sas.value = $sastoken 
$a | ConvertTo-Json -Depth 3 | Out-File  "$PSScriptRoot\parametrs.json" 
#endregion
# # creating resourses by arm templates
new-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup `
    -TemplateFile "$PSScriptRoot\main.json" `
    -TemplateParameterFile "$PSScriptRoot\parametrs.json"  -Force -Verbose -DeploymentDebugLogLevel All
#to remove my resources 
#Get-AzResourceGroup |  Remove-AzResourceGroup -Force -Confirm: $false -Verbose

