terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.75.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

resource "azurerm_resource_group" "task4_rg" {
  name     = "task4-rg"
  location = var.location
}

resource "azurerm_virtual_network" "task4_vnet" {
  name                = "task4-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.task4_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "task4_bastion_subnet" {
  name                 = "task4-bastion-subnet"
  resource_group_name  = azurerm_resource_group.task4_rg.name
  virtual_network_name = azurerm_virtual_network.task4_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "task4_web_subnet" {
  name                 = "task4-web-subnet"
  resource_group_name  = azurerm_resource_group.task4_rg.name
  virtual_network_name = azurerm_virtual_network.task4_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "task4_app_subnet" {
  name                 = "task4-app-subnet"
  resource_group_name  = azurerm_resource_group.task4_rg.name
  virtual_network_name = azurerm_virtual_network.task4_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "task4_db_subnet" {
  name                 = "task4-db-subnet"
  resource_group_name  = azurerm_resource_group.task4_rg.name
  virtual_network_name = azurerm_virtual_network.task4_vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

resource "azurerm_public_ip" "task4_bastion_public_ip" {
  name                = "task4-bastion-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.task4_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "task4_bastion_nsg" {
  name                = "task4-bastion-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.task4_rg.name

  security_rule {
    name                       = "task4-allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "task4_bastion_nic" {
  name                = "task4-bastion-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.task4_rg.name

  ip_configuration {
    name                          = "task4-bastion-ipconfig"
    subnet_id                     = azurerm_subnet.task4_bastion_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.task4_bastion_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "task4_bastion_nic_nsg" {
  network_interface_id      = azurerm_network_interface.task4_bastion_nic.id
  network_security_group_id = azurerm_network_security_group.task4_bastion_nsg.id
}

resource "azurerm_linux_virtual_machine" "task4_bastion_vm" {
  name                = "task4-bastion-vm"
  resource_group_name = azurerm_resource_group.task4_rg.name
  location            = var.location
  size                = "Standard_B2ats_v2"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.task4_bastion_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_network_security_group" "task4_web_nsg" {
  name                = "task4-web-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.task4_rg.name

  security_rule {
    name                       = "task4-allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "task4-allow-ssh-from-bastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "task4_web_nsg_association" {
  subnet_id                 = azurerm_subnet.task4_web_subnet.id
  network_security_group_id = azurerm_network_security_group.task4_web_nsg.id
}

resource "azurerm_public_ip" "task4_lb_public_ip" {
  name                = "task4-lb-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.task4_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "task4_load_balancer" {
  name                = "task4-load-balancer"
  location            = var.location
  resource_group_name = azurerm_resource_group.task4_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "task4-public-frontend"
    public_ip_address_id = azurerm_public_ip.task4_lb_public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "task4_backend_pool" {
  loadbalancer_id = azurerm_lb.task4_load_balancer.id
  name            = "task4-web-backend-pool"
}

resource "azurerm_lb_probe" "task4_http_probe" {
  loadbalancer_id = azurerm_lb.task4_load_balancer.id
  name            = "task4-http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

resource "azurerm_lb_rule" "task4_http_rule" {
  loadbalancer_id                = azurerm_lb.task4_load_balancer.id
  name                           = "task4-http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "task4-public-frontend"

  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.task4_backend_pool.id
  ]

  probe_id = azurerm_lb_probe.task4_http_probe.id
}

resource "azurerm_linux_virtual_machine_scale_set" "task4_web_vmss" {
  name                = "task4-web-vmss"
  resource_group_name = azurerm_resource_group.task4_rg.name
  location            = var.location

  sku            = "Standard_B2ats_v2"
  instances      = 1
  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  network_interface {
    name    = "task4-web-vmss-nic"
    primary = true

    ip_configuration {
      name      = "task4-web-ipconfig"
      primary   = true
      subnet_id = azurerm_subnet.task4_web_subnet.id

      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.task4_backend_pool.id
      ]
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
echo "<h1>Task 4 - Azure VMSS Web Server</h1>" > /var/www/html/index.html
EOF
  )

  upgrade_mode = "Manual"

  depends_on = [
    azurerm_lb_rule.task4_http_rule
  ]
}

resource "azurerm_network_security_group" "task4_app_nsg" {
  name                = "task4-app-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.task4_rg.name

  security_rule {
    name                       = "task4-allow-app-from-web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "task4_app_nsg_association" {
  subnet_id                 = azurerm_subnet.task4_app_subnet.id
  network_security_group_id = azurerm_network_security_group.task4_app_nsg.id
}

resource "azurerm_network_security_group" "task4_db_nsg" {
  name                = "task4-db-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.task4_rg.name

  security_rule {
    name                       = "task4-allow-mysql-from-app"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "10.0.3.0/24"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "task4_db_nsg_association" {
  subnet_id                 = azurerm_subnet.task4_db_subnet.id
  network_security_group_id = azurerm_network_security_group.task4_db_nsg.id
}

resource "azurerm_monitor_autoscale_setting" "task4_web_autoscale" {
  name                = "task4-web-autoscale"
  resource_group_name = azurerm_resource_group.task4_rg.name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.task4_web_vmss.id

  profile {
    name = "task4-default-profile"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.task4_web_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.task4_web_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
