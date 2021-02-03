# Project
resource "aiven_project" "omega" {
  project = var.aiven_project_name
  #card_id = var.aiven_card_id # NOTE: Not needed with trial account!
}