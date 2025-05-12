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

  storage_role_arn = "arn:aws:iam::${local.aws_account}:role/${local.storage_role}"
  owner            = "SYSADMIN_${local.env}"

  # first read the file as a plain string
  raw_content = file("${path.module}/config.yaml")

  # run our string interpolations - e.g. replace ${env} with the actual env name
  cooked_content = replace(local.raw_content, "$${env}", local.env)

  # now decode the yaml an pull out the Snowflake section - if it exists
  raw_yaml = try(yamldecode(local.cooked_content).Snowflake, null)


  # do we have a Snowflake account override section - this is a key into Secrets Manager (?)
  default_account = try(local.raw_yaml.account, null)

  # all sub-sections are optional, so we need to set up suitable defaults - mostly empty lists
  yaml = {
    warehouses   = try(local.raw_yaml.warehouse, [])
    databases    = try(local.raw_yaml.database, [])
    integrations = try(local.raw_yaml.s3_integration, [])
    stages       = try(local.raw_yaml.stage, [])
    service_user = try(local.raw_yaml.service_user, "")
  }

  # now transform each section - icky hack on forcing tobool to fail
  warehouses = {
    for wh in local.yaml.warehouses :
    lookup(wh, "name", "") => {
      size              = lookup(wh, "size", "XSMALL")
      max_cluster_count = lookup(wh, "clusters", 1)
      comment           = lookup(wh, "comment", "Created by ${local.repo}")
      accounts          = lookup(wh, "account", [local.default_account])
    }
  }
  databases = {
    for db in local.yaml.databases :
    can(db.name) ? "${db.name}_${local.env}" : "" => {
      extra_schemas = lookup(db, "extra_schemas", [])
      comment       = lookup(db, "comment", "Created by ${local.repo}")
      accounts      = lookup(db, "account", [local.default_account])
    }
  }
  integrations = {
    for ig in local.yaml.integrations :
    can(ig.name) ? "${ig.name}_${local.env}" : "" => {
      allowed_locations = [
        for loc in ig.allowed_locations : loc
      ]
      comment  = lookup(ig, "comment", "Created by ${local.repo}")
      accounts = lookup(ig, "account", [local.default_account])
    }
  }
  stages = {
    for sg in local.yaml.stages :
    can(sg.name) ? "${sg.name}_${local.env}" : "" => {
      location    = sg.location
      integration = sg.integration
      comment     = lookup(sg, "comment", "Created by ${local.repo}")
      accounts    = lookup(sg, "account", [local.default_account])
    }
  }
  service_user = local.yaml.service_user.name

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


# run some validation checks
resource "terraform_data" "validate_sections" {
  input = {
    warehouses   = local.yaml.warehouses
    databases    = local.yaml.databases
    integrations = local.yaml.integrations
    stages       = local.yaml.stages
  }

  lifecycle {
    precondition {
      condition     = alltrue([for wh in local.yaml.warehouses : can(wh.name)])
      error_message = "ERROR: All warehouses must have a name - please check config.yml"
    }
    precondition {
      condition     = alltrue([for db in local.yaml.databases : can(db.name)])
      error_message = "ERROR: All databases must have a name - please check config.yml"
    }
    postcondition {
      condition     = alltrue([for ig in local.yaml.integrations : can(ig.name)])
      error_message = "ERROR: All integrations must have a name - please check config.yml"
    }
    postcondition {
      condition     = alltrue([for sg in local.yaml.stages : can(sg.name)])
      error_message = "ERROR: All stages must have a name - please check config.yml"
    }
  }
}

# now pretend to call the modules  

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
  providers         = { tfcoremock = tfcoremock.LONDON } # terraform doesn't allow dynamic provider selection
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
