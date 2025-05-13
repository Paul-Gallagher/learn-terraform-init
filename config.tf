# Parses our data project's config.yaml file and extracts the Snowflake section 
#
# It then enhances each section with defaults - such as Snowflake account or warehouse size
# Finally some rudimentary checks are run - eg that each resource has a name

locals {

  # constants
  default_account = "IRELAND"
  default_wh_size = "XSMALL"
  defaut_clusters = 1
  default_comment = "Created by ${local.repo}"


  # first read the file as a plain string
  raw_content = file("${path.module}/config.yaml")

  # run our string interpolations - e.g. replace ${env} with the actual env name
  cooked_content = replace(local.raw_content, "$${env}", local.env)

  # now decode the yaml an pull out the Snowflake section - if it exists
  raw_yaml = try(yamldecode(local.cooked_content).Snowflake, null)

  # do we have a Snowflake account override section - this is a key into Secrets Manager (?)
  snowflake_account = try(local.raw_yaml.account, local.default_account)

  # all sub-sections are optional, so we need to set up suitable defaults - mostly empty lists
  yaml = {
    warehouses   = try(local.raw_yaml.warehouse, [])
    databases    = try(local.raw_yaml.database, [])
    integrations = try(local.raw_yaml.s3_integration, [])
    stages       = try(local.raw_yaml.stage, [])
    service_user = try(local.raw_yaml.service_user, "")
  }

  # now transform each section

  # Here is the original simple version - however it didn't allow merging of items with the same name
  # or allowing lists with a single entry to be specified as a string in the yaml
  #   warehouses = {
  #     for wh in local.yaml.warehouses :
  #     lookup(wh, "name", "") => {
  #       size              = lookup(wh, "size", local.default_wh_size)
  #       max_cluster_count = lookup(wh, "clusters", local.default_clusters)
  #       comment           = lookup(wh, "comment", local.default_comment)
  #       account           = lookup(wh, "account", local.snowflake_account)
  #     }
  #     if contains(lookup(wh, "env", [local.env]), local.env)
  #   }

  # Normally, expect items with the SAME name to be for different environments
  # This more complex version deals with edge cases where this is not the case (eg user error)
  # This version also allows singe-value lists to be specified by a string
  # A later addition to allow differences between accounts added extra complexity
  # In the end I broke it down into two steps for a bit of extra legibility

  # Step 1: Filter warehouse entries and add default values
  filtered_warehouses = [
    for wh in local.yaml.warehouses :
    {
      name              = lookup(wh, "name", "")
      account           = upper(lookup(wh, "account", local.default_account))
      size              = lookup(wh, "size", local.default_wh_size)
      max_cluster_count = lookup(wh, "clusters", local.defaut_clusters)
      comment           = lookup(wh, "comment", "Created by ${local.repo}")
      env               = lookup(wh, "env", [local.env]) # don't need this except for debugging

    }
    # filter to include only entries for the current environment
    if contains(
      # cConvert env entry to a list if it's given as a string
      [for e in(
        try(
          # try to access as a list - will fail if it's a string
          tolist(lookup(wh, "env", [local.env])),
          # fallback - treat as a string and wrap in a list
          [lookup(wh, "env", local.env)]
        )
      ) : upper(e)],
      local.env
    )
  ]

  # Step 2: Group by name and account - giving us a map of maps, with name_account as the key
  grouped_warehouses = {
    # create a composite key from name and account, the ellipsis(...) groups entries with the same key
    for entry in local.filtered_warehouses :
    "${entry.name}_${entry.account}" => entry...
  }

  # Step 3: Finally, take the last entry for each group (eg someone mistakenly misses an environment definition)
  warehouses = {
    for key, entries in local.grouped_warehouses :
    key => {
      # take the last entry in each group (most recent definition in the yaml)
      name              = entries[length(entries) - 1].name
      size              = entries[length(entries) - 1].size
      max_cluster_count = entries[length(entries) - 1].max_cluster_count
      comment           = entries[length(entries) - 1].comment
      account           = entries[length(entries) - 1].account
    }
  }
  # jump thru similar loops for the other resource types

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
      accounts      = lookup(db_list[length(db_list) - 1], "account", [local.snowflake_account])
      accounts = try(
        tolist(lookup(db_list[length(db_list) - 1], "account", [local.snowflake_account])),
        [lookup(db_list[length(db_list) - 1], "account", local.snowflake_account)]
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
      accounts = lookup(ig, "account", [local.snowflake_account])
    }
  }
  stages = {
    for sg in local.yaml.stages :
    can(sg.name) ? "${sg.name}_${local.env}" : "" => {
      location    = sg.location
      integration = sg.integration
      comment     = lookup(sg, "comment", "Created by ${local.repo}")
      accounts    = lookup(sg, "account", [local.snowflake_account])
    }
  }
  service_user = {
    name     = can(local.yaml.service_user) ? "${local.yaml.service_user.name}_${local.env}" : ""
    comment  = lookup(local.yaml.service_user, "comment", "Created by ${local.repo}")
    accounts = lookup(local.yaml.service_user, "account", [local.snowflake_account])
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
