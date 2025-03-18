
resource "yandex_alb_backend_group" "demo-backend-group" {
  name      = "demo-backend-group"

  http_backend {
    name = "demo-http-backend"
    weight = 1
    port = 8080
    target_group_ids = [ yandex_compute_instance_group.coi-ig.application_load_balancer[0].target_group_id]

    load_balancing_config {
      panic_threshold = 50
    }    
    healthcheck {
      timeout = "15s"
      interval = "15s"
      http_healthcheck {
        path  = "/api/status"
      }
    }
  }
}

resource "yandex_vpc_security_group" "security-group-alb" {
  description = "Security group for VM"
  network_id  = yandex_vpc_network.demo_network.id

  ingress {
    protocol          = "TCP"
    port              = 30080
    predefined_target = "loadbalancer_healthchecks"
  }
  ingress {
    protocol          = "TCP"
    port              = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol          = "TCP"
    port              = 8080
    predefined_target = "self_security_group"
  }


  ingress {
    description    = "Allow SSH connections for VM from the Internet"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing connections to any required resource"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "yandex_alb_http_router" "demo-router" {
  name          = "demo-router"
}

resource "yandex_alb_virtual_host" "demo-virtual-host" {
  name                    = "demo-virtual-host"
  http_router_id          = "${yandex_alb_http_router.demo-router.id}"
  route {
    name                  = "demo-router"
    http_route {
      http_match {
  path {  
    prefix  = "/" 
        } 
      }
      http_route_action {
        backend_group_id  = "${yandex_alb_backend_group.demo-backend-group.id}"
        timeout           = "60s"
      }
    }
  }
}  

resource "yandex_alb_load_balancer" "demo-balancer" {
  name        = "demo-balancer"
  network_id  = yandex_vpc_network.demo_network.id
  security_group_ids = [yandex_vpc_security_group.security-group-alb.id]
  allocation_policy {
    dynamic "location" {
        for_each = yandex_vpc_subnet.demo-subnet
        content {
            zone_id   = location.value.zone
            subnet_id = location.value.id
        }
      }
  }

  listener {
    name = "demo-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 80 ]
    }
    http {
      handler {
        http_router_id = "${yandex_alb_http_router.demo-router.id}"
      }
    }
  }
}

