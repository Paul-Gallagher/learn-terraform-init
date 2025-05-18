####################################################################################
# warehouse2.tftest.hcl 
#
# Test root overrides of env and location 
# Test multiple warehouses  (dev/uat/prd london)
####################################################################################

variables { config = "config2.yaml" }

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
        "comment"           = "forced to Ireland only"
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

### 2 of 6: UAT IRELAND ############################################################

run "t2_uat-ireland" {
  command = plan

  variables {
    env      = "uat"
    location = "ba_ireland"
    expected = {
      "WH_TEST1_BA_IRELAND" = {
        "name"              = "WH_TEST1"
        "location"          = "BA_IRELAND"
        "size"              = "XSMALL"
        "comment"           = "forced to Ireland only"
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

### 3 of 6: PRD IRELAND - same as dev ireland ######################################

run "t3_prd-ireland" {
  command = plan

  variables {
    env      = "prd"
    location = "ba_ireland"
    expected = {
      "WH_TEST1_BA_IRELAND" = {
        "name"              = "WH_TEST1"
        "location"          = "BA_IRELAND"
        "size"              = "XSMALL"
        "comment"           = "forced to Ireland only"
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

### 4 of 6: DEV LONDON #############################################################


run "t4_dev-london" {
  command = plan

  variables {
    env      = "dev"
    location = "ba_london"
    expected = {
      "WH_TEST2_BA_LONDON" = {
        "name"              = "WH_TEST2"
        "location"          = "BA_LONDON"
        "size"              = "XSMALL"
        "comment"           = "London 2"
        "max_cluster_count" = 1
      },
      "WH_TEST3_BA_LONDON" = {
        "name"              = "WH_TEST3"
        "location"          = "BA_LONDON"
        "size"              = "LARGE"
        "comment"           = "London 3"
        "max_cluster_count" = 2
      }
    }
  }

  assert {
    condition     = length(local.warehouses) == 2
    error_message = "Expected no warehouses but found ${length(local.warehouses)}"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST2_BA_LONDON"])
    error_message = "Expected to find key WH_TEST2_BA_LONDON"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST3_BA_LONDON"])
    error_message = "Expected to find key WH_TEST3_BA_LONDON"
  }
  assert {
    condition     = local.warehouses == var.expected
    error_message = "Expected warehouse to be:\n${jsonencode(var.expected)}\nfound:\n${jsonencode(local.warehouses)}"
  }

}

### 5 of 6: UAT LONDON #############################################################


run "t5_uat-london" {
  command = plan

  variables {
    env      = "uat"
    location = "ba_london"
    expected = {
      "WH_TEST2_BA_LONDON" = {
        "name"              = "WH_TEST2"
        "location"          = "BA_LONDON"
        "size"              = "XSMALL"
        "comment"           = "London 2"
        "max_cluster_count" = 1
      },
      "WH_TEST3_BA_LONDON" = {
        "name"              = "WH_TEST3"
        "location"          = "BA_LONDON"
        "size"              = "LARGE"
        "comment"           = "London 3"
        "max_cluster_count" = 2
      }
    }
  }

  assert {
    condition     = length(local.warehouses) == 2
    error_message = "Expected a single warehouse but found ${length(local.warehouses)}"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST2_BA_LONDON"])
    error_message = "Expected to find key WH_TEST2_BA_LONDON"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST3_BA_LONDON"])
    error_message = "Expected to find key WH_TEST3_BA_LONDON"
  }
  assert {
    condition     = local.warehouses == var.expected
    error_message = "Expected warehouse to be:\n${jsonencode(var.expected)}\nfound:\n${jsonencode(local.warehouses)}"
  }
}

### 6 of 6: PRD LONDON #############################################################

run "t6_prd-london" {
  command = plan

  variables {
    env      = "prd"
    location = "ba_london"
    expected = {
      "WH_TEST2_BA_LONDON" = {
        "name"              = "WH_TEST2"
        "location"          = "BA_LONDON"
        "size"              = "XSMALL"
        "comment"           = "London 2"
        "max_cluster_count" = 1
      },
      "WH_TEST3_BA_LONDON" = {
        "name"              = "WH_TEST3"
        "location"          = "BA_LONDON"
        "size"              = "LARGE"
        "comment"           = "London 3"
        "max_cluster_count" = 2
      },
      "WH_TEST4_BA_LONDON" = {
        "name"              = "WH_TEST4"
        "location"          = "BA_LONDON"
        "size"              = "XSMALL"
        "comment"           = "forced to PRD only"
        "max_cluster_count" = 1
      }
    }
  }

  assert {
    condition     = length(local.warehouses) == 3
    error_message = "Expected no warehouses but found ${length(local.warehouses)}"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST2_BA_LONDON"])
    error_message = "Expected to find key WH_TEST2_BA_LONDON"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST3_BA_LONDON"])
    error_message = "Expected to find key WH_TEST3_BA_LONDON"
  }
  assert {
    condition     = can(local.warehouses["WH_TEST4_BA_LONDON"])
    error_message = "Expected to find key WH_TEST4_BA_LONDON"
  }
  assert {
    condition     = local.warehouses == var.expected
    error_message = "Expected warehouse to be:\n${jsonencode(var.expected)}\nfound:\n${jsonencode(local.warehouses)}"
  }

}
