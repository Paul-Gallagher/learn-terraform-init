# SNOWFLAKE-STAGE - dummy module
#  - creates a Snowflake stage and changes its ownership


# these are our variable parameters - mostly supplied by the yaml file
variable "name" { type = string }
variable "location" { type = string }
variable "integration" { type = string }
variable "comment" { type = string }
variable "owner" { type = string }


# now our dummy resource - would be snowflake_warehouse in the real module 
resource "terraform_data" "stage" {
  input = jsonencode({
    name        = var.name
    location    = var.location
    integration = var.integration
    comment     = var.comment
  })
  triggers_replace = [timestamp()] # just so plan always shows a replacement
}

resource "terraform_data" "grant_ownership" {
  depends_on = [terraform_data.stage]
  input = jsonencode({
    account_role_name   = var.owner
    outbound_privileges = "COPY"
    object_name         = var.name
    object_type         = "STAGE"
  })
  triggers_replace = [timestamp()]
}

