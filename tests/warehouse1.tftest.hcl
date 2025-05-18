####################################################################################
# warehouse1.tftest.hcl 
#
# Check basic functionality:
#  - filtering by location
#  - expansion of ${env} - here only visible in the comments
#  - default location, size, clusters and comment
#  - ability to give single value lists as a string
#  - case insensitivity of location
#  - unintentionally providing conflicting values
#    (in which case, the latest definition wins)
#
####################################################################################

variables {
  config = "config1.yaml"
  repo   = "olympus-infr-adm-snowflake" # needed to check default comment in test 6
}

### 1 of 4: DEV IRELAND ############################################################

run "t1_dev-ireland" {
  command = plan

  variables {
    env      = "dev"
    location = "ba_ireland"
    expected = {
      "WH_TEST1_BA_IRELAND" = {
        "name"              = "WH_TEST1"
        "location"          = "BA_IRELAND"
        "size"              = "MEDIUM"
        "comment"           = "latest wins"
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

### 2 of 4: PRD IRELAND  (same as dev ireland but for comment) #####################

run "t2_prd-ireland" {
  command = plan

  variables {
    env      = "prd"
    location = "ba_ireland"
    expected = {
      "WH_TEST1_BA_IRELAND" = {
        "name"              = "WH_TEST1"
        "location"          = "BA_IRELAND"
        "size"              = "MEDIUM"
        "comment"           = "latest wins"
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

### 3 of 4: DEV LONDON #############################################################

run "t3_dev-london" {
  command = plan

  variables {
    env      = "dev"
    location = "ba_london"
    expected = {
      "WH_TEST1_BA_LONDON" = {
        "name"              = "WH_TEST1"
        "location"          = "BA_LONDON"
        "size"              = "LARGE"
        "comment"           = "DEV London"
        "max_cluster_count" = 2
      },
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
    condition     = length(local.warehouses) == 2
    error_message = "Expected no warehouses but found ${length(local.warehouses)}"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST1_BA_LONDON"]) # sometimes CRASHES terraform :-)
    error_message = "Expected to find key WH_TEST1_BA_LONDON"
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

### 4 of 4: PRD LONDON  (same as dev london but for comment) ######################

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
      },
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
    condition     = length(local.warehouses) == 2
    error_message = "Expected no warehouses but found ${length(local.warehouses)}"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST1_BA_LONDON"]) # CRASHES terraform if you give a non existent key)
    error_message = "Expected to find key WH_TEST1_BA_LONDON"
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


