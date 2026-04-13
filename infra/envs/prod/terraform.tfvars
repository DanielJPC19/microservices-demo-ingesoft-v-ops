# Production environment — non-sensitive defaults.
# image_tag is overridden by CI/CD on every deploy (set to the git SHA).
# To roll back: dispatch cd-infra.yml manually with a previous SHA as image_tag.
# Sensitive values (db_password, docker_username, project_id) are injected
# by CI/CD as TF_VAR_* environment variables — do NOT commit secrets here.

image_tag = "prod"
region    = "us-central1"
# project_id is set via TF_VAR_project_id in CI/CD
