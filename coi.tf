data "yandex_compute_image" "container-optimized-image" {
    family = "container-optimized-image" 
}
resource "yandex_compute_instance_group" "coi-ig" {
  name                = "demo-ig"
  
  depends_on = [
    #to races on destroy prevent
    yandex_resourcemanager_folder_iam_member.alb-editor,
    yandex_resourcemanager_folder_iam_member.sa-ceditor,
    yandex_resourcemanager_folder_iam_member.sa-vpc-admin,
    yandex_iam_service_account.sa, 
    yandex_mdb_postgresql_database.pg_db
  ]

  service_account_id  = yandex_iam_service_account.sa.id
  instance_template {
    service_account_id = yandex_iam_service_account.sa.id
    platform_id = "standard-v3"
    boot_disk {
        initialize_params {
        image_id = data.yandex_compute_image.container-optimized-image.id
        size     = 15
        }
    }
    network_interface {
        subnet_ids = [for d in yandex_vpc_subnet.demo-subnet: d.id ]
        security_group_ids = [yandex_vpc_security_group.security-group-alb.id]
        nat = true
    }
    resources {
        cores = 2
        memory = 1
        core_fraction = 50
    }
    metadata = {
        docker-compose = templatefile("templates/docker-compose.yaml.template", {
            image = "${var.image}"
            jdbc_url = "jdbc:postgresql://c-${yandex_mdb_postgresql_cluster.pg_cluster.id}.rw.mdb.yandexcloud.net:6432/${var.pg_cluster.db_user}?targetServerType=master",
            jdbc_user = var.pg_cluster.db_user
            jdbc_password = var.pg_cluster.db_pass
        })
        user-data = templatefile("templates/user-data.yaml.template", {
            ssh_key  = file(var.ssh_key_path)
        })
    }
  }
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
  allocation_policy {
    zones = [yandex_vpc_subnet.demo-subnet[keys(yandex_vpc_subnet.demo-subnet)[0]].zone]
  }
  deploy_policy {
    max_unavailable = 1
    max_creating    = 1
    max_expansion   = 2
    max_deleting    = 1
  }
  application_load_balancer {
    target_group_name        = "demo-target-group"
    target_group_description = "load balancer demo target group"
  }
}  

locals {
  subnets = jsonencode(yandex_compute_instance_group.coi-ig.instance_template[0].network_interface[0].subnet_ids)
}

resource "local_file" "ig_config" {
  filename = "instance_group.yaml"
  content  = templatefile("templates/instance_group.yaml.template", {
            group_name = yandex_compute_instance_group.coi-ig.name,
            service_account_id = yandex_iam_service_account.sa.id
            itemp_platform_id = yandex_compute_instance_group.coi-ig.instance_template[0].platform_id
            itemp_mem_size = yandex_compute_instance_group.coi-ig.instance_template[0].resources[0].memory
            itemp_cores = yandex_compute_instance_group.coi-ig.instance_template[0].resources[0].cores
            itemp_core_fraction = yandex_compute_instance_group.coi-ig.instance_template[0].resources[0].core_fraction
            item_disk_image_id = yandex_compute_instance_group.coi-ig.instance_template[0].boot_disk[0].initialize_params[0].image_id
            itemp_disk_type = yandex_compute_instance_group.coi-ig.instance_template[0].boot_disk[0].initialize_params[0].type
            itemp_disk_size = yandex_compute_instance_group.coi-ig.instance_template[0].boot_disk[0].initialize_params[0].size
            itemp_network_id = yandex_vpc_network.demo_network.id
            itemp_subnet_ids = local.subnets
            itemp_user_data = jsonencode(yandex_compute_instance_group.coi-ig.instance_template[0].metadata.user-data)
            itemp_docker_compose = jsonencode(yandex_compute_instance_group.coi-ig.instance_template[0].metadata.docker-compose)
            fixed_scale_size = yandex_compute_instance_group.coi-ig.scale_policy[0].fixed_scale[0].size
            target_group_name = yandex_compute_instance_group.coi-ig.application_load_balancer[0].target_group_name
            max_unavailable = yandex_compute_instance_group.coi-ig.deploy_policy[0].max_unavailable
            max_expansion = yandex_compute_instance_group.coi-ig.deploy_policy[0].max_expansion
            max_creating = yandex_compute_instance_group.coi-ig.deploy_policy[0].max_creating
            max_deleting = yandex_compute_instance_group.coi-ig.deploy_policy[0].max_deleting
            security_group = yandex_vpc_security_group.security-group-alb.id
        })
}
