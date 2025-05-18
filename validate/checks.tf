####################################################################################
# checks.tf: these only run during a plan or apply so can't be in the /tests/ folder
#
# written as pre-conditions rather than checks 'cos checks are just warnings
#
# NB: uses symlinked config.tf and config.yaml
####################################################################################

variable "schema" { default = "snowflake_schema.yaml" }

locals {
  schema_config = yamldecode(file(var.schema))

  wh_name_regex = local.schema_config.warehouse.name
  db_name_regex = local.schema_config.database.name
  schema_regex  = local.schema_config.database.schema
}

resource "terraform_data" "validate_sections" {
  input = {
    warehouses   = local.warehouses
    databases    = local.databases
    integrations = local.integrations
    # stages        = local.stages
    service_users = local.service_users
  }

  lifecycle {

    ### WAREHOUSE CHECKS ###############################################################

    # location
    precondition {
      condition = length(local.warehouses) == 0 || alltrue([
        for key, wh in local.warehouses :
        contains(local.schema_config.location, wh.location)
      ])
      error_message = "ERROR: Invalid Warehouse location(s):\n${join("\n", [
        for key, wh in local.warehouses :
        "  - ${wh.name}: ${wh.location}"
        if !contains(local.schema_config.location, wh.location)
      ])}\nValid locations are: ${jsonencode(local.schema_config.location)}"
    }

    # name
    precondition {
      condition = length(local.warehouses) == 0 || alltrue([
        for key, wh in local.warehouses :
        can(regex(local.wh_name_regex, wh.name))
      ])
      error_message = "ERROR: Invalid Warehouse name(s):\n${join("\n", [
        for key, wh in local.warehouses :
        "  - ${wh.name}"
        if !can(regex(local.wh_name_regex, wh.name))
      ])}\nWarehouse names must match pattern: ${local.wh_name_regex}"
    }

    # size
    precondition {
      condition = length(local.warehouses) == 0 || alltrue([
        for key, wh in local.warehouses :
        # straw man: WHX_ warehouses can be of a larger size - see snowflake_schema.yaml
        can(regex("^WHX_", wh.name)) ?
        contains(local.schema_config.warehouse.sizex, wh.size) :
        contains(local.schema_config.warehouse.size, wh.size)
      ])
      error_message = "ERROR: Invalid Warehouse size(s):\n${join("\n", [
        for key, wh in local.warehouses :
        "  - ${wh.name}: ${wh.size} (${can(regex("^WHX_", wh.name)) ? "extended size" : "standard size"})"
        if can(regex("^WHX_", wh.name)) ?
        !contains(local.schema_config.warehouse.sizex, wh.size) :
        !contains(local.schema_config.warehouse.size, wh.size)
      ])}\nValid standard sizes: ${jsonencode(local.schema_config.warehouse.size)}\nValid extended sizes: ${jsonencode(local.schema_config.warehouse.sizex)}"
    }

    # cluster
    precondition {
      condition = length(local.warehouses) == 0 || alltrue([
        for key, wh in local.warehouses :
        wh.max_cluster_count <= lookup(
          local.schema_config.warehouse.cluster,
          wh.size,
          10
        )
      ])
      error_message = "ERROR: Invalid cluster count for warehouses:\n${join("\n", [
        for key, wh in local.warehouses :
        "  - ${wh.name}: max_cluster_count ${wh.max_cluster_count} exceeds limit of ${
          lookup(
            local.schema_config.warehouse.cluster,
            wh.size,
            10
          )
        } for size ${wh.size}"
        if wh.max_cluster_count > lookup(
          local.schema_config.warehouse.cluster,
          wh.size,
          10
        )
      ])}"
    }

    ### DATABASE CHECKS ################################################################

    # environment
    precondition {
      condition = length(local.databases) == 0 || alltrue([
        for key, db in local.databases :
        contains(local.schema_config.env, db.env)
      ])
      error_message = "Invalid Database environment(s):\n${join("\n", [
        for key, db in local.databases :
        "  - ${db.name}: ${db.env}"
        if !contains(local.schema_config.env, db.env)
      ])}\nValid environments are: ${jsonencode(local.schema_config.env)}"
    }

    # location
    precondition {
      condition = length(local.databases) == 0 || alltrue([
        for key, db in local.databases :
        contains(local.schema_config.location, db.location)
      ])
      error_message = "Invalid Database location(s):\n${join("\n", [
        for key, db in local.databases :
        "  - ${db.name}: ${db.location}"
        if !contains(local.schema_config.location, db.location)
      ])}\nValid locations are: ${jsonencode(local.schema_config.location)}"
    }

    # name
    precondition {
      condition = (
        length(local.databases) == 0 ||
        alltrue([
          for key, db in local.databases :
          can(regex(local.db_name_regex, db.name))
        ])
      )
      error_message = "Invalid Database name(s):\n${join("\n", [
        for key, db in local.databases :
        "  - ${db.name}"
        if !can(regex(local.db_name_regex, db.name))
      ])}\nDatabase names must match pattern: ${local.db_name_regex}"
    }

    # extra schema
    precondition {
      condition = length(local.databases) == 0 || alltrue([
        for key, db in local.databases :
        can(tolist(db.extra_schemas)) &&
        alltrue([
          for schema in db.extra_schemas :
          can(tostring(schema)) &&
          can(regex("^${local.schema_regex}$", schema))
        ])
      ])
      error_message = "Invalid extra_schemas configuration:\n${join("\n", [
        for key, db in local.databases :
        "  - ${db.name}: ${jsonencode(db.extra_schemas)}"
        if !can(tolist(db.extra_schemas)) ||
        !alltrue([
          for schema in db.extra_schemas :
          can(tostring(schema)) &&
          can(regex("^${local.schema_regex}$", schema))
        ])
      ])}\nExtra schemas must match the pattern: ${local.schema_regex}"
    }

  }
}
