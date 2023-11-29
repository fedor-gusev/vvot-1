terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

// Configure the Yandex.Cloud provider
provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone_region
}

 
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = var.admin_id
  description        = "Ключ для бакетов"
}

resource "yandex_iam_service_account_api_key" "sa-api-key" {
  service_account_id =  var.admin_id
  description        = "Ключ для Яндекс.Vision"
}
 
resource "yandex_storage_bucket" "vvot13-photo" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "vvot13-photo"
}

resource "yandex_storage_bucket" "vvot13-faces" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "vvot13-faces"
}

resource "yandex_message_queue" "vvot13-task" {
  name                        = "vvot13-task"
  visibility_timeout_seconds  = 30
  receive_wait_time_seconds   = 20
  message_retention_seconds   = 345600
  access_key                  = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key                  = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
}

resource "yandex_ydb_database_serverless" "vvot13-db-photo-face" {
  name                = "vvot13-db-photo-face"
  deletion_protection = false

  serverless_database {
    enable_throttling_rcu_limit = false
    storage_size_limit          = 5
  }
}

 resource "yandex_ydb_table" "vvot13-db-photo-face" {
  path = "vvot13-db-photo-face"
  connection_string = yandex_ydb_database_serverless.vvot13-db-photo-face.ydb_full_endpoint 
  
column {
      name = "storage_id"
      type = "String"
      not_null = true
    }
    column {
      name = "chat_id"
      type = "String"
      not_null = false
    }
    column {
      name = "name"
      type = "String"
      not_null = false
    }

  primary_key = ["storage_id"]
  
}

resource "yandex_function" "vvot13-face-detection" {
  name               = "vvot13-face-detection"
  description        = "Обработчик лиц фото"
  user_hash          = "e701a80e-158a-4fde-b991-518abffa05b7"
  runtime            = "python311"
  entrypoint         = "vvot13-face-detection.handler"
  memory             = "128"
  execution_timeout  = "60"
  service_account_id = var.admin_id
  tags               = ["my_tag"]
  content {
    zip_filename = "vvot13-face-detection.zip"
  }
  environment = {
    QUEUE_NAME = yandex_message_queue.vvot13-task.name
    AWS_ACCESS_KEY_ID = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
    AWS_DEFAULT_REGION = var.aws_region
    API_KEY = yandex_iam_service_account_api_key.sa-api-key.secret_key
  }

}

resource "archive_file" "zip" {
  output_path = "vvot13-face-detection.zip"
  type        = "zip"
  source_dir = "./face-detection"
}


resource "yandex_function_trigger" "vvot13-photo" {
  name        = "vvot13-photo"
  description = "Срабатывает при сохранении объекта в бакет"
  object_storage {
     bucket_id = yandex_storage_bucket.vvot13-photo.id
     create    = true
     update    = false
     batch_cutoff = false
  }
  function {
    id                 = yandex_function.vvot13-face-detection.id
    service_account_id = var.admin_id
  }
}


resource "yandex_function" "vvot13-face-cut" {
  name               = "vvot13-face-cut"
  description        = "Обрезка лиц на фото"
  user_hash          = "49409590-8455-4d73-aa44-4f5d2fc9ed97"
  runtime            = "python311"
  entrypoint         = "vvot13-face-cut.handler"
  memory             = "128"
  execution_timeout  = "60"
  service_account_id = var.admin_id
  tags               = ["my_tag"]
  content {
    zip_filename = "vvot13-face-cut.zip"
  }
  environment = {
    PHOTO_BUCKET_NAME = yandex_storage_bucket.vvot13-photo.bucket
    FACES_BUCKET_NAME = yandex_storage_bucket.vvot13-faces.bucket
    TABLE_NAME = yandex_ydb_database_serverless.vvot13-db-photo-face.name
    AWS_ACCESS_KEY_ID = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
    AWS_DEFAULT_REGION = var.aws_region
    YDB_ACCESS_TOKEN_CREDENTIALS = var.iam_token
    YDB_ENDPOINT = yandex_ydb_database_serverless.vvot13-db-photo-face.ydb_full_endpoint 
    YDB_DATABASE = yandex_ydb_database_serverless.vvot13-db-photo-face.database_path
  }

}

resource "archive_file" "zip2" {
  output_path = "vvot13-face-cut.zip"
  type        = "zip"
  source_dir = "./face-cut"
}

resource "yandex_function_trigger" "vvot13-task" {
  name        = "vvot13-task"
  description = "Срабатывает при получнии сообщения из MQ"
  message_queue {
    queue_id           =  yandex_message_queue.vvot13-task.arn
    service_account_id = var.admin_id
    batch_size         = "1"
    batch_cutoff       = "10"
  }
  function {
    id                 = yandex_function.vvot13-face-cut.id
    service_account_id = var.admin_id
  }
}


resource "yandex_api_gateway" "vvot13-apigw" {
  name        = "vvot13-apigw"
  description = "api gateway tg"
  spec = <<-EOT
    openapi: "3.0.0"
    info:
      version: 1.0.0
      title: Test API
    servers:
      - url: https://{yandex_api_gateway.vvot13-apigw.id}.apigw.yandexcloud.net
    paths:
      /:
        get:
          summary: Serve static file from Yandex Cloud Object Storage
          parameters:
            - name: face
              in: query
              required: true
              schema:
                type: string
              style: simple
              explode: false
          x-yc-apigateway-integration:
            type: object_storage
            bucket: vvot13-faces
            object: '{face}.jpg'
            error_object: error.html
            service_account_id: ${var.admin_id}
  EOT
}

resource "archive_file" "zip3" {
  output_path = "vvot13-2023-boot.zip"
  type        = "zip"
  source_dir = "./bot"
}

resource "yandex_function" "vvot13-2023-boot" {
  name               = "vvot13-2023-boot"
  description        = "Обработчик сообщений для телеграм бота"
  user_hash          = "4934cfc4-636d-470f-a649-1ddfc6b494ae"
  runtime            = "python311"
  entrypoint         = "bot.handler"
  memory             = "128"
  execution_timeout  = "60"
  service_account_id = var.admin_id
  tags               = ["my_tag"]
  content {
    zip_filename = "vvot13-2023-boot.zip"
  }
  environment = {
    API_GATEWAY_ID = yandex_api_gateway.vvot13-apigw.id 
    FACES_BUCKET_NAME = yandex_storage_bucket.vvot13-faces.bucket
    AWS_ACCESS_KEY_ID = yandex_iam_service_account_static_access_key.sa-static-key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
    AWS_DEFAULT_REGION = var.aws_region
    YDB_ACCESS_TOKEN_CREDENTIALS = var.iam_token
    YDB_ENDPOINT = yandex_ydb_database_serverless.vvot13-db-photo-face.ydb_full_endpoint 
    YDB_DATABASE = yandex_ydb_database_serverless.vvot13-db-photo-face.database_path
    TGKEY = var.tgkey
    TABLE_NAME = yandex_ydb_database_serverless.vvot13-db-photo-face.name
  }

}

resource "yandex_function_iam_binding" "function-boot" {
  function_id = yandex_function.vvot13-2023-boot.id
  role        = "functions.functionInvoker"
  members = [
    "system:allUsers",
  ]
}

data "http" "webhook" {
  url = "https://api.telegram.org/bot${var.tgkey}/setWebhook?url=https://functions.yandexcloud.net/${yandex_function.vvot13-2023-boot.id}"
}