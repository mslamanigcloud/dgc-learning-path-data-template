/*
variable "project_id" {
    default = "sandbox-lhanot"
}
variable "region" {
    default = "europe-west1"
}
provider "google" {
  project = var.project_id
  region  = var.region
}
resource "google_storage_bucket" "magasin_cie_landing" {
  project  = var.project_id
  name     = "${var.project_id}_magasin_cie_landing"
  location = var.location
}

resource "google_storage_bucket" "magasin_cie_utils" {
  project  = var.project_id
  name     = "${var.project_id}_magasin_cie_utils"
  location = var.location
}*/
data "archive_file" "source" {
    type        = "zip"
    source_dir  = "./cloud_functions/cf_trigger_on_file/src"
    output_path = "/tmp/function.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "zip" {
    source       = data.archive_file.source.output_path
    content_type = "application/zip"

    # Append to the MD5 checksum of the files's content
    # to force the zip to be updated as soon as a change occurs
    name         = "src-${data.archive_file.source.output_md5}.zip"
    bucket       = google_storage_bucket.function_bucket.name

    # Dependencies are automatically inferred so these lines can be deleted
    depends_on   = [
        google_storage_bucket.function_bucket,  # declared in `storage.tf`
        data.archive_file.source
    ]
}

# Create the Cloud function triggered by a `Finalize` event on the bucket
resource "google_cloudfunctions_function" "function" {
    name                  = "function-trigger-on-file"
    runtime               = "python310"  # of course changeable

    # Get the source code of the cloud function as a Zip compression
    source_archive_bucket = google_storage_bucket.function_bucket.name
    source_archive_object = google_storage_bucket_object.zip.name

    # Must match the function name in the cloud function `main.py` source code
    entry_point           = "check_file_format"
    
    # 
    event_trigger {
        event_type = "google.storage.object.finalize"
        resource   = "${var.project_id}-input"
    }

    # Dependencies are automatically inferred so these lines can be deleted
    depends_on            = [
        google_storage_bucket.function_bucket,  # declared in `storage.tf`
        google_storage_bucket_object.zip
    ]
}