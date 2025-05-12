# DATABASE - dummy module

# these are our variable parameters - mostly supplied by the yaml file
variable "name" { type = string }
variable "extra_schemas" { type = list(any) }
variable "comment" { type = string }
variable "owner" { type = string }


# now our dummy resource - would be snowflake_database in the real module 
resource "terraform_data" "database" {
  input = jsonencode({
    name          = var.name
    extra_schemas = var.extra_schemas
    comment       = var.comment
  })
  triggers_replace = [timestamp()]
}

resource "terraform_data" "grant_ownership" {
  depends_on = [terraform_data.database]
  input = jsonencode({
    account_role_name   = var.owner
    outbound_privileges = "COPY"
    object_name         = var.name
    object_type         = "DATABASE"
  })
  triggers_replace = [timestamp()]
}
