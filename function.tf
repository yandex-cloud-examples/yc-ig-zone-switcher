resource "yandex_storage_object" "ig-template" {
  bucket = yandex_storage_bucket.dev_bucket.bucket
  key    = local_file.ig_config.filename
  source = local_file.ig_config.filename
  depends_on = [
    yandex_resourcemanager_folder_iam_member.sa-editor
  ]
}

data "archive_file" "follow-the-leader-function" {
  type        = "zip"
  source_dir  = "scripts/"
  output_path = "follow-the-leader-function.zip"
}

resource "yandex_function" "follow-the-leader-trigger" {
  folder_id          = var.yc_folder_id
  name               = "follow-the-leader-example"
  runtime            = "bash-2204"
  entrypoint         = "yc_function.sh"
  memory             = 128
  execution_timeout  = 10
  service_account_id = yandex_iam_service_account.sa.id
  environment = {
    FOLDER_ID       = var.yc_folder_id
    IG_ID           = yandex_compute_instance_group.coi-ig.id
    CLUSTER_ID      = yandex_mdb_postgresql_cluster.pg_cluster.id
    LOG_GROUP_ID    = var.log_group_id
    YC_BUCKET       = yandex_storage_bucket.dev_bucket.bucket
    IG_TEMPLATE     = local_file.ig_config.filename
    MDB_STYPE       = var.mdb_service_type
  }
  user_hash = data.archive_file.follow-the-leader-function.output_base64sha256
  content {
    zip_filename = data.archive_file.follow-the-leader-function.output_path
  }
  mounts {
    
        name = var.function_mount_name
        mode = "rw"
        object_storage {
            bucket = yandex_storage_bucket.dev_bucket.bucket
        }
  } 
}

resource "yandex_function_trigger" "route_switcher_trigger" {
  depends_on = [yandex_storage_object.ig-template]
  folder_id = var.yc_folder_id
  name = "follow-the-leader-example"

  function {
    id                 = yandex_function.follow-the-leader-trigger.id
    service_account_id = yandex_iam_service_account.sa.id
  }

  timer {
    cron_expression = "*/5 * ? * * *"
  }
}
