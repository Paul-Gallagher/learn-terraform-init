# we want to exclude any debug.tftest.hcl files but -filter "!debug.tftest.hcl" doesn't bloody work
#  - so move them to a separate sub-directory
#
# terraform test                             # runs the main one(s)
# terraform test -test-directory=debug       # runs thesee debug one(s)

run "test1" {
  command = plan

  variables {
    # these are the default values
    env      = "dev"
    location = "BA_IRELAND"
  }

  assert {
    condition     = can(local.warehouses["WH_TEST1_BA_IRELAND"])
    error_message = "Expected to find WH_TEST1_BA_IRELAND warehouse in dev environment"
  }

  assert {
    condition     = can(local.warehouses)
    error_message = "This is a test ${jsonencode(local.warehouses)}"
  }

}

