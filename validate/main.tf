####################################################################################
# main.tf: Minimal file to validate config.yaml against our schema
####################################################################################

# from gihub workflow  NB: terraform test files don't inherit these 
variable "vsn" { default = "latest" }
variable "env" { default = "dev" }
variable "location" { default = "BA_IRELAND" }
variable "repo" { default = "olympus-infr-adm-snowflake" }

# terraform combines all files with a .tf extension 
# in particular, our symlinked config.tf, config.yaml and our checks.tf
