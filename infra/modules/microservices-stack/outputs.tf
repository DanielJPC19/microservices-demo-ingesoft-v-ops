output "vote_service_url" {
  description = "External IP of the vote LoadBalancer (available after apply)"
  value       = try("http://${kubernetes_service.vote.status[0].load_balancer[0].ingress[0].ip}", "pending")
}

output "result_service_url" {
  description = "External IP of the result LoadBalancer (available after apply)"
  value       = try("http://${kubernetes_service.result.status[0].load_balancer[0].ingress[0].ip}", "pending")
}

output "environment" {
  description = "Deployment environment name"
  value       = var.environment
}
