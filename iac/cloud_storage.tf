 resource "google_storage_bucket" "magasin_cie_landing_test" {
   #project  = var.project_id
   project = "sandbox-cselmene"
   #name     = "${var.project_id}_magasin_cie_landing2"
   name = "sandbox-cselmene_magasin_cie_landing_test"
   location = var.location
   lifecycle_rule {
     condition {
       age = 30
     }
     action {
       type = "SetStorageClass"
       storage_class = "NEARLINE"
     }
   }
   lifecycle_rule {
     condition {
       age = 90
     }
     action {
       type = "SetStorageClass"
       storage_class = "COLDLINE"
     }
   }
   lifecycle_rule {
     condition {
       age = 365
     }
     action {
       type = "SetStorageClass"
       storage_class = "ARCHIVE"
     }
   }
   lifecycle_rule {
     condition {
       age = 1000
     }
     action {
       type = "Delete"
     }
   }
 }
resource "google_storage_bucket" "function_bucket" {
    name     = "${var.project_id}-function"
    location = var.region
}

resource "google_storage_bucket" "input_bucket" {
    name     = "${var.project_id}-input"
    location = var.region
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

