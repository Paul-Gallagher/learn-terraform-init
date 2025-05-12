terraform {
  required_providers {
    tfcoremock = {
      source  = "hashicorp/tfcoremock"
      version = "0.1.2"
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


