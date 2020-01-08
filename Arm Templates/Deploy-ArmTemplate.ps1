New-AzResourceGroup -Name "rg-msdn-mk-ps" -Location 'West Europe' -Verbose #use this command when you need to create a new resource group for your deployment
New-AzResourceGroupDeployment -ResourceGroupName "rg-msdn-mk-ps" -TemplateUri https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/101-vm-tags/azuredeploy.json
