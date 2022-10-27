# --------------------------------------------------------------------------------------------------------------
# Module to Build a Windows Server
# Terraform script written by sol-tec
# v 1.0
# 21 Sep 2020
# --------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------
# Data sources
# --------------------------------------------------------------------------------------------------------------

data "azurerm_storage_account" "boot_diagnostics" {
  name                = var.diagnostic_storage_account_name
  resource_group_name = var.diagnostic_storage_account_resource_group
}

data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group_name
}

data "azurerm_resource_group" "main" {
  name = var.resource_group
}

data "azurerm_key_vault" "disk_encryption" {
  name                = var.keyvault_name
  resource_group_name = var.core_resource_group_name
}

data "azurerm_key_vault_key" "encryption_key" {
  key_vault_id = data.azurerm_key_vault.disk_encryption.id
  name         = var.keyvault_disk_enc_key
}

# --------------------------------------------------------------------------------------------------------------
# Resources
# --------------------------------------------------------------------------------------------------------------

resource "azurerm_network_interface" "main" {
  count               = length(var.vm_names)
  name                = keys(var.vm_nic_map)[count.index]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = values(var.vm_nic_map)[count.index]
  }
  dns_servers = var.dns_servers
}

# Deploy Virtual Machine
resource "azurerm_virtual_machine" "vm" {
  count                 = length(var.vm_names)
  name                  = element(var.vm_names, count.index)
  location              = data.azurerm_resource_group.main.location
  resource_group_name   = data.azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main[count.index].id]
  vm_size               = var.vm_size

  # zone - Note if you build more than 3 instances, the below line will need refactoring. As Azure only has 3 zones.
  availability_set_id = var.availability_set_id != "" ? var.availability_set_id : null
  zones               = var.availability_set_id != "" ? null : [count.index + 1]

  delete_os_disk_on_termination    = var.delete_disks_on_termination
  delete_data_disks_on_termination = var.delete_disks_on_termination

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "${var.windows_os_version}-Datacenter"
    version   = "latest"
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = data.azurerm_storage_account.boot_diagnostics.primary_blob_endpoint
  }

  storage_os_disk {
    name              = format("osDisk-%s", element(var.vm_names, count.index))
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = var.disk_type
  }

  storage_data_disk {
    name              = format("dataDiskDNS-%s", element(var.vm_names, count.index))
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = var.data_disk_size
    managed_disk_type = var.disk_type
  }
  
    storage_data_disk {
    name              = format("dataDiskNTDS-%s", element(var.vm_names, count.index))
    create_option     = "Empty"
    lun               = 1
    disk_size_gb      = var.data_disk_size
    managed_disk_type = var.disk_type
  }

  os_profile {
    computer_name  = element(var.vm_names, count.index)
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  depends_on = [
    azurerm_network_interface.main
  ]

  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}


resource "azurerm_virtual_machine_extension" "vm_antivirus" {
  name                       = "IaaSAntimalware"
  virtual_machine_id         = azurerm_virtual_machine.vm[count.index].id
  publisher                  = "Microsoft.Azure.Security"
  type                       = "IaaSAntimalware"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = "true"

  settings = <<SETTINGS
  {
    "AntimalwareEnabled": true,
    "RealtimeProtectionEnabled": "true",
    "ScheduledScanSettings": {
        "isEnabled": "true",
        "day": "7",
        "time": "120",
        "scanType": "Quick"
    },
    "Exclusions": {
        "Extensions": "",
        "Paths": "C:\\Windows\\SoftwareDistribution\\Datastore;C:\\Windows\\SoftwareDistribution\\Datastore\\Logs;C:\\Windows\\Security\\Database",
        "Processes": "NTUser.dat*"
     }
  }
  SETTINGS

  count = length(var.vm_names)

  depends_on = [
    
  ]

  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

# OMS Monitoring VM Extension 
resource "azurerm_virtual_machine_extension" "monitoring" {
  name                       = "MicrosoftMonitoringAgent"
  virtual_machine_id         = azurerm_virtual_machine.vm[count.index].id
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = <<-BASE_SETTINGS
  {
    "azureResourceId" : "${azurerm_virtual_machine.vm[count.index].id}",
    "stopOnMultipleConnections" : true,
    "workspaceId" : "${var.oms_workspace_id}"
  }
  BASE_SETTINGS

  protected_settings = <<-PROTECTED_SETTINGS
  {
    "workspaceKey" : "${var.oms_workspace_primary_shared_key}"
  }
  PROTECTED_SETTINGS

  count = length(var.vm_names)

  depends_on = [
    
  ]

  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}


resource "azurerm_virtual_machine_extension" "vm_extension_initialize_disks" {
  name                 = "InitializeDisks"
  virtual_machine_id   = azurerm_virtual_machine.vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  settings             = <<SETTINGS
    {
        "commandToExecute": "powershell.exe -command \"$disks = Get-disk -friendlyname msft*; foreach ($disk in $disks){Initialize-Disk -UniqueId $disk.UniqueId -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume  -FileSystem NTFS -NewFileSystemLabel “DataDisk $($disk.number)” -Confirm:$false};\""
    }

  SETTINGS

  count = length(var.vm_names)

  depends_on = [
    
  ]

  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}


resource "azurerm_virtual_machine_extension" "encryption" {
  name                 = "AzureDiskEncrpytion"
  virtual_machine_id   = azurerm_virtual_machine.vm[count.index].id
  publisher            = "Microsoft.Azure.Security"
  type                 = "AzureDiskEncryption"
  type_handler_version = "2.2"

  settings = <<SETTINGS
    {
        "EncryptionOperation": "EnableEncryption",
        "KeyEncryptionAlgorithm": "RSA-OAEP",
        "KeyEncryptionKeyURL": "${data.azurerm_key_vault.disk_encryption.vault_uri}keys/${data.azurerm_key_vault_key.encryption_key.name}/${data.azurerm_key_vault_key.encryption_key.version}",
        "KeyVaultURL": "${data.azurerm_key_vault.disk_encryption.vault_uri}",
        "KeyVaultResourceId": "${data.azurerm_key_vault.disk_encryption.id}",
        "KekVaultResourceId": "${data.azurerm_key_vault.disk_encryption.id}",
        "VolumeType": "All"
    }
    SETTINGS

  count = length(var.vm_names)

  depends_on = [
    azurerm_virtual_machine_extension.vm_extension_initialize_disks
  ]

  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
