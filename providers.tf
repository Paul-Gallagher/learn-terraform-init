terraform {
  required_providers {
    tfcoremock = {
      source  = "hashicorp/tfcoremock"
      version = "0.1.2"

      # without this list we'd have tp add a providers.tf to each module sub-directory
      configuration_aliases = [
        tfcoremock,
        tfcoremock.BANGKOK,
        tfcoremock.IRELAND,
        tfcoremock.LONDON,
      ]
    }
  }
}

# baseline provider configuration
provider "tfcoremock" {
  # Default provider configuration
}

# define separate provider aliases for each Snowflake account - these inherit from the bseline configuration
provider "tfcoremock" {
  alias = "LONDON" # London-specific connection parameters - from environment variables
}
provider "tfcoremock" {
  alias = "IRELAND" # Ireland-specific connection parameters
}
provider "tfcoremock" {
  alias = "BANGKOK" # Bangkok-specific connection parameters
}


