# Create a BigQuery dataset named raw in location EU.
resource "google_bigquery_dataset" "raw" {
  dataset_id = "raw"
  location   = "EU"
  project    = var.project_id
}

# Create a BigQuery dataset named cleaned in location EU.
resource "google_bigquery_dataset" "cleaned" {
  dataset_id = "cleaned"
  location   = "EU"
  project    = var.project_id
}

# Create a BigQuery table store in the dataset raw (schema is schemas/raw/store.json).
resource "google_bigquery_table" "store_raw" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  table_id   = "store"
  project    = var.project_id
  schema     = file("../schemas/raw/store.json")
}

# Create a BigQuery table store in the dataset cleaned (schema is schemas/cleaned/store.json).
resource "google_bigquery_table" "store_cleaned" {
  dataset_id = google_bigquery_dataset.cleaned.dataset_id
  table_id   = "store"
  project    = var.project_id
  schema     = file("../schemas/cleaned/store.json")
}