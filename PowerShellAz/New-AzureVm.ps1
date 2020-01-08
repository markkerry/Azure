# Install the Az module
# To use this script you will need to already have a resource group and virtual network created or extend the script to add those items as well. 

#Install-Module Az
 
#Login to your Azure account.
#Login-AzAccount
 
#Define the following parameters for the virtual machine.
$vmAdminUsername = "azureuser"
$vmAdminPassword = ConvertTo-SecureString "MySecurePassword" -AsPlainText -Force
$vmComputerName = "vm-msdn-mk-ps1"
 
#Define the following parameters for the Azure resources.
$azureLocation = "westeurope"
$azureResourceGroup = "rg-msdn-mk-test1"
$azureVmName = "vm-msdn-mk-ps1"
$azureVmOsDiskName = "vm-msdn-mk-ps1-OS"
$azureVmSize = "Standard_DS1_v2"
 
#Define the networking information.
$azureNicName = "vm-msdn-mk-ps1-NIC"
$azurePublicIpName = "vm-msdn-mk-ps1-IP"

#Define the existing VNet information.
$azureVnetName = "rg-msdn-mk-test1-vnet"
$azureVnetSubnetName = "default"
 
#Define the VM marketplace image details.
$azureVmPublisherName = "MicrosoftWindowsServer"
$azureVmOffer = "WindowsServer"
$azureVmSkus = "2019-Datacenter"
 
#Get the subnet details for the specified virtual network + subnet combination.
$azureVnetSubnet = (Get-AzVirtualNetwork -Name $azureVnetName -ResourceGroupName $azureResourceGroup).Subnets | Where-Object {$_.Name -eq $azureVnetSubnetName}
 
#Create the public IP address.
$azurePublicIp = New-AzPublicIpAddress -Name $azurePublicIpName -ResourceGroupName $azureResourceGroup -Location $azureLocation -AllocationMethod Dynamic
 
#Create the NIC and associate the public IpAddress.
$azureNIC = New-AzNetworkInterface -Name $azureNicName -ResourceGroupName $azureResourceGroup -Location $azureLocation -SubnetId $azureVnetSubnet.Id -PublicIpAddressId $azurePublicIp.Id
 
#Store the credentials for the local admin account.
$vmCredential = New-Object System.Management.Automation.PSCredential ($vmAdminUsername, $vmAdminPassword)
 
#Define the parameters for the new virtual machine.
$VirtualMachine = New-AzVMConfig -VMName $azureVmName -VMSize $azureVmSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $vmComputerName -Credential $vmCredential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $azureNIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $azureVmPublisherName -Offer $azureVmOffer -Skus $azureVmSkus -Version "latest"
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -StorageAccountType "Premium_LRS" -Caching ReadWrite -Name $azureVmOsDiskName -CreateOption FromImage
 
#Create the virtual machine.
New-AzVM -ResourceGroupName $azureResourceGroup -Location $azureLocation -VM $VirtualMachine -Verbose

#Define the following parameters for the Azure resources. Add this to the "#Define the following parameters for the Azure resources." code section.
$azureVmDataDisk01Name  = "vm-msdn-mk-ps1-Data01"
 
#Optionally, add an additional data disk. Add this to the "#Define the parameters for the new virtual machine." code section.
$vmDataDisk01Config = New-AzDiskConfig -SkuName Standard_LRS -Location $azureLocation -CreateOption Empty -DiskSizeGB 8
$vmDataDisk01 = New-AzDisk -DiskName $azureVmDataDisk01Name -Disk $vmDataDisk01Config -ResourceGroupName $azureResourceGroup
$VirtualMachine = Add-AzVMDataDisk -VM $VirtualMachine -Name $azureVmDataDisk01Name -CreateOption Attach -ManagedDiskId $vmDataDisk01.Id -Lun 0
