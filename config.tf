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
#  - build a tags map from yaml outside the Snowflake section
#  - run some rudimentary checks - eg each resource has a name
#
# Example uses: terraform apply -auto-approve
#               terraform apply -auto-approve -var env=uat -var config=demo.yaml
#
# Notes: valid locations and defaults should come from some central location
####################################################################################

# needs these variables from elsewhere (eg defined in main.tf but set by Githyb workflow)
# variable "env"      { type = string }  
# variable "location" { type = string }
# variable "repo"     { type = string }


# allow changing the config file - useful during debugging
variable "config" { default = "config.yaml" }


locals {
  env      = upper(var.env)
  location = upper(var.location)
  repo     = upper(var.repo)

  # constants - used as defaults - get these from elsewhere
  default_location = "BA_IRELAND"
  default_wh_size  = "XSMALL"
  defaut_clusters  = 1
  default_comment  = "Created by ${local.repo}"


  # first read the configuration file as a plain string
  raw_content = file("${path.module}/${var.config}")

  # run any string interpolation(s) - e.g. replace ${env} with the actual env name
  cooked_content = replace(local.raw_content, "$${env}", local.env)

  # decode the yaml and pull out the Snowflake section - if it exists
  raw_yaml = try(yamldecode(local.cooked_content).Snowflake, null)

  # do we have root-level Snowflake location ooverride
  resource_location = try(local.raw_yaml.location, local.default_location)

  # all sub-sections are optional, so we need to set up suitable defaults - mostly empty lists
  yaml = {
    warehouses   = try(local.raw_yaml.warehouse, {})
    databases    = try(local.raw_yaml.database, {})
    integrations = try(local.raw_yaml.integration, {})
    # stages        = try(local.raw_yaml.stage, {})
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

  # Normally, we'd expect items with the SAME name to be for different environments and locations
  # This more complex version deals with edge cases where this is not the case (eg user error)
  # This version also allows singe-value lists to be specified by a string
  # A later addition to allow differences between locations added extra complexity
  # In the end I broke it down into two steps for a bit of extra legibility

  # Step 1: Filter warehouse entries and add defaults for missing keys
  filtered_warehouses = [
    for wh in local.yaml.warehouses :
    {
      name              = lookup(wh, "name", "")
      size              = upper(lookup(wh, "size", local.default_wh_size))
      max_cluster_count = lookup(wh, "clusters", local.defaut_clusters)
      comment           = lookup(wh, "comment", "Created by ${var.repo}")
      env               = local.env
      location          = local.location
    }
    # filter out entries other than those for the current environment and location
    if contains(
      [ # make sure the env entry is a list of strings
        for e in(
          try(
            # try to access it as a list - which will fail if it's a mere string
            tolist(lookup(wh, "env", [local.env])),
            # fallback - treat it as a string and wrap in a list
            [lookup(wh, "env", local.env)]
          )
    ) : upper(e)], local.env)
    && contains(
      [ # similar logic for location - allow it to be a list or a string
        for l in(
          try(
            tolist(lookup(wh, "location", [local.resource_location])),
            [lookup(wh, "location", local.resource_location)]
          )
    ) : upper(l)], local.location)
  ]

  # Step 2: Group warehouses by name and location and take the latest definition for each group
  # This handles duplicate entries in the yaml with the same name, environment and location  
  # This grouping step is needed when someone mistakenly defines the same warehouse multiple times
  warehouses = {
    for key, entries in {
      # this inner loop groups the warehouses by name and location using a composite key
      # the ellipsis(...) operator collects entries with the same key into arrays
      # allowing us to use "last definition wins" semantics
      for entry in local.filtered_warehouses :
      "${entry.name}_${entry.location}" => entry...
    } :
    key => {
      # take the last entry in each group (ie the lowest definition in the yaml)
      name              = entries[length(entries) - 1].name
      size              = entries[length(entries) - 1].size
      max_cluster_count = entries[length(entries) - 1].max_cluster_count
      comment           = entries[length(entries) - 1].comment
      location          = entries[length(entries) - 1].location
    }
  }

  # jump thru similar loops for the other resource types - no obvious way of DRY-ing this up

  filtered_databases = [
    for db in local.yaml.databases :
    {
      name          = lookup(db, "name", "")
      extra_schemas = lookup(db, "extra_schemas", [])
      comment       = lookup(db, "comment", "Created by ${local.repo}")
      env           = local.env
      location      = local.location
    }
    # filter - see comments for filtered_warehouses above
    if contains([for e in(
      try(
        tolist(lookup(db, "env", [local.env])),
        [lookup(db, "env", local.env)]
      )
    ) : upper(e)], local.env)
    && contains([for l in(
      try(
        tolist(lookup(db, "location", [local.resource_location])),
        [lookup(db, "location", local.resource_location)]
      )
    ) : upper(l)], local.location)
  ]

  databases = {
    for key, entries in {
      for entry in local.filtered_databases :
      "${entry.name}_${entry.location}" => entry...
    } :
    key => {
      # take the last entry in each group (ie the lowest definition in the yaml)
      name          = entries[length(entries) - 1].name
      extra_schemas = entries[length(entries) - 1].extra_schemas
      comment       = entries[length(entries) - 1].comment
      location      = entries[length(entries) - 1].location
    }
  }

  filtered_integrations = [
    for ig in local.yaml.integrations :
    {
      name              = lookup(ig, "name", "")
      allowed_locations = lookup(ig, "allowed_locations", [])
      stages            = lookup(ig, "stages", [])
      comment           = lookup(ig, "comment", "Created by ${local.repo}")
      env               = local.env
      location          = local.location
    }
    # filter - see comments for filtered_warehouses above
    if contains([for e in(
      try(
        tolist(lookup(ig, "env", [local.env])),
        [lookup(ig, "env", local.env)]
      )
    ) : upper(e)], local.env)
    && contains([for l in(
      try(
        tolist(lookup(ig, "location", [local.resource_location])),
        [lookup(ig, "location", local.resource_location)]
      )
    ) : upper(l)], local.location)
  ]


  integrations = {
    for key, entries in {
      for entry in local.filtered_integrations :
      "${entry.name}_${entry.location}" => entry...
    } :
    key => {
      # take the last entry in each group (ie the lowest definition in the yaml)
      name              = entries[length(entries) - 1].name
      allowed_locations = entries[length(entries) - 1].allowed_locations
      comment           = entries[length(entries) - 1].comment
      location          = entries[length(entries) - 1].location
    }
  }

  #   stages = {
  #     for sg in local.yaml.stages :
  #     can(sg.name) ? "${sg.name}_${local.env}" : "" => {
  #       location    = sg.location
  #       integration = sg.integration
  #       comment     = lookup(sg, "comment", "Created by ${local.repo}")
  #       locations   = lookup(sg, "location", [local.resource_location])
  #     }
  #   }

  service_users = {
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
    warehouses   = local.warehouses
    databases    = local.databases
    integrations = local.integrations
    # stages        = local.stages
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
    # precondition {
    #   condition     = alltrue([for name, _ in local.stages : name != ""])
    #   error_message = "ERROR: All stages must have a name - please check config.yml"
    # }
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

# output "yaml_warehouses" { value = local.yaml.warehouses }
# output "filtered_warehouses" { value = local.filtered_warehouses }
output "warehouses" { value = local.warehouses }
# output "filtered_databases" { value = local.filtered_databases }
output "databases" { value = local.databases }
output "filtered_integrations" { value = local.filtered_integrations }
output "integrations" { value = local.integrations }
# output "stages" { value = local.stages }
output "service_users" { value = local.service_users }
