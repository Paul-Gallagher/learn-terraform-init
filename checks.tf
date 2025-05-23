####################################################################################
# checks.tf: these only run during a plan or apply so can't be in the /tests/ folder
#
# written as pre-conditions rather than checks 'cos checks are just warnings
#
# NB: uses symlinked config.tf and config.yaml
####################################################################################

variable "schema" { default = "config_meta.yaml" }

locals {
  meta_config = yamldecode(file(var.schema))

  wh_name_regex      = local.meta_config.warehouse.name
  db_name_regex      = local.meta_config.database.name
  schema_regex       = local.meta_config.database.schema
  integration_regex  = local.meta_config.integration.name
  bucket_regex       = local.meta_config.integration.buckets
  stage_regex        = local.meta_config.integration.stage.name
  service_user_regex = local.meta_config.service_user.name

  standard_sizes = local.meta_config.warehouse.size
  extended_sizes = local.meta_config.warehouse.sizex
  all_sizes      = concat(local.standard_sizes, local.extended_sizes)
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

    ### ROOT LEVEL CHECKS ##############################################################

    # environment
    precondition {
      condition     = contains(local.meta_config.env, local.root_env)
      error_message = "ERROR: Invalid root environment '${local.root_env}'\n\nValid environments are:\n${yamlencode(local.meta_config.env)}"
    }

    # location  
    precondition {
      condition     = contains(local.meta_config.location, local.root_location)
      error_message = "ERROR: Invalid root location '${local.root_location}'\n\nValid locations are:\n${yamlencode(local.meta_config.location)}"
    }

    ### WAREHOUSE CHECKS ###############################################################

    # location - not actually needed 'cos config.tf filters warehouses by location
    precondition {
      condition = length(local.warehouses) == 0 || alltrue([
        for key, wh in local.warehouses :
        contains(local.meta_config.location, wh.location)
      ])
      error_message = "ERROR: Invalid Warehouse location(s):\n${join("\n", [
        for key, wh in local.warehouses :
        "  - ${wh.name}: ${wh.location}"
        if !contains(local.meta_config.location, wh.location)
      ])}\nValid locations are: ${jsonencode(local.meta_config.location)}"
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
        # straw man: WHX_ warehouses can be of a larger size - see config_meta.yaml
        can(regex("^WHX_", wh.name)) ?
        contains(local.all_sizes, wh.size) :
        contains(local.standard_sizes, wh.size)
      ])
      # hideously complex expression 'cos I wanted the message hints to be specific depending on the warehousename 
      error_message = join("", [
        "ERROR: Invalid Warehouse size(s):\n${join("\n", [
          # this part iterates thu the warehouses generating a list of this in error
          for key, wh in local.warehouses :
          "  - ${wh.name}: ${wh.size} (${can(regex("^WHX_", wh.name)) ? "extended size" : "standard size"})"
          if can(regex("^WHX_", wh.name)) ?
          !contains(local.all_sizes, wh.size) :
          !contains(local.standard_sizes, wh.size)
        ])}\n\n",

        # while this part shows the appropriate list of valid sizes based on the warehouse name (ie type)
        length([
          for key, wh in local.warehouses :
          wh.name
          if can(regex("^WHX_", wh.name)) && !contains(local.all_sizes, wh.size)
        ]) > 0 ?
        "Valid extended sizes are:\n${yamlencode(local.all_sizes)}" :
        "Valid standard sizes are:\n${yamlencode(local.standard_sizes)}"
      ])
    }

    # cluster
    precondition {
      condition = length(local.warehouses) == 0 || alltrue([
        for key, wh in local.warehouses :
        wh.max_cluster_count <= lookup(
          local.meta_config.warehouse.cluster,
          wh.size,
          10
        )
      ])
      error_message = "ERROR: Invalid cluster count for warehouses:\n${join("\n", [
        for key, wh in local.warehouses :
        "  - ${wh.name}: max_cluster_count ${wh.max_cluster_count} exceeds limit of ${
          lookup(
            local.meta_config.warehouse.cluster,
            wh.size,
            10
          )
        } for size ${wh.size}"
        if wh.max_cluster_count > lookup(
          local.meta_config.warehouse.cluster,
          wh.size,
          10
        )
      ])}"
    }

    ### DATABASE CHECKS ################################################################

    # environment - not needed 'cos config.tf filters databases by environment
    precondition {
      condition = length(local.databases) == 0 || alltrue([
        for key, db in local.databases :
        contains(local.meta_config.env, db.env)
      ])
      error_message = "Invalid Database environment(s):\n${join("\n", [
        for key, db in local.databases :
        "  - ${db.name}: ${db.env}"
        if !contains(local.meta_config.env, db.env)
      ])}\nValid environments are: ${jsonencode(local.meta_config.env)}"
    }

    # location - not needed 'cos config.tf filters databases by environment
    precondition {
      condition = length(local.databases) == 0 || alltrue([
        for key, db in local.databases :
        contains(local.meta_config.location, db.location)
      ])
      error_message = "Invalid Database location(s):\n${join("\n", [
        for key, db in local.databases :
        "  - ${db.name}: ${db.location}"
        if !contains(local.meta_config.location, db.location)
      ])}\nValid locations are: ${jsonencode(local.meta_config.location)}"
    }

    # name
    precondition {
      condition = (
        length(local.databases) == 0 || alltrue([
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
        alltrue([
          for schema in db.extra_schemas :
          can(regex(local.schema_regex, schema))
        ])
      ])
      error_message = "Invalid extra_schemas configuration:\n${join("\n", [
        for key, db in local.databases :
        "  - ${db.name}: ${jsonencode(db.extra_schemas)}"
        if !alltrue([
          for schema in db.extra_schemas :
          can(regex(local.schema_regex, schema))
        ])
      ])}\n\nExtra schemas must match the pattern: ${local.schema_regex}"
    }


    ### INTEGRATION CHECKS #############################################################

    # environment - not needed 'cos config.tf filters databases by environment
    precondition {
      condition = length(local.integrations) == 0 || alltrue([
        for key, ig in local.integrations :
        contains(local.meta_config.env, ig.env)
      ])
      error_message = "Invalid Integration environment(s):\n${join("\n", [
        for key, ig in local.integrations :
        "  - ${ig.name}: ${ig.env}"
        if !contains(local.meta_config.env, ig.env)
      ])}\nValid environments are: ${jsonencode(local.meta_config.env)}"
    }

    # location - not needed 'cos config.tf filters databases by location
    precondition {
      condition = length(local.integrations) == 0 || alltrue([
        for key, ig in local.integrations :
        contains(local.meta_config.location, ig.location)
      ])
      error_message = "Invalid Integration location(s):\n${join("\n", [
        for key, ig in local.integrations :
        "  - ${ig.name}: ${ig.location}"
        if !contains(local.meta_config.location, ig.location)
      ])}\nValid locations are: ${jsonencode(local.meta_config.location)}"
    }

    # name
    precondition {
      condition = (
        length(local.integrations) == 0 || alltrue([
          for key, ig in local.integrations :
          can(regex(local.integration_regex, ig.name))
        ])
      )
      error_message = "Invalid Integration name(s):\n${join("\n", [
        for key, ig in local.integrations :
        "  - ${ig.name}"
        if !can(regex(local.integration_regex, ig.name))
      ])}\nIntegration names must match pattern: ${local.integration_regex}"
    }

    # buckets
    precondition {
      condition = length(local.integrations) == 0 || alltrue([
        for key, ig in local.integrations :
        alltrue([
          for bucket in ig.buckets :
          can(regex(local.bucket_regex, bucket))
        ])
      ])
      error_message = "ERROR: Invalid bucket configuration:\n${join("\n", [
        for key, ig in local.integrations :
        "  - ${ig.name}: ${jsonencode(ig.buckets)}"
        if !alltrue([
          for bucket in ig.buckets :
          can(regex(local.bucket_regex, bucket))
        ])
      ])}\n\nBucket names must match pattern: ${local.bucket_regex}"
    }

    # stage name check
    precondition {
      condition = length(local.integrations) == 0 || alltrue([
        for key, ig in local.integrations :
        length(lookup(ig, "stage", [])) == 0 || alltrue([
          for stage in lookup(ig, "stage", []) :
          can(regex(local.stage_regex, stage.name))
        ])
      ])
      error_message = "ERROR: Invalid stage name configuration:\n${join("\n", [
        for key, ig in local.integrations :
        join("\n", [
          for stage in lookup(ig, "stage", []) :
          "  - ${ig.name}: stage ${stage.name}"
          if !can(tostring(stage.name)) || !can(regex(local.stage_regex, stage.name))
        ])
      ])}\n\nStage names must match pattern: ${local.stage_regex}"
    }

    # stage buckets =  check the bucket exists in parent integration's list of buckets
    precondition {
      condition = length(local.integrations) == 0 || alltrue([
        for key, ig in local.integrations :
        length(lookup(ig, "stage", [])) == 0 || alltrue([
          for stage in lookup(ig, "stage", []) :
          contains(ig.buckets, stage.bucket)
        ])
      ])
      error_message = "ERROR: Invalid stage bucket selection:\n${join("\n", [
        for key, ig in local.integrations :
        join("", [
          join("\n", [
            for stage in lookup(ig, "stage", []) :
            "  - ${ig.name}: stage ${stage.name} using '${stage.bucket}' "
            if !contains(ig.buckets, stage.bucket)
          ]),
          length([
            for stage in lookup(ig, "stage", []) :
            stage.name
            if !contains(ig.buckets, stage.bucket)
          ]) > 0 ? "\n\nAvailable buckets for ${ig.name} are:\n${yamlencode(ig.buckets)}" : ""
        ])
      ])}"
    }

    ### SERVICE USER CHECKS ############################################################

    # name
    precondition {
      condition = length(local.service_users) == 0 || alltrue([
        for key, user in local.service_users :
        can(regex(local.service_user_regex, user.name))
      ])
      error_message = "ERROR: Invalid service_user name(s):\n${join("\n", [
        for key, user in local.service_users :
        "  - ${user.name}"
        if !can(regex(local.service_user_regex, user.name))
      ])}\n\nService user names must match pattern: ${local.service_user_regex}"
    }

  } # lifecycle
}   # resource
