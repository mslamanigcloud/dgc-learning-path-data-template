locals {
  cloud_functions_bucket = "${var.project_id}_cloud-function-sources"
}

# ZIP
data "archive_file" "check_file_format_source" {
  type        = "zip"
  source_dir  = "../cloud_functions/cf_trigger_on_file/src"
  output_path = "/tmp/check_file_format.zip"
}

# ZIP >> cloud_functions_sources
resource "google_storage_bucket_object" "check_file_format_zip" {
  source       = data.archive_file.check_file_format_source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.check_file_format_source.output_md5}.zip"
  bucket = local.cloud_functions_bucket
}

# DEPLOY
resource "google_cloudfunctions_function" "check_file_format" {
  name    = "check_file_format"
  runtime = "python37"

  # Get the source code of the cloud function as a Zip compression
  source_archive_bucket = local.cloud_functions_bucket
  source_archive_object = google_storage_bucket_object.check_file_format_zip.name

  # Must match the function name in the cloud function `main.py` source code
  entry_point = "check_file_format"

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = "projects/${var.project_id}/buckets/${var.project_id}_magasin-cie-landing"
  }

  environment_variables = yamldecode(file("../cloud_functions/cf_trigger_on_file/env.yaml"))
}

# ZIP
data "archive_file" "receive_messages_source" {
  type        = "zip"
  source_dir  = "../cloud_functions/cf_dispatch_workflow/src"
  output_path = "/tmp/receive_messages.zip"
}

# ZIP >> cloud_functions_sources
resource "google_storage_bucket_object" "receive_messages_zip" {
  source       = data.archive_file.receive_messages_source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.receive_messages_source.output_md5}.zip"
  bucket = local.cloud_functions_bucket
}

# DEPLOY
resource "google_cloudfunctions_function" "receive_messages" {
  name    = "receive_messages"
  runtime = "python37"

  # Get the source code of the cloud function as a Zip compression
  source_archive_bucket = local.cloud_functions_bucket
  source_archive_object = google_storage_bucket_object.receive_messages_zip.name

  # Must match the function name in the cloud function `main.py` source code
  entry_point = "receive_messages"

  event_trigger {
    event_type = "providers/cloud.pubsub/eventTypes/topic.publish"
    resource   = "projects/sandbox-vvaneecloo/topics/valid_file"
  }

  environment_variables = yamldecode(file("../cloud_functions/cf_trigger_on_file/env.yaml"))
}