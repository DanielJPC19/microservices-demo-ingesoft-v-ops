terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# ─────────────────────────────────────────────
# DB password — read by worker and result via
# secretKeyRef in the deployment env blocks.
# ─────────────────────────────────────────────
resource "kubernetes_secret" "db" {
  metadata {
    name = "db-secret"
  }
  data = {
    password = var.db_password
  }
}

# ─────────────────────────────────────────────
# PostgreSQL (Bitnami Helm chart)
# Service DNS: postgresql:5432
# ─────────────────────────────────────────────
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "~> 15.0"
  timeout    = 900

  set {
    name  = "auth.username"
    value = var.db_user
  }
  set_sensitive {
    name  = "auth.password"
    value = var.db_password
  }
  set {
    name  = "auth.database"
    value = var.db_name
  }
  set {
    name  = "primary.persistence.size"
    value = "5Gi"
  }
}

# ─────────────────────────────────────────────
# Kafka (Bitnami Helm chart, KRaft mode)
# Service DNS: kafka:9092
# ─────────────────────────────────────────────
resource "helm_release" "kafka" {
  name       = "kafka"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kafka"
  version    = "~> 28.0"
  timeout    = 900

  set {
    name  = "listeners.client.protocol"
    value = "PLAINTEXT"
  }
  set {
    name  = "listeners.interbroker.protocol"
    value = "PLAINTEXT"
  }
  set {
    name  = "persistence.size"
    value = "5Gi"
  }
}

# ─────────────────────────────────────────────
# Vote Service (Java / Spring Boot)
# ─────────────────────────────────────────────
resource "kubernetes_deployment" "vote" {
  metadata {
    name   = "vote"
    labels = { app = "vote" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "vote" } }
    template {
      metadata { labels = { app = "vote" } }
      spec {
        container {
          name  = "vote"
          image = "${var.docker_username}/vote:${var.image_tag}"
          port { container_port = 8080 }
          env {
            name  = "KAFKA_BOOTSTRAP_SERVERS"
            value = "kafka:9092"
          }
          resources {
            limits   = { cpu = "500m", memory = "512Mi" }
            requests = { cpu = "100m", memory = "256Mi" }
          }
        }
      }
    }
  }
  depends_on = [helm_release.kafka]
}

resource "kubernetes_service" "vote" {
  metadata { name = "vote" }
  spec {
    selector = { app = "vote" }
    port {
      port        = 80
      target_port = 8080
    }
    type = "LoadBalancer"
  }
}

# ─────────────────────────────────────────────
# Worker Service (Go)
# ─────────────────────────────────────────────
resource "kubernetes_deployment" "worker" {
  metadata {
    name   = "worker"
    labels = { app = "worker" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "worker" } }
    template {
      metadata { labels = { app = "worker" } }
      spec {
        container {
          name  = "worker"
          image = "${var.docker_username}/worker:${var.image_tag}"
          env {
            name  = "DB_HOST"
            value = "postgresql"
          }
          env {
            name  = "DB_PORT"
            value = "5432"
          }
          env {
            name  = "DB_USER"
            value = var.db_user
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db.metadata[0].name
                key  = "password"
              }
            }
          }
          env {
            name  = "DB_NAME"
            value = var.db_name
          }
          env {
            name  = "KAFKA_BROKERS"
            value = "kafka:9092"
          }
          resources {
            limits   = { cpu = "300m", memory = "256Mi" }
            requests = { cpu = "50m", memory = "128Mi" }
          }
        }
      }
    }
  }
  depends_on = [helm_release.postgresql, helm_release.kafka]
}

# ─────────────────────────────────────────────
# Result Service (Node.js)
# ─────────────────────────────────────────────
resource "kubernetes_deployment" "result" {
  metadata {
    name   = "result"
    labels = { app = "result" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "result" } }
    template {
      metadata { labels = { app = "result" } }
      spec {
        container {
          name  = "result"
          image = "${var.docker_username}/result:${var.image_tag}"
          port { container_port = 80 }
          env {
            name  = "DB_HOST"
            value = "postgresql"
          }
          env {
            name  = "DB_PORT"
            value = "5432"
          }
          env {
            name  = "DB_USER"
            value = var.db_user
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.db.metadata[0].name
                key  = "password"
              }
            }
          }
          env {
            name  = "DB_NAME"
            value = var.db_name
          }
          resources {
            limits   = { cpu = "300m", memory = "256Mi" }
            requests = { cpu = "50m", memory = "128Mi" }
          }
        }
      }
    }
  }
  depends_on = [helm_release.postgresql]
}

resource "kubernetes_service" "result" {
  metadata { name = "result" }
  spec {
    selector = { app = "result" }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
