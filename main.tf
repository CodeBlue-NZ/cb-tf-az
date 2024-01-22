# Configure the Required Terraform version and azure rm source. 
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm" # Specifies the provider source
      version = "=3.86.0"           # Specifies the provider version
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {} # Empty block means all features are used with their default settings
}

# Added a Random Provider for Generating Randomness
provider "random" {
}

# Random Password Generator
resource "random_password" "password" {
  length           = 24    # Specifies the length of the password
  special          = true  # Specifies that special characters are allowed
  override_special = "_%@" # Specifies the special characters to be used
}

# Configures the resource group and location
resource "azurerm_resource_group" "cb-tf-rg" {
  name     = "cb-tf-resources" # Specifies the name of the resource group
  location = "Australia East"  # Specifies the location of the resource group
  tags = {
    environment = "test"
    createdby   = "terraform"
  }
}

# Virtual Network for the Azure VM
resource "azurerm_virtual_network" "cb-tf-vn" {
  name                = "cb-tf-network"                          # Specifies the name of the virtual network
  location            = azurerm_resource_group.cb-tf-rg.location # Specifies the location of the virtual network
  resource_group_name = azurerm_resource_group.cb-tf-rg.name     # Specifies the resource group of the virtual network
  address_space       = ["10.0.0.0/16"]                          # Specifies the address space of the virtual network
  tags = {
    environment = "test"
    createdby   = "terraform"
  }
}

#VM Subnet created
resource "azurerm_subnet" "cbvm-subnet" {
  name                 = "cbvm-subnet"                         # Specifies the name of the subnet
  resource_group_name  = azurerm_resource_group.cb-tf-rg.name  # Specifies the resource group of the subnet
  virtual_network_name = azurerm_virtual_network.cb-tf-vn.name # Specifies the virtual network of the subnet
  address_prefixes     = ["10.0.1.0/24"]                       # Specifies the address prefixes of the subnet
}

#Network Security Group to be associated to the VM
resource "azurerm_network_security_group" "cb-tf-sg" {
  name                = "vmTestSecurityGroup1"                   # Specifies the name of the network security group
  location            = azurerm_resource_group.cb-tf-rg.location # Specifies the location of the network security group
  resource_group_name = azurerm_resource_group.cb-tf-rg.name     # Specifies the resource group of the network security group
  tags = {
    environment = "test"
    createdby   = "terraform"
  }
}

# Network Security rule within the Security group allowing Inbound access from our Codeblue Office Public IP
resource "azurerm_network_security_rule" "cb-tf-rule" {
  name                        = "vminboundrule"                              # Specifies the name of the network security rule
  priority                    = 100                                          # Specifies the priority of the network security rule
  direction                   = "Inbound"                                    # Specifies the direction of the network security rule
  access                      = "Allow"                                      # Specifies the access of the network security rule
  protocol                    = "*"                                          # Specifies the protocol of the network security rule
  source_port_range           = "*"                                          # Specifies the source port range of the network security rule
  destination_port_range      = "*"                                          # Specifies the destination port range of the network security rule
  source_address_prefix       = chomp(data.http.myip.body)                   #  Use the fetched IP address in the network security rule
  destination_address_prefix  = "*"                                          # Specifies the destination address prefix of the network security rule
  resource_group_name         = azurerm_resource_group.cb-tf-rg.name         # Specifies the resource group of the network security rule
  network_security_group_name = azurerm_network_security_group.cb-tf-sg.name # Specifies the network security group of the network security rule
}

# Fetch the IP address
data "http" "myip" {
  url = "https://ipv4.icanhazip.com/"
}

# Network Security Group associated to the subnet
resource "azurerm_subnet_network_security_group_association" "cb-tf-sga" {
  subnet_id                 = azurerm_subnet.cbvm-subnet.id              # Specifies the subnet id of the association
  network_security_group_id = azurerm_network_security_group.cb-tf-sg.id # Specifies the network security group id of the association
}

# Public IP creation
resource "azurerm_public_ip" "cb-tf-pubip" {
  name                = "TestPublicIp1"                          # Specifies the name of the public IP
  resource_group_name = azurerm_resource_group.cb-tf-rg.name     # Specifies the resource group of the public IP
  location            = azurerm_resource_group.cb-tf-rg.location # Specifies the location of the public IP
  allocation_method   = "Dynamic"                                # Specifies the allocation method of the public IP
  tags = {
    environment = "test"
    createdby   = "terraform"
  }
}

# Network NIC Configuration 
resource "azurerm_network_interface" "cb-tf-nic" {
  name                = "vm-nic"                                 # Specifies the name of the network interface
  location            = azurerm_resource_group.cb-tf-rg.location # Specifies the location of the network interface
  resource_group_name = azurerm_resource_group.cb-tf-rg.name     # Specifies the resource group of the network interface

  ip_configuration {
    name                          = "internal"                       # Specifies the name of the IP configuration
    subnet_id                     = azurerm_subnet.cbvm-subnet.id    # Specifies the subnet id of the IP configuration
    private_ip_address_allocation = "Dynamic"                        # Specifies the private IP address allocation of the IP configuration
    public_ip_address_id          = azurerm_public_ip.cb-tf-pubip.id # Specifies the public IP address id of the IP configuration
  }
  tags = {
    environment = "test"
    createdby   = "terraform"
  }
}

# Windows Server VM Created
resource "azurerm_windows_virtual_machine" "cb-tf-testvm" {
  name                = "cb-tf-testvm"                           # Specifies the name of the virtual machine
  resource_group_name = azurerm_resource_group.cb-tf-rg.name     # Specifies the resource group of the virtual machine
  location            = azurerm_resource_group.cb-tf-rg.location # Specifies the location of the virtual machine
  size                = "Standard_DS1_v2"                        # Specifies the size of the virtual machine
  admin_username      = "cblocaladmin"                           # Specifies the admin username of the virtual machine
  admin_password      = random_password.password.result          # Specifies the admin password of the virtual machine
  timezone            = "New Zealand Standard Time"              # Specifies the timezone of the virtual machine
  network_interface_ids = [
    azurerm_network_interface.cb-tf-nic.id, # Specifies the network interface ids of the virtual machine
  ]

  os_disk {
    caching              = "ReadWrite"    # Specifies the caching of the OS disk
    storage_account_type = "Standard_LRS" # Specifies the storage account type of the OS disk
  }

  tags = {
    environment = "test"
    createdby   = "terraform"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer" # Specifies the publisher of the source image
    offer     = "WindowsServer"          # Specifies the offer of the source image
    sku       = "2022-Datacenter"        # Specifies the SKU of the source image
    version   = "latest"                 # Specifies the version of the source image
  }
}