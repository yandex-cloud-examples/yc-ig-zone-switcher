resource "yandex_iam_service_account" "sa" {
  folder_id = var.yc_folder_id
  name      = "ig-switch-demo-sa"
}

// Grant permissions
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = var.yc_folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "sa-ipluller" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "sa-vpc-admin" {
  folder_id = var.yc_folder_id
  role      = "vpc.admin"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "sa-mdb-viewer" {
  folder_id = var.yc_folder_id
  role      = "mdb.viewer"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "sa-log-writer" {
  folder_id = var.yc_folder_id
  role      = "logging.writer"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "alb-editor" {
  folder_id = var.yc_folder_id
  role      = "alb.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "sa-user" {
  folder_id = var.yc_folder_id
  role      = "iam.serviceAccounts.user"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "sa-ceditor" {
  folder_id = var.yc_folder_id
  role      = "compute.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "sa-finvoker" {
  folder_id = var.yc_folder_id
  role      = "functions.functionInvoker"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

// Create Static Access Keys
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}



// Use keys to create bucket
resource "yandex_storage_bucket" "dev_bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = "ig-switch-demo-bucket"
  depends_on = [
    yandex_resourcemanager_folder_iam_member.sa-editor
  ]
}

resource "yandex_vpc_network" "demo_network" {
  name = "ig_zone_switch_demo_network"
}


resource "yandex_vpc_subnet" "demo-subnet" {
  for_each       = { for v in var.subnet_zones : v.zone => v }
  zone           = each.value.zone
  network_id     = yandex_vpc_network.demo_network.id
  v4_cidr_blocks = [each.value.cidr]
}
