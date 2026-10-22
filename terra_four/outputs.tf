output "task4_bastion_public_ip" {
  value = azurerm_public_ip.task4_bastion_public_ip.ip_address
}

output "task4_load_balancer_public_ip" {
  value = azurerm_public_ip.task4_lb_public_ip.ip_address
}

output "task4_load_balancer_url" {
  value = "http://${azurerm_public_ip.task4_lb_public_ip.ip_address}"
}

output "task4_vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.task4_web_vmss.name
}
