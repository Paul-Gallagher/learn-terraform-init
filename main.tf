# The end-user interface is solely through the config.yaml file - buzz-word might be "separation of concerns".
# This allows them to define the Snowflake resources they want without touching HCL code.
# Parsing is centralised here ensures consistency accross moduled. 
# (each module could have its own parsing logic - but that would be a nightmare to maintain)
#
# The aim here is to:
#  - apply environment-specific transformations (e.g. replace ${env} with the actual env name)
#  - transform complex nexted structures into flat maps or lists
#  - provide sensible defaults for optional values (e.g. clus`ter_count, extra_schemas)

# from gihub workflow
variable "env" { default = "dev" }
variable "repo" { default = "olympus-infr-adm-snowflake" }
variable "aws_account" { default = "347295195503" }

locals {
  # some values will be passed in from the Github workflow run (e.g. env, AWS account etc)
  env          = upper(var.env)
  aws_account  = var.aws_account # avoid having to remember when to use var. and when local.
  repo         = var.repo
  storage_role = "ba-olympus-ecpsnowflake"

  # used in setting up storage integrations
  storage_role_arn = "arn:aws:iam::${local.aws_account}:role/${local.storage_role}"

  # Snowflake resources have their ownership transferred to this user
  owner = "SYSADMIN_${local.env}"

  # see config.tf which parses config.yaml and sets un various maps (eg warehouses, databases, etc
}

# now pretend to call the modules - unfortunately providers can't be chosen dynamically

### BA_LONDON #########################################################

# module "snowflake_roles_london" {
#   source = "./modules/snowflake-roles"
#   for_each = {
#     for name, wh in local.warehouses : name => wh
#     if contains(wh.locations, "BA_LONDON")
#   }
#   name      = each.key
#   comment   = each.value.comment
#   providers = { tfcoremock = tfcoremock.BA_LONDON }
# }

module "snowflake_warehouse_ba_london" {
  source = "./modules/snowflake-warehouse"
  for_each = {
    for name, wh in local.warehouses : name => wh
    if wh.location == "BA_LONDON"
  }
  name              = each.key
  size              = each.value.size
  max_cluster_count = each.value.max_cluster_count
  comment           = each.value.comment
  owner             = local.owner
  providers         = { tfcoremock = tfcoremock.BA_LONDON }
}

module "snowflake_database_ba_london" {
  #   source = "git@github.com:BritishAirways-Ent/olympus-infr-adm-snowflake/src/terraform/modules/snowflake-database?ref=main"
  source = "./modules/snowflake-database"
  for_each = {
    for name, db in local.databases : name => db
    if contains(db.locations, "BA_LONDON")
  }
  name          = each.key
  extra_schemas = each.value.extra_schemas
  comment       = each.value.comment
  owner         = local.owner
  providers     = { tfcoremock = tfcoremock.BA_LONDON }
}

module "snowflake_integration_ba_london" {
  source = "./modules/snowflake-integration"
  for_each = {
    for name, ig in local.integrations : name => ig
    if contains(ig.locations, "BA_LONDON")
  }
  name              = each.key
  allowed_locations = each.value.allowed_locations
  comment           = each.value.comment
  owner             = local.owner
  storage_role_arn  = local.storage_role_arn
  providers         = { tfcoremock = tfcoremock.BA_LONDON }
}

module "snowflake_stage_ba_london" {
  source = "./modules/snowflake-stage"
  for_each = {
    for name, st in local.stages : name => st
    if contains(st.locations, "BA_LONDON")
  }
  name        = each.key
  location    = each.value.location
  integration = each.value.integration
  comment     = each.value.comment
  owner       = local.owner
  providers   = { tfcoremock = tfcoremock.BA_LONDON }
}


### BA_IRELAND #########################################################

module "snowflake_warehouse_ba_ireland" {
  source = "./modules/snowflake-warehouse"
  for_each = {
    for name, wh in local.warehouses : name => wh
    if wh.location == "BA_IRELAND"
  }
  name              = each.key
  size              = each.value.size
  max_cluster_count = each.value.max_cluster_count
  comment           = each.value.comment
  owner             = local.owner
  providers         = { tfcoremock = tfcoremock.BA_IRELAND }
}

module "snowflake_database_ba_ireland" {
  #   source = "git@github.com:BritishAirways-Ent/olympus-infr-adm-snowflake/src/terraform/modules/snowflake-database?ref=main"
  source = "./modules/snowflake-database"

  for_each = {
    for name, db in local.databases : name => db
    if contains(db.locations, "BA_IRELAND")
  }
  name          = each.key
  extra_schemas = each.value.extra_schemas
  comment       = each.value.comment
  owner         = local.owner
  providers     = { tfcoremock = tfcoremock.BA_IRELAND }
}

module "snowflake_integration_ba_ireland" {
  source = "./modules/snowflake-integration"
  for_each = {
    for name, ig in local.integrations : name => ig
    if contains(ig.locations, "BA_IRELAND")
  }
  name              = each.key
  allowed_locations = each.value.allowed_locations
  comment           = each.value.comment
  owner             = local.owner
  storage_role_arn  = local.storage_role_arn
  providers         = { tfcoremock = tfcoremock.BA_IRELAND }
}

module "snowflake_stage_ba_ireland" {
  source = "./modules/snowflake-stage"
  for_each = {
    for name, st in local.stages : name => st
    if contains(st.locations, "BA_IRELAND")
  }
  name        = each.key
  location    = each.value.location
  integration = each.value.integration
  comment     = each.value.comment
  owner       = local.owner
  providers   = { tfcoremock = tfcoremock.BA_IRELAND }
}


# terraform state list module.snowflake_warehouse
#
# print put the resources we whoul have created
# terraform show -json | jq ".values.root_module.child_modules[].resources[].values.input | fromjson"

# see x-cmd.log
