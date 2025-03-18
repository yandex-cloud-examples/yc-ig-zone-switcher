variable "yc_token" {
  type = string
}
variable "yc_cloud_id" {
  description = "YC Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "YC Folder ID"
  type        = string
}
variable "pg_cluster" {
  type = object(
    {
      db_user   = string # Database admin username
      db_pass   = string # Database admin password
    }
  )
}

variable "subnet_zones" {
  type = list(object(
    {
      zone = string
      cidr = string
    }
  ))
  default = [
    {zone = "ru-central1-b", cidr ="10.12.0.0/24"}, 
    {zone = "ru-central1-a", cidr ="10.13.0.0/24"}
  ]
}

variable "image" {
  type = string
  default = "cr.yandex/crp9vlkjcajdbfqf3116/dp-solutions/follow-the-leader"
}

variable "ssh_key_path" {
  type = string
}

variable "log_group_id" {
  type = string
}

variable "function_mount_name" {
  type = string
  default = "u01"  
}

variable "mdb_service_type" {
  type = string
  default = "postgresql"
  # or "mysql"
}