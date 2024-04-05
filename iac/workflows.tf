resource "google_workflows_workflow" "store_wkf" {
  project         = var.project_id
  name            = "store_wkf"
  description     = "SQL query store workflow"
  region          = var.region
  source_contents = file("../cloud_workflows/store_wkf.yaml")
}