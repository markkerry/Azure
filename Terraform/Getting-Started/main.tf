terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-eu-stg"
    storage_account_name = "mkstfcqgtckq5sjjds"
    container_name       = "tf-state"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = ""
  features {}
}

# Create the resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# Create Storage Account
resource "azurerm_storage_account" "demo" {
  name                     = "${var.prefix}-stgaccount"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  access_tier              = "Standard"
  account_replication_type = "LRS"
}

# Create vNet
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Create Subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal-subnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create vm1 nic
resource "azurerm_network_interface" "vm1nic" {
  name                = "${var.prefix}-vm1-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create vm2 nic
resource "azurerm_network_interface" "vm2nic" {
  name                = "${var.prefix}-vm2-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create VM1 Ubuntu
resource "azurerm_virtual_machine" "vm1" {
  name                = "${var.prefix}-vm-vm1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_A2_v2"
  admin_username      = "admin-user"
  network_interface_ids = [azurerm_network_interface.vm1nic.id]

  admin_ssh_key {
    username   = "admin-user"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

# Create VM2 Ubuntu
resource "azurerm_virtual_machine" "vm2" {
  name                = "${var.prefix}-vm-vm2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_A2_v2"
  admin_username      = "admin-user"
  network_interface_ids = [azurerm_network_interface.vm2nic.id]

  admin_ssh_key {
    username   = "admin-user"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}