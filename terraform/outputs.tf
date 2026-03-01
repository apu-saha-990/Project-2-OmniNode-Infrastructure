# =============================================================
# OmniNode — Terraform Outputs
# =============================================================

output "node_ip" {
  description = "Public IP address of the OmniNode server"
  value       = digitalocean_droplet.omninode.ipv4_address
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${digitalocean_droplet.omninode.ipv4_address}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${digitalocean_droplet.omninode.ipv4_address}:9090"
}

output "bitcoin_rpc_url" {
  description = "Bitcoin RPC endpoint"
  value       = "http://${digitalocean_droplet.omninode.ipv4_address}:8332"
}

output "ethereum_rpc_url" {
  description = "Ethereum RPC endpoint"
  value       = "http://${digitalocean_droplet.omninode.ipv4_address}:8545"
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh root@${digitalocean_droplet.omninode.ipv4_address}"
}
