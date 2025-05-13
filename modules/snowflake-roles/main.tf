# SNOWFLAKE-ROLES - dummy module
#  - creates a role for DBT and another for AIRFLOW
#  - mucks around with ownership of the roles


# these are our variable parameters - mostly supplied by the yaml file
variable "name" { type = string }
variable "comment" { type = string }


# now our dummy resource - would be snowflake_database in the real module 
resource "terraform_data" "database" {
  input = jsonencode({
    name    = var.name
    comment = var.comment
  })
  triggers_replace = [timestamp()]
}

# resource "terraform_data" "grant_ownership" {
#   depends_on = [terraform_data.database]
#   input = jsonencode({
#     account_role_name   = var.owner
#     outbound_privileges = "COPY"
#     object_name         = var.name
#     object_type         = "DATABASE"
#   })
#   triggers_replace = [timestamp()]
# }
