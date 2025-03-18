output "alb_external_ip" {
  value = yandex_alb_load_balancer.demo-balancer.listener[0].endpoint[0].address[0].external_ipv4_address[0]  
}

output "mdb_cluster_id" {
  value = yandex_mdb_postgresql_cluster.pg_cluster.id
}