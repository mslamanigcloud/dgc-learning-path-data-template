### LOCALS ###
locals {
  ### BUCKETS ###
  ### Bucket names ###
  magasin-cie-landing    = "${var.project_id}_magasin-cie-landing"
  magasin-cie-utils      = "${var.project_id}_magasin-cie-utils"
  cloud-function-sources = "${var.project_id}_cloud-function-sources"

  ### Bucket config ###
  bucket_config = {
    (local.magasin-cie-landing) = {
      name = local.magasin-cie-landing
      project  = var.project_id
      location = var.location
      force_destroy = true
      lifecycle_rules = [
        {
          age                   = 30
          matches_storage_class = ["STANDARD"]
          matches_prefix        = "*/input/"
          action_type           = "SetStorageClass"
          storage_class         = "NEARLINE"
        },
        {
          age                   = 90
          matches_storage_class = ["NEARLINE"]
          matches_prefix        = "*/input/"
          action_type           = "SetStorageClass"
          storage_class         = "COLDLINE"
        },
        {
          age                   = 365
          matches_storage_class = ["COLDLINE"]
          matches_prefix        = "*/input/"
          action_type           = "SetStorageClass"
          storage_class         = "ARCHIVE"
        },
        {
          age                   = 1000
          matches_storage_class = ["ARCHIVE"]
          matches_prefix        = "*/input/"
          action_type           = "Delete"
      }]
    },
    (local.magasin-cie-utils) = {
      name = local.magasin-cie-utils
      project  = var.project_id,
      location = var.location
      force_destroy = true
    },
    (local.cloud-function-sources) ={
      project                     = var.project_id
      name                        = local.cloud-function-sources
      location                    = var.location
      force_destroy               = true
      uniform_bucket_level_access = true
    }
  }

  ### BUCKET OBJECT ###
  ### Files ('/input' and "/invalid") ###
  bucket_object_config = {
    "input" = {
      bucket  = local.magasin-cie-landing
      content = " "
    }
    "invalid" = {
      bucket  = local.magasin-cie-landing
      content = " "
    }
  }
}

### BUCKETS ###
resource "google_storage_bucket" "buckets" {
  for_each = local.bucket_config
  #### Required args ###
  name     = each.value.name
  project  = each.value.project
  location = each.value.location
  ### Optional args ###
  force_destroy               = try(each.value.force_destroy, false)
  uniform_bucket_level_access = try(each.value.uniform_bucket_level_access, false)
  dynamic "lifecycle_rule" {
    for_each = try(each.value.lifecycle_rules, [])
    content {
      condition {
        age                   = try(lifecycle_rule.value.age, null)
        matches_storage_class = try(lifecycle_rule.value.matches_storage_class, null)
      }
      action {
        type          = try(lifecycle_rule.value.action_type, null)
        storage_class = try(lifecycle_rule.value.storage_class, null)
      }
    }
  }
}

### GCS BUCKET OBJECTS ###

### Files ('/input' and "/invalid") ###
resource "google_storage_bucket_object" "files" {
  for_each = local.bucket_object_config
  name     = each.key
  content  = try(each.value.content, null)
  source   = try(each.value.source, null)
  bucket   = each.value.bucket
}

### Queries ###
resource "google_storage_bucket_object" "queries" {
  bucket   = local.magasin-cie-utils
  for_each = fileset("../queries", "**")
  name     = "queries/${each.value}"
  source   = "../queries/${each.value}"
}

### Schemas ###
resource "google_storage_bucket_object" "schemas" {
  bucket   = local.magasin-cie-utils
  for_each = fileset("../schemas", "**")
  name     = "schemas/${each.value}"
  source   = "../schemas/${each.value}"
}