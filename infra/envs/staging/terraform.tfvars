# Staging environment — non-sensitive defaults.
# Sensitive values (db_password, docker_username, project_id) are injected
# by CI/CD as TF_VAR_* environment variables — do NOT commit secrets here.

image_tag = "staging"
region    = "us-central1"
# project_id is set via TF_VAR_project_id in CI/CD
