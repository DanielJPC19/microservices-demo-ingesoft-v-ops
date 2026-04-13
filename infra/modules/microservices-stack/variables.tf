variable "environment" {
  description = "Deployment environment: dev, staging, or prod"
  type        = string
}

variable "docker_username" {
  description = "Docker Hub username used to pull images"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy (e.g. prod, staging, dev, or a git SHA)"
  type        = string
  default     = "prod"
}

variable "db_password" {
  description = "PostgreSQL password (injected from CI/CD secret, never hardcoded)"
  type        = string
  sensitive   = true
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "appuser"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "votes"
}
