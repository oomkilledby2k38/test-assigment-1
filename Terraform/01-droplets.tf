data "digitalocean_ssh_key" "key" {
  name = "Terik"
}


resource "digitalocean_vpc" "main" {
  name     = "my-vpc"
  region   = "ams3"
  ip_range = "10.10.10.0/24"
}


resource "digitalocean_droplet" "vm1" {
  image    = "ubuntu-22-04-x64"
  name     = "virtualmachine1"
  size     = "s-2vcpu-2gb"
  region   = "ams3"
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = [data.digitalocean_ssh_key.key.id]
  backups  = true
  backup_policy {
    plan    = "weekly"
    weekday = "TUE"
    hour    = 12
  }
}
