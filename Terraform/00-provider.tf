# для чего конфиг digital ocean если локальные vm использовались для конфигов ансибла?

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}
