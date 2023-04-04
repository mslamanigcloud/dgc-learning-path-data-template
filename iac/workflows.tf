resource "google_project_service" "workflow" {
  project            = var.project_id
  service            = "workflows.googleapis.com"
  disable_on_destroy = false
}


resource "google_workflows_workflow" "workflows" {
  for_each        = fileset(path.module, "../cloud_workflows/**")
  project         = var.project_id
  name            = trimsuffix(trimprefix(each.value, "../cloud_workflows/"), ".yaml")
  region          = var.region
  source_contents = file(each.value)
}