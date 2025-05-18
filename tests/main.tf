####################################################################################
# main.tf: Minimal file to test config.tf functionality
####################################################################################

# from gihub workflow  NB: terraform test files don't inherit these 
variable "vsn" { default = "latest" }
variable "env" { default = "dev" }
variable "location" { default = "BA_IRELAND" }
variable "repo" { default = "olympus-infr-adm-snowflake" }

# terraform combines all files with a .tf extension 
# in particular it will use the config.tf symlink  

