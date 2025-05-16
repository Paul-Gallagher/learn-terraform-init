####################################################################################
# Minimal main.tf to test the config.tf file
####################################################################################

# from gihub workflow
variable "vsn" { default = "latest" }
variable "env" { default = "dev" }
variable "location" { default = "BA_IRELAND" }
variable "repo" { default = "olympus-infr-adm-snowflake" }

# terraform will combine this file others to create a single plan
# in particular it will use the symlink to our main config.tf file

output "debug_warehouses" {
  value = local.warehouses
}
