####################################################################################
# main.tf: Minimal file to test config.tf functionality
#
# NB: uses symlinked config.tf and config.yaml
####################################################################################

# from gihub workflow  NB: terraform test files don't inherit these 
variable "vsn" { default = "latest" }
variable "env" { default = "dev" }
variable "location" { default = "BA_IRELAND" }
variable "repo" { default = "olympus-infr-adm-snowflake" }

# terraform combines all files with a .tf extension 
# in particular it will pick up our symlinked config.tf 

# terraform test will then run all files with a .tftest.hcl extension

