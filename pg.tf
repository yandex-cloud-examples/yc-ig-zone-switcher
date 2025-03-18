resource "yandex_vpc_security_group" "security-group-pg" {
  description = "Security group for PG"
  network_id  = yandex_vpc_network.demo_network.id

  ingress {
    protocol       = "TCP"
    port           = 6432
    v4_cidr_blocks =  values(yandex_vpc_subnet.demo-subnet)[*].v4_cidr_blocks[0]
  }
}
resource "yandex_mdb_postgresql_cluster" "pg_cluster" {
  folder_id   = var.yc_folder_id
  name        = "ig_zone_switch_pg_cluster"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.demo_network.id
  security_group_ids = [yandex_vpc_security_group.security-group-pg.id]

  config {
    version = "16"
    resources {
      resource_preset_id = "s1.small"
      disk_type_id       = "network-ssd"
      disk_size          = "10"
    }
    postgresql_config = {
      synchronous_commit = 3 # off to that particular test
    }
  }
  dynamic "host" {
    for_each = yandex_vpc_subnet.demo-subnet
    content {
        zone      = host.value.zone
        subnet_id = host.value.id
    }
  }
}

resource "yandex_mdb_postgresql_user" "pg_user" {
  cluster_id = yandex_mdb_postgresql_cluster.pg_cluster.id
  name       = var.pg_cluster.db_user
  password   = var.pg_cluster.db_pass
}

resource "yandex_mdb_postgresql_database" "pg_db" {
  cluster_id = yandex_mdb_postgresql_cluster.pg_cluster.id
  name       = yandex_mdb_postgresql_user.pg_user.name
  owner      = yandex_mdb_postgresql_user.pg_user.name
}
