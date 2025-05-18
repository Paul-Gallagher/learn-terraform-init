####################################################################################
# warehouse1.tftest.hcl 
#
# I Wanted to exclude any debug.tftest.hcl files but -filter "!debug.tftest.hcl" doesn't work
#  - so move them to a separate sub-directory
#
# The first four tests check basic functionality:
#  - filtering by env and location
#  - expansion of ${env} - here only visible in the comments
#  - default env, location, size, clusters and comment
#  - ability to give single value lists as a string
#  - case insensitivity of env and location
#
# The fifth checks the case of unintentionally providing conflicting values
#  - in which case, the latest / lowest definition wins
#
# The sixth checks default comments
####################################################################################

variables {
  config = "config1.yaml"
  repo   = "olympus-infr-adm-snowflake" # needed to check default comment in test 6
}

### 1 of 6: DEV IRELAND ############################################################

run "t1_dev-ireland" {
  command = plan

  variables {
    env      = "dev"
    location = "ba_ireland"
    expected = {
      "WH_TEST1_BA_IRELAND" = {
        "name"              = "WH_TEST1"
        "location"          = "BA_IRELAND"
        "size"              = "XSMALL"
        "comment"           = "dev and uat only"
        "max_cluster_count" = 1
      }
    }
  }

  assert {
    condition     = length(local.warehouses) == 1
    error_message = "Expected a single warehouse but found ${length(local.warehouses)}"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST1_BA_IRELAND"])
    error_message = "Expected to find key WH_TEST1_BA_IRELAND"
  }
  assert {
    condition     = local.warehouses == var.expected
    error_message = "Expected warehouse to be:\n${jsonencode(var.expected)}\nfound:\n${jsonencode(local.warehouses)}"
  }

}

### 2 of 6: PRD IRELAND ############################################################

run "t2_prd-ireland" {
  command = plan

  variables {
    env      = "prd"
    location = "ba_ireland"
    expected = {}
  }

  assert {
    condition     = length(local.warehouses) == 0
    error_message = "Expected no warehouses but found ${length(local.warehouses)}"
  }
  assert {
    condition     = local.warehouses == var.expected
    error_message = "Expected no warehouses but found:\n${jsonencode(local.warehouses)}"
  }

}

### 3 of 6: DEV LONDON #############################################################

run "t3_dev-london" {
  command = plan

  variables {
    env      = "dev"
    location = "ba_london"
    expected = {}
  }

  assert {
    condition     = length(local.warehouses) == 0
    error_message = "Expected no warehouses but found ${length(local.warehouses)}"
  }
  assert {
    condition     = local.warehouses == var.expected
    error_message = "Expected warehouse to be:\n${jsonencode(var.expected)}\nfound:\n${jsonencode(local.warehouses)}"
  }

}

### 4 of 6: PRD LONDON #############################################################

run "t4_prd-london" {
  command = plan

  variables {
    env      = "prd"
    location = "ba_london"
    expected = {
      "WH_TEST1_BA_LONDON" = {
        "name"              = "WH_TEST1"
        "location"          = "BA_LONDON"
        "size"              = "LARGE"
        "comment"           = "PRD London"
        "max_cluster_count" = 2
      }
    }
  }

  assert {
    condition     = length(local.warehouses) == 1
    error_message = "Expected a single warehouse but found ${length(local.warehouses)}"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST1_BA_LONDON"])
    error_message = "Expected to find key WH_TEST1_BA_LONDON"
  }
  assert {
    condition     = local.warehouses == var.expected
    error_message = "Expected warehouse to be:\n${jsonencode(var.expected)}\nfound:\n${jsonencode(local.warehouses)}"
  }

}

### 5 of 6: UAT IRELAND - multiple definitions #####################################

run "t5_uat-ireland" {
  command = plan

  variables {
    env      = "uat"
    location = "ba_ireland"
    expected = {
      "WH_TEST1_BA_IRELAND" = {
        "name"              = "WH_TEST1"
        "location"          = "BA_IRELAND"
        "size"              = "MEDIUM"
        "comment"           = "takes precedence"
        "max_cluster_count" = 1
      }
    }
  }

  assert {
    condition     = length(local.warehouses) == 1
    error_message = "Expected a single warehouse but found ${length(local.warehouses)}"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST1_BA_IRELAND"])
    error_message = "Expected to find key WH_TEST1_BA_IRELAND"
  }
  assert {
    condition     = local.warehouses == var.expected
    error_message = "Expected warehouse to be:\n${jsonencode(var.expected)}\nfound:\n${jsonencode(local.warehouses)}"
  }

}

### 6 of 6: UAT LONDON - check default comment #####################################

run "t6_uat-london" {
  command = plan

  variables {
    env      = "uat"
    location = "ba_london"
    expected = {
      "WH_TEST2_BA_LONDON" = {
        "name"              = "WH_TEST2"
        "location"          = "BA_LONDON"
        "size"              = "XSMALL"
        "comment"           = "Created by ${var.repo}"
        "max_cluster_count" = 1
      }
    }
  }

  assert {
    condition     = length(local.warehouses) == 1
    error_message = "Expected a single warehouse but found ${length(local.warehouses)}"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST2_BA_LONDON"])
    error_message = "Expected to find key WH_TEST2_BA_LONDON"
  }
  assert {
    condition     = local.warehouses == var.expected
    error_message = "Expected warehouse to be:\n${jsonencode(var.expected)}\nfound:\n${jsonencode(local.warehouses)}"
  }

}
