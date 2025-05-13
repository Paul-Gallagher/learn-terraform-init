# Parses our data project's config.yaml file and extracts the Snowflake section 
#
# It then enhances each section with defaults - such as Snowflake account or warehouse size
# Finally some rudimentary checks are run - eg that each resource has a name

locals {

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

  # now transform each section

  # this was the original simple version - however it didn't allow merging of items with the same name
  # or allowing lists with a single entry to be specified as a string in the yaml
  #   warehouses = {
  #     for wh in local.yaml.warehouses :
  #     lookup(wh, "name", "") => {
  #       size              = lookup(wh, "size", "XSMALL")
  #       max_cluster_count = lookup(wh, "clusters", 1)
  #       comment           = lookup(wh, "comment", "Created by ${local.repo}")
  #       accounts          = lookup(wh, "account", [local.default_account])
  #     }
  #     if contains(lookup(wh, "env", ["dev"]), "dev")
  #   }

  # I'd expect items with the same name to be for different environments
  # this more complex version deals with edge cases where this is not the case
  # It also allows lists with a single item to be specified without the brackets
  warehouses = {
    # this outer loop iterates over the grouped values returned by the inner loop
    for name, wh_list in {
      # this inner loop uses the ellipsis operator (...) to group all keys with the same name
      # it has a filter to include only entries for the current environment
      for wh in local.yaml.warehouses :
      lookup(wh, "name", "") => wh...
      if contains(
        # convert env entry to a list if it's given as a string
        [for e in(
          try(
            # Try to access as a list - will fail if it's a string
            tolist(lookup(wh, "env", [local.env])),
            # Fallback - treat as a string and wrap in a list
            [lookup(wh, "env", local.env)]
          )
        ) : upper(e)],
        local.env
      )
    } :
    name => {
      # Set defaults and transform, taking the last item in the group  (wh_list[length(wh_list) - 1])
      # this means we lose any earlier definition with the same name for the same environment
      size              = lookup(wh_list[length(wh_list) - 1], "size", "XSMALL")
      max_cluster_count = lookup(wh_list[length(wh_list) - 1], "clusters", 1)
      comment           = lookup(wh_list[length(wh_list) - 1], "comment", "Created by ${local.repo}")
      # accounts can be a string or list  
      accounts = try(
        # try to access as a list - which will fail if it's a string
        tolist(lookup(wh_list[length(wh_list) - 1], "account", [local.default_account])),
        # ww couldn't access it as a list so we must have a string (quacks like one anyway)
        [lookup(wh_list[length(wh_list) - 1], "account", local.default_account)]
      )
    }
  }

  databases = {
    # see walkthru of warehouses above
    for name, db_list in {
      for db in local.yaml.databases :
      lookup(db, "name", "") => db...
      if contains(
        [for e in(
          try(
            tolist(lookup(db, "env", [local.env])),
            [lookup(db, "env", local.env)]
          )
        ) : upper(e)],
        local.env
      )
    } :
    # stitch an _env suffix onto the name
    can(name) ? "${name}_${local.env}" : "" => {
      extra_schemas = lookup(db_list[length(db_list) - 1], "extra_schemas", [])
      comment       = lookup(db_list[length(db_list) - 1], "comment", "Created by ${local.repo}")
      accounts      = lookup(db_list[length(db_list) - 1], "account", [local.default_account])
      accounts = try(
        tolist(lookup(db_list[length(db_list) - 1], "account", [local.default_account])),
        [lookup(db_list[length(db_list) - 1], "account", local.default_account)]
      )
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
  service_user = {
    name     = can(local.yaml.service_user) ? "${local.yaml.service_user.name}_${local.env}" : ""
    comment  = lookup(local.yaml.service_user, "comment", "Created by ${local.repo}")
    accounts = lookup(local.yaml.service_user, "account", [local.default_account])
  }

}

# run some validation checks
resource "terraform_data" "validate_sections" {
  input = {
    warehouses   = local.warehouses
    databases    = local.databases
    integrations = local.integrations
    stages       = local.stages
    service_user = local.service_user
  }

  lifecycle {
    precondition {
      condition     = alltrue([for name, _ in local.warehouses : name != ""])
      error_message = "ERROR: All warehouses must have a name - please check config.yml"
    }
    precondition {
      condition     = alltrue([for name, _ in local.databases : name != ""])
      error_message = "ERROR: All databases must have a name - please check config.yml"
    }
    precondition {
      condition     = alltrue([for name, _ in local.integrations : name != ""])
      error_message = "ERROR: All integrations must have a name - please check config.yml"
    }
    precondition {
      condition     = alltrue([for name, _ in local.stages : name != ""])
      error_message = "ERROR: All stages must have a name - please check config.yml"
    }
    precondition {
      condition     = local.service_user.name != ""
      error_message = "ERROR: service_user must have a name - please check config.yml"
    }
  }

}

# useful for debugging - show the transformed yaml
# output "validation_inputs" {
#   description = "Transformed yaml as passed to the validation checks"
#   value       = terraform_data.validate_sections.input
# }
