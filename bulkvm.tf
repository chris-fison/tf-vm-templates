# Sample deploy 5 Vms for SCCM purposes

# refer to a resource group
data "azurerm_resource_group" "test" {
  #location = "uksouth"
  name = "fisontech-rg" 
}

# refer to a subnet
data "azurerm_subnet" "test" {
  name                 = "default"
  virtual_network_name = "Fisontech-vnet"
  resource_group_name  = "fisontech-rg"
}

 resource "azurerm_network_interface" "test" {
   count               = 3
   name                = "acctni${count.index}"
   location            = "${data.azurerm_resource_group.test.location}"
   resource_group_name = "${data.azurerm_resource_group.test.name}"


   ip_configuration {
     name                          = "testConfiguration"
     subnet_id                     = "${data.azurerm_subnet.test.id}"
     private_ip_address_allocation = "Dynamic"
     # public_ip_address_id          = "${azurerm_public_ip.test.id}"
   }
 }

 resource "azurerm_managed_disk" "test" {
   count                = 3
   name                 = "datadisk_existing_${count.index}"
   location             = "${data.azurerm_resource_group.test.location}"
   resource_group_name  = "${data.azurerm_resource_group.test.name}"
   storage_account_type = "Standard_LRS"
   create_option        = "Empty"
   disk_size_gb         = "1023"
 }

 resource "azurerm_availability_set" "avset" {
   name                         = "avset"
   location                     = "${data.azurerm_resource_group.test.location}"
   resource_group_name          = "${data.azurerm_resource_group.test.name}"
   platform_fault_domain_count  = 2
   platform_update_domain_count = 2
   managed                      = true
 }

 resource "azurerm_virtual_machine" "test" {
   count                 = 3
   name                  = "acctvm${count.index}"
   location              = "${data.azurerm_resource_group.test.location}"
   availability_set_id   = azurerm_availability_set.avset.id
   resource_group_name   = "${data.azurerm_resource_group.test.name}"
   network_interface_ids = [element(azurerm_network_interface.test.*.id, count.index)]
   vm_size               = "Standard_DS1_v2"

   # Uncomment this line to delete the OS disk automatically when deleting the VM
   # delete_os_disk_on_termination = true

   # Uncomment this line to delete the data disks automatically when deleting the VM
   # delete_data_disks_on_termination = true

   storage_image_reference {
     publisher = "Canonical"
     offer     = "UbuntuServer"
     sku       = "16.04-LTS"
     version   = "latest"
   }

   storage_os_disk {
     name              = "myosdisk${count.index}"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }

   # Optional data disks
   storage_data_disk {
     name              = "datadisk_new_${count.index}"
     managed_disk_type = "Standard_LRS"
     create_option     = "Empty"
     lun               = 0
     disk_size_gb      = "1023"
   }

   storage_data_disk {
     name            = element(azurerm_managed_disk.test.*.name, count.index)
     managed_disk_id = element(azurerm_managed_disk.test.*.id, count.index)
     create_option   = "Attach"
     lun             = 1
     disk_size_gb    = element(azurerm_managed_disk.test.*.disk_size_gb, count.index)
   }

   os_profile {
     computer_name  = "hostname"
     admin_username = "testadmin"
     admin_password = "Password1234!"
   }

   os_profile_linux_config {
     disable_password_authentication = false
   }

   tags = {
     environment = "staging"
   }
 }
