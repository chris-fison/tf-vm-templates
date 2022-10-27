variable "diagnostic_storage_account_name" {
  type        = string
  description = "Jump box diagnostic account"
}

variable "diagnostic_storage_account_resource_group" {
  type        = string
  description = "Jump box diagnostic account resource group name"
}

variable "subnet_name" {
  type        = string
  description = "subnet_name name for jump box"
}

variable "virtual_network_name" {
  type        = string
  description = "Virtual network for Jump box"
}

variable "virtual_network_resource_group_name" {
  type        = string
  description = "Resource group name where virtual network is located"
}

variable "resource_group" {
  type        = string
  description = "Resource group name where virtual machine is located"
}

variable "keyvault_name" {
  type        = string
  description = "Key Vault name for disk encryption and local admin password"
}

variable "core_resource_group_name" {
  type        = string
  description = "Resource group where key vault is located"
}

variable "keyvault_disk_enc_key" {
  type        = string
  description = "Key reference name for disk encrpytion"
}

variable "backup_vault_name" {
  type        = string
  description = "Name of the vault to store the backup of the virtual machine"
}

variable "backup_policy_id" {
  type        = string
  description = "ID of the backup policy to attach to the virtual machine"
}

variable "vm_nic_map" {
  type        = map(string)
  description = "Network interface private IP addresses"
}

variable "dns_servers" {
  type        = list(string)
  description = "List of custom DNS servers"
  default     = []
}

variable "vm_names" {
  type        = list(string)
  description = "List of virtual machine names"
}

variable "vm_size" {
  type        = string
  description = "Virtual machine size"
}

variable "windows_os_version" {
  type        = string
  description = "Version of the Windows Server Operating system to deploy"
  default     = "2019"
  validation {
  condition     = contains(["2012-R2","2016","2019","2022"], var.windows_os_version)
  error_message = "The Windows OS version must be one of ['2012-R2', '2016', '2019'. '2022']."
  }
}

variable "disk_type" {
  type        = string
  description = "Type of disk"
  default     = "Standard_LRS"
}

variable "data_disk_size" {
  type        = string
  description = "Data disk size in GB"
}

variable "admin_username" {
  type        = string
  description = "User admin name to RDP to Jump box"
}

variable "admin_password" {
  type        = string
  description = "User password to RDP to Jump Box"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to be applied. Default is none."
  default     = {}
}

variable "oms_workspace_id" {
  type        = string
  description = "Workspace Id"
}

variable "oms_workspace_primary_shared_key" {
  type        = string
  description = "workspace primary shared key"
}

variable "availability_set_id" {
  type        = string
  description = "(Optional) Availability Set Id for regions not supporting Availability Zones"
  default     = ""
}

variable "delete_disks_on_termination" {
  type        = bool
  description = "Should VM disks be deleted when the VM is? Setting as false means the disks will be left behind after a destroy"
  default     = true
}
