output "ip_adress_vm1" {
  value = digitalocean_droplet.vm1.ipv4_address
}



output "ip_adress_vm1_private" {
  value = digitalocean_droplet.vm1.ipv4_address_private
}
