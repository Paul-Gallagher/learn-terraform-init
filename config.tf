####################################################################################
# Parse, transform and validate the Snowflake section in a [config.yaml] file
#
# Input: name of the configuration file - default is config.yaml
# Output: a map of maps for each resource type (warehouses, databases, etc)
#
# Overview: Transform and enhance each resource sub-section
#  - add defaults - such as Snowflake location or warehouse size
#  - filter out unwanted environments
#  - deal with multiple environments, multiple Snowflake locations and case insensitivity
#  - build a tags map from yaml outside the SSnowflake section
#  - run some rudimentary checks - eg each resource has a name
#
# Example uses: terraform apply -auto-approve
#               terraform apply -auto-approve -var env=uat -var config=demo.yaml
#
# Notes: valid locations and defaults should come from some central location
####################################################################################

variable "config" { default = "config.yaml" }
variable "locations" { default = ["BA_IRELAND", "BA_LONDON", "BA_BANGKOK"] }

locals {
  # constants
  default_location = var.locations[0]
  default_wh_size  = "XSMALL"
  defaut_clusters  = 1
  default_comment  = "Created by ${local.repo}"


  # first read the configuration file as a plain string
  raw_content = file("${path.module}/${var.config}")

  # run any string interpolation(s) - e.g. replace ${env} with the actual env name
  cooked_content = replace(local.raw_content, "$${env}", local.env)

  # decode the yaml and pull out the Snowflake section - if it exists
  raw_yaml = try(yamldecode(local.cooked_content).Snowflake, null)

  # do we have a Snowflake location override section - this is a key into Secrets Manager (?)
  resource_location = try(local.raw_yaml.location, local.default_location)

  # all sub-sections are optional, so we need to set up suitable defaults - mostly empty lists
  yaml = {
    warehouses    = try(local.raw_yaml.warehouse, {})
    databases     = try(local.raw_yaml.database, {})
    integrations  = try(local.raw_yaml.s3_integration, {})
    stages        = try(local.raw_yaml.stage, {})
    service_users = try(local.raw_yaml.service_user, {})
  }

  # now transform each section

  # Here is the original simple version - however it didn't allow merging of items with the same name
  # or allowing lists with a single entry to be specified as a string in the yaml
  #   warehouses = {
  #     for wh in local.yaml.warehouses :
  #     lookup(wh, "name", "") => {
  #       size               = lookup(wh, "size", local.default_wh_size)
  #       max_cluster_count  = lookup(wh, "clusters", local.default_clusters)
  #       comment            = lookup(wh, "comment", local.default_comment)
  #       location           = lookup(wh, "location", local.resource_location)
  #     }
  #     if contains(lookup(wh, "env", [local.env]), local.env)
  #   }

  # Normally, expect items with the SAME name to be for different environments
  # This more complex version deals with edge cases where this is not the case (eg user error)
  # This version also allows singe-value lists to be specified by a string
  # A later addition to allow differences between locations added extra complexity
  # In the end I broke it down into two steps for a bit of extra legibility

  # Step 1: Filter warehouse entries and add default values
  filtered_warehouses = [
    for wh in local.yaml.warehouses :
    {
      name              = lookup(wh, "name", "")
      size              = upper(lookup(wh, "size", local.default_wh_size))
      max_cluster_count = lookup(wh, "clusters", local.defaut_clusters)
      comment           = lookup(wh, "comment", "Created by ${local.repo}")
      env               = lookup(wh, "env", [local.env]) # don't need this except for debugging
      # convert location to an uppercase comma separated string (simplifies the next step)
      locations = try(
        # if it's already a string, use it directly
        upper(tostring(lookup(wh, "location", local.default_location))),
        # if it's a list, join it with commas
        join(",", [for a in lookup(wh, "location", [local.default_location]) : upper(a)])
      )
    }
    # filter to include only entries for the current environment
    if contains(
      # convert env entry to a list if it's given as a string
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

  # Step 2: Group by name and location - giving us a map of maps, with name_location as the key
  grouped_warehouses = {
    for item in flatten([
      for entry in local.filtered_warehouses : [
        for location in split(",", entry.locations) : { # here's our comma-separated locations (see above)
          key               = "${entry.name}_${location}"
          name              = entry.name
          size              = entry.size
          max_cluster_count = entry.max_cluster_count
          comment           = entry.comment
          location          = location
        }
      ]
    ]) : item.key => item...
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
      location          = entries[length(entries) - 1].location
    }
  }

  # jump thru similar loops for the other resource types - no obvious way of DRY-ing this up

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
      locations     = lookup(db_list[length(db_list) - 1], "location", [local.resource_location])
      locations = try(
        tolist(lookup(db_list[length(db_list) - 1], "location", [local.resource_location])),
        [lookup(db_list[length(db_list) - 1], "location", local.resource_location)]
      )
    }
  }
  integrations = {
    for ig in local.yaml.integrations :
    can(ig.name) ? "${ig.name}_${local.env}" : "" => {
      allowed_locations = [
        for loc in ig.allowed_locations : loc
      ]
      comment   = lookup(ig, "comment", "Created by ${local.repo}")
      locations = lookup(ig, "location", [local.resource_location])
    }
  }
  stages = {
    for sg in local.yaml.stages :
    can(sg.name) ? "${sg.name}_${local.env}" : "" => {
      location    = sg.location
      integration = sg.integration
      comment     = lookup(sg, "comment", "Created by ${local.repo}")
      locations   = lookup(sg, "location", [local.resource_location])
    }
  }
  service_users = { #
    for su in local.yaml.service_users :
    can(su.name) ? "${su.name}_${local.env}" : "" => {
      comment   = lookup(su, "comment", "Created by ${local.repo}")
      locations = lookup(su, "location", [local.resource_location])
    }
  }
}

# run some validation checks
resource "terraform_data" "validate_sections" {
  input = {
    warehouses    = local.warehouses
    databases     = local.databases
    integrations  = local.integrations
    stages        = local.stages
    service_users = local.service_users
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
      condition     = alltrue([for name, _ in local.service_users : name != ""])
      error_message = "ERROR: service_user must have a name - please check config.yml"
    }
  }

}

# --- these are purely for debugging ------------------------------------

# output "validation_inputs" {
#   description = "Transformed yaml as passed to the validation checks"
#   value       = terraform_data.validate_sections.input
# }

# output "aws_account" { value = local.aws_account }
# output "yaml_warehouses" { value = local.yaml.warehouses }
output "filtered_warehouses" { value = local.filtered_warehouses }
output "grouped_warehouses" { value = local.grouped_warehouses }
output "warehouses" { value = local.warehouses }
output "databases" { value = local.databases }
# output "integrations" { value = local.integrations }
# output "stages" { value = local.stages }
output "service_users" { value = local.service_users }
