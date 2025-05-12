<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| tfcoremock | 0.1.2 |

## Providers

| Name | Version |
|------|---------|
| terraform | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| snowflake\_database\_ireland | ./modules/snowflake-database | n/a |
| snowflake\_database\_london | ./modules/snowflake-database | n/a |
| snowflake\_integration\_ireland | ./modules/snowflake-integration | n/a |
| snowflake\_integration\_london | ./modules/snowflake-integration | n/a |
| snowflake\_stage\_ireland | ./modules/snowflake-stage | n/a |
| snowflake\_stage\_london | ./modules/snowflake-stage | n/a |
| snowflake\_warehouse\_ireland | ./modules/snowflake-warehouse | n/a |
| snowflake\_warehouse\_london | ./modules/snowflake-warehouse | n/a |

## Resources

| Name | Type |
|------|------|
| [terraform_data.validate_sections](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |



## Outputs

| Name | Description |
|------|-------------|
| integrations | --- these are purely for debugging ------------------------------------ output "account" { value = local.account } output "all\_accounts" { value = local.all\_accounts } output "warehouses" { value = local.warehouses } output "databases" { value = local.databases } |
| service\_user | output "stages" { value = local.stages } |
| validation\_inputs | Transformed yaml as passed to the validation checks |
<!-- END_TF_DOCS -->