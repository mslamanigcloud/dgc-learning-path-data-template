resource "google_storage_bucket" "magasin_cie_landing" {
  project  = var.project_id
  name     = "${var.project_id}_magasin_cie_landing"
  location = var.location
  lifecycle_rule {
    condition {
      age            = 30
      matches_prefix = ["archive/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
  lifecycle_rule {
    condition {
      age            = 90
      matches_prefix = ["archive/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
  lifecycle_rule {
    condition {
      age            = 365
      matches_prefix = ["archive/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }
  lifecycle_rule {
    condition {
      age            = 1000
      matches_prefix = ["archive/"]
    }
    action {
      type = "Delete"
    }
  }
}

# create the input, archive, reject, invalid empty folders in the landing bucket
resource "google_storage_bucket_object" "landing_folders" {
  for_each = {
    "input/"   = "",
    "archive/" = "",
    "reject/"  = "",
    "invalid/" = "",
  }
  name    = each.key
  content = each.value
  bucket  = google_storage_bucket.storage_bucket.name
}

resource "google_storage_bucket" "magasin_cie_utils" {
  project  = var.project_id
  name     = "${var.project_id}_magasin_cie_utils"
  location = var.location
}

resource "google_storage_bucket" "cloud_functions_sources" {
  project                     = var.project_id
  name                        = "${var.project_id}_cloud_functions_sources"
  location                    = var.location
  force_destroy               = true
  uniform_bucket_level_access = true
}

# populate the utils bucket with all the folders contained in the queries folder
resource "google_storage_bucket_object" "queries" {
  for_each   = fileset("../queries", "**/*")
  name       = "queries/${each.value}"
  source     = "../queries/${each.value}"
  bucket     = google_storage_bucket.magasin_cie_utils.name
  depends_on = [google_storage_bucket.magasin_cie_utils]
}

# populate the utils bucket with all the folders contained in the schemas folder
resource "google_storage_bucket_object" "schema" {
  for_each   = fileset("../schemas", "**/*")
  name       = "schemas/${each.value}"
  source     = "../schemas/${each.value}"
  bucket     = google_storage_bucket.magasin_cie_utils.name
  depends_on = [google_storage_bucket.magasin_cie_utils]
}