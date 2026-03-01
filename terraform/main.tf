# =============================================================
# OmniNode — Terraform Infrastructure
# Provisions a cloud VPS ready to run OmniNode
# Provider: DigitalOcean
# =============================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# -------------------------------------------------------------
# SSH Key
# -------------------------------------------------------------
resource "digitalocean_ssh_key" "omninode" {
  name       = "omninode-key"
  public_key = var.ssh_public_key
}

# -------------------------------------------------------------
# Firewall
# -------------------------------------------------------------
resource "digitalocean_firewall" "omninode" {
  name = "omninode-firewall"

  droplet_ids = [digitalocean_droplet.omninode.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Bitcoin RPC
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8332"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Bitcoin P2P
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8333"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Ethereum HTTP RPC
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8545"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Ethereum WebSocket
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8546"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Ethereum P2P
  inbound_rule {
    protocol         = "tcp"
    port_range       = "30303"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Lighthouse P2P
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = "9000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Grafana
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Prometheus
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Alertmanager
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9093"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # All outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# -------------------------------------------------------------
# Droplet (VPS)
# -------------------------------------------------------------
resource "digitalocean_droplet" "omninode" {
  name     = "omninode-node"
  region   = var.region
  size     = var.droplet_size
  image    = "ubuntu-22-04-x64"
  ssh_keys = [digitalocean_ssh_key.omninode.fingerprint]

  user_data = <<-USERDATA
    #!/bin/bash
    apt-get update -y
    apt-get install -y git curl

    # Install Docker
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker root

    # Clone OmniNode
    git clone https://github.com/${var.github_repo}.git /opt/omninode
    cd /opt/omninode

    # Copy env
    cp .env.example .env

    echo "OmniNode provisioning complete. Run ./omninode start all to launch."
  USERDATA

  tags = ["omninode", "blockchain", "infrastructure"]
}

# -------------------------------------------------------------
# Volume (persistent storage for blockchain data)
# -------------------------------------------------------------
resource "digitalocean_volume" "omninode_data" {
  region      = var.region
  name        = "omninode-blockchain-data"
  size        = var.volume_size_gb
  description = "Persistent storage for Bitcoin and Ethereum node data"
}

resource "digitalocean_volume_attachment" "omninode_data" {
  droplet_id = digitalocean_droplet.omninode.id
  volume_id  = digitalocean_volume.omninode_data.id
}
