# "Terraform's test framework is designed for verifying conditions rather than displaying data"
#  - nleh! ... so these tests intentionally fail just to show us the values
#
# terraform test                             # runs the main one(s)
# terraform test -test-directory=debug       # runs thesee debug one(s)

run "debug_values" {
  command = plan

  variables {
    env      = "dev"
    location = "BA_IRELAND"
  }

  assert {
    condition     = local.env == "force failure"
    error_message = "Debug output:\n${replace(yamlencode(local.warehouses), ", ", ",\n  ")}"
  }
}
