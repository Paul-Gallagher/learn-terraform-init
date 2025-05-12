# The end-user interface is solely through the config.yaml file - buzz-word might be "separation of concerns".
# This allows them to define the Snowflake resources they want without touching HCL code.
# Parsing is centralised here ensures consistency accross moduled. 
# (each module could have its own parsing logic - but that would be a nightmare to maintain)
#
# The aim here is to:
#  - apply environment-specific transformations (e.g. replace ${env} with the actual env name)
#  - transform complex nexted structures into flat maps or lists
#  - provide sensible defaults for optional values (e.g. cluster_count, extra_schemas)

locals {
  # some values will be passed in from the Github workflow run (e.g. env, AWS account etc)
  env          = upper("dev")
  aws_account  = "347295195503"
  storage_role = "ba-olympus-ecpsnowflake"
  repo         = "olympus-infr-adm-snowflake"

  # used in setting up storage integrations
  storage_role_arn = "arn:aws:iam::${local.aws_account}:role/${local.storage_role}"

  # Snowflake resources have their ownership transferred to this user
  owner = "SYSADMIN_${local.env}"
}

# --- these are purely for debugging ------------------------------------
# output "account" { value = local.account }
# output "all_accounts" { value = local.all_accounts }
# output "warehouses" { value = local.warehouses }
# output "databases" { value = local.databases }
output "integrations" { value = local.integrations }
# output "stages" { value = local.stages }
output "service_user" { value = local.service_user }
# -----------------------------------------------------------------------


# now pretend to call the modules - unfortunately providers can't be chosen dynamically

### LONDON #########################################################

module "snowflake_warehouse_london" {
  source = "./modules/snowflake-warehouse"
  for_each = {
    for name, wh in local.warehouses : name => wh
    if contains(wh.accounts, "LONDON")
  }
  name              = each.key
  size              = each.value.size
  max_cluster_count = each.value.max_cluster_count
  comment           = each.value.comment
  owner             = local.owner
  providers         = { tfcoremock = tfcoremock.LONDON }
}

module "snowflake_database_london" {
  source = "./modules/snowflake-database"
  for_each = {
    for name, db in local.databases : name => db
    if contains(db.accounts, "LONDON")
  }
  name          = each.key
  extra_schemas = each.value.extra_schemas
  comment       = each.value.comment
  owner         = local.owner
  providers     = { tfcoremock = tfcoremock.LONDON }
}

module "snowflake_integration_london" {
  source = "./modules/snowflake-integration"
  for_each = {
    for name, ig in local.integrations : name => ig
    if contains(ig.accounts, "LONDON")
  }
  name              = each.key
  allowed_locations = each.value.allowed_locations
  comment           = each.value.comment
  owner             = local.owner
  storage_role_arn  = local.storage_role_arn
  providers         = { tfcoremock = tfcoremock.LONDON }
}

module "snowflake_stage_london" {
  source = "./modules/snowflake-stage"
  for_each = {
    for name, st in local.stages : name => st
    if contains(st.accounts, "LONDON")
  }
  name        = each.key
  location    = each.value.location
  integration = each.value.integration
  comment     = each.value.comment
  owner       = local.owner
  providers   = { tfcoremock = tfcoremock.LONDON }
}


### IRELAND #########################################################

module "snowflake_warehouse_ireland" {
  source = "./modules/snowflake-warehouse"
  for_each = {
    for name, wh in local.warehouses : name => wh
    if contains(wh.accounts, "IRELAND")
  }
  name              = each.key
  size              = each.value.size
  max_cluster_count = each.value.max_cluster_count
  comment           = each.value.comment
  owner             = local.owner
  providers         = { tfcoremock = tfcoremock.IRELAND }
}

module "snowflake_database_ireland" {
  source = "./modules/snowflake-database"
  for_each = {
    for name, db in local.databases : name => db
    if contains(db.accounts, "IRELAND")
  }
  name          = each.key
  extra_schemas = each.value.extra_schemas
  comment       = each.value.comment
  owner         = local.owner
  providers     = { tfcoremock = tfcoremock.IRELAND }
}

module "snowflake_integration_ireland" {
  source = "./modules/snowflake-integration"
  for_each = {
    for name, ig in local.integrations : name => ig
    if contains(ig.accounts, "IRELAND")
  }
  name              = each.key
  allowed_locations = each.value.allowed_locations
  comment           = each.value.comment
  owner             = local.owner
  storage_role_arn  = local.storage_role_arn
  providers         = { tfcoremock = tfcoremock.IRELAND }
}

module "snowflake_stage_ireland" {
  source = "./modules/snowflake-stage"
  for_each = {
    for name, st in local.stages : name => st
    if contains(st.accounts, "IRELAND")
  }
  name        = each.key
  location    = each.value.location
  integration = each.value.integration
  comment     = each.value.comment
  owner       = local.owner
  providers   = { tfcoremock = tfcoremock.IRELAND }
}


# terraform state list module.snowflake_warehouse
#
# print put the resources we whoul have created
# terraform show -json | jq ".values.root_module.child_modules[].resources[].values.input | fromjson"

# also printing out the resource address is icky
# terraform show -json | jq ".values.root_module.child_modules[].resources[] | {address: .address, properties: (.values.input | fromjson)}"
# terraform show -json | jq ".values.root_module.child_modules[].resources[] | {address: .address, properties: (.values.input | fromjson)}"
#
# secrets
# airflow/connections/snowflake_secure_comm_loy_ba_members_conn
#   snowflake://AIRFLOW_SECURE_IAGL_LOY_CCD_DEV:m0SdJ%7B%5E%5E0%7B%23%3E%3BuNJp%7Drn@url.com:443?account=ba&region=eu-west-1&private_key_content=-----BEGIN+ENCRYPTED+PRIVATE+KEY-----...-----END+ENCRYPTED+PRIVATE+KEY-----
#
# airflow/connections/snowflake_cust_loy_ba_members_secure_conn
#  snowflake://AIRFLOW_CUST_LOY_BA_MEMBERS_SECURE_DEV:5_u%3C%7C38_R%233I6_bvb%2ABe@url.com:443?account=ba&region=eu-west-1&private_key_content=-----BEGIN+ENCRYPTED+PRIVATE+KEY----- ...-----END+ENCRYPTED+PRIVATE+KEY-----
