terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  # backend "gcs" {
  #   bucket = "your-tf-state-bucket"
  #   prefix = "microservices-demo/staging"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

resource "google_container_cluster" "main" {
  name     = "votes-staging"
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false
}

resource "google_container_node_pool" "nodes" {
  name       = "default"
  location   = var.region
  cluster    = google_container_cluster.main.name
  node_count = 2

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.main.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.main.master_auth[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.main.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.main.master_auth[0].cluster_ca_certificate)
}

module "stack" {
  source = "../../modules/microservices-stack"

  environment     = "staging"
  docker_username = var.docker_username
  image_tag       = var.image_tag
  db_password     = var.db_password

  depends_on = [google_container_node_pool.nodes]
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "docker_username" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "staging"
}

variable "db_password" {
  type      = string
  sensitive = true
}

output "vote_url"     { value = module.stack.vote_service_url }
output "result_url"   { value = module.stack.result_service_url }
output "cluster_name" { value = google_container_cluster.main.name }
