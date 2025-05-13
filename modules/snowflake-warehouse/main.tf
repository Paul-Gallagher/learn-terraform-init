# WAREHOUSE - dummy module
#  - creates a Snowflake warehouse and changes its ownership


# these are our variable parameters - mostly supplied by the yaml file
variable "name" { type = string }
variable "size" { type = string }
variable "max_cluster_count" { type = number }
variable "comment" { type = string }
variable "owner" { type = string }

# these are constant defaults - I made them locals to help them stand out
locals {
  auto_resume         = true
  auto_suspend        = 60
  min_cluster_count   = 1
  concurrency_level   = 8
  queued_timeout      = 1800
  timeout             = 7200
  initially_suspended = true
}
# snowflake_warehouse
# variable "auto_resume" { default = true }
# variable "auto_suspend" { default = 60 }
# variable "min_cluster_count" { default = 1 }
# variable "concurrency_level" { default = 8 }
# variable "queued_timeout" { default = 1800 }
# variable "timeout" { default = 7200 }
# variable "initially_suspended" { default = true }


# now our dummy resource - would be snowflake_warehouse in the real module 
resource "terraform_data" "warehouse" {
  input = jsonencode({
    name                                = var.name
    comment                             = var.comment
    warehouse_size                      = var.size
    max_cluster_count                   = var.max_cluster_count
    min_cluster_count                   = local.min_cluster_count   # constant
    auto_resume                         = local.auto_resume         # constant
    auto_suspend                        = local.auto_suspend        # constant
    initially_suspended                 = local.initially_suspended # constant
    max_concurrency_level               = local.concurrency_level   # constant
    statement_queued_timeout_in_seconds = local.queued_timeout      # constant
    statement_timeout_in_seconds        = local.timeout             # constant
  })
  triggers_replace = [timestamp()] # so plan always shows a replacement
}

resource "terraform_data" "grant_ownership" {
  depends_on = [terraform_data.warehouse]
  input = jsonencode({
    account_role_name   = var.owner
    outbound_privileges = "COPY"
    object_name         = var.name
    object_type         = "WAREHOUSE"
  })
  triggers_replace = [timestamp()]
}

