terraform {
  required_version = ">= 1.6.2"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.33"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

provider "local" {}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
