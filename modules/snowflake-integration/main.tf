# SNOWFLAKE-INTEGRATION - dummy module
#  - creates a Snowflake integration and changes its ownership


# these are our variable parameters - mostly supplied by the yaml file
variable "name" { type = string }
variable "buckets" { type = list(string) }
variable "comment" { type = string }
variable "owner" { type = string }
variable "storage_role_arn" { type = string }


# now our dummy resource - would be snowflake_warehouse in the real module 
resource "terraform_data" "integration" {
  input = jsonencode({
    name                      = var.name
    type                      = "EXTERNAL_STAGE"
    storage_provider          = "S3"
    storage_role_arn          = var.storage_role_arn
    storage_allowed_locations = var.buckets
    enabled                   = true
    comment                   = var.comment
  })
  triggers_replace = [timestamp()] # just so plan always shows a replacement
}

resource "terraform_data" "grant_ownership" {
  depends_on = [terraform_data.integration]
  input = jsonencode({
    account_role_name   = var.owner
    outbound_privileges = "USAGE"
    object_name         = var.name
    object_type         = "INTEGRATION"
  })
  triggers_replace = [timestamp()]
}

