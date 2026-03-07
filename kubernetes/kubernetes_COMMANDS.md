# OmniNode — Kubernetes Command Reference

Part of the OmniNode Infrastructure Manager (Project 2).
Kubernetes manifests for running the full OmniNode stack on a local minikube cluster.

---

## 1. Prerequisites

You need Docker running before minikube will work.

```bash
# Verify Docker is running
docker info

# Verify you are in the project root
pwd
# Should show: /home/<user>/omninode-infrastructure
```

---

## 2. Install kubectl

```bash
# Download latest stable release
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make executable
chmod +x kubectl

# Move to PATH
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

---

## 3. Install minikube

```bash
# Download minikube binary
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Install
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Remove the downloaded binary — do NOT commit this to git
rm minikube-linux-amd64

# Verify
minikube version
```

---

## 4. Start minikube

```bash
# Start with enough resources for the full OmniNode stack
minikube start --driver=docker --cpus=4 --memory=8192

# Verify cluster is running
minikube status

# Check nodes
kubectl get nodes
```

---

## 5. Deploy — Full Stack

Run these in order. Sequence matters.

```bash
# Namespace first — everything else goes inside it
kubectl apply -f kubernetes/namespace.yml

# Config and secrets before deployments
kubectl apply -f kubernetes/configmap.yml
kubectl apply -f kubernetes/secrets.yml

# Storage before pods
kubectl apply -f kubernetes/persistent-volumes.yml

# Blockchain nodes
kubectl apply -f kubernetes/bitcoin-deployment.yml
kubectl apply -f kubernetes/ethereum-deployment.yml
kubectl apply -f kubernetes/lighthouse-deployment.yml

# Monitoring stack
kubectl apply -f kubernetes/monitoring-deployment.yml
```

---

## 6. Prometheus ConfigMap Fix

This step is required. Without it the Prometheus pod stays stuck in ContainerCreating.

```bash
# Create the ConfigMap from the monitoring config files
kubectl create configmap prometheus-config \
  --from-file=prometheus.yml=monitoring/prometheus/prometheus.yml \
  --from-file=alerts.yml=monitoring/prometheus/alerts.yml \
  -n omninode

# Restart Prometheus to pick up the config
kubectl rollout restart deployment/prometheus -n omninode

# Watch it come up
kubectl get pods -n omninode -w
```

---

## 7. Verify Everything is Running

```bash
# All pods — should all show Running
kubectl get pods -n omninode

# All services
kubectl get services -n omninode

# Persistent volume claims
kubectl get pvc -n omninode

# Resource limits per pod
kubectl describe pod -n omninode -l app=bitcoin | grep -A8 "Limits"
kubectl describe pod -n omninode -l app=ethereum | grep -A8 "Limits"
```

---

## 8. Logs

```bash
# Bitcoin logs
kubectl logs -n omninode -l app=bitcoin -f

# Ethereum logs
kubectl logs -n omninode -l app=ethereum -f

# Lighthouse logs
kubectl logs -n omninode -l app=lighthouse -f

# Prometheus logs
kubectl logs -n omninode -l app=prometheus -f

# Grafana logs
kubectl logs -n omninode -l app=grafana -f
```

---

## 9. Demo Commands

These are the commands to run during an interview demo.

```bash
# Show all pods running
kubectl get pods -n omninode

# Show all services and ports
kubectl get services -n omninode

# Show resource limits on Ethereum pod
kubectl describe pod -n omninode -l app=ethereum | grep -A8 "Limits"

# Live Bitcoin logs
kubectl logs -n omninode -l app=bitcoin -f

# Live Ethereum logs
kubectl logs -n omninode -l app=ethereum -f

# Show persistent volumes
kubectl get pvc -n omninode
```

---

## 10. Access Services

minikube does not expose NodePort services on localhost automatically. Use minikube service to access them.

```bash
# Get Grafana URL
minikube service grafana -n omninode --url

# Get Prometheus URL
minikube service prometheus -n omninode --url

# Get all service URLs
minikube service list -n omninode
```

---

## 11. Troubleshooting

### Pod stuck in Pending
```bash
kubectl describe pod -n omninode <pod-name>
# Look for: Insufficient cpu/memory → minikube needs more resources
# Restart minikube with more: minikube start --cpus=4 --memory=8192
```

### Pod stuck in ContainerCreating
```bash
kubectl describe pod -n omninode <pod-name>
# Most common cause: prometheus-config ConfigMap not created
# Fix: run Step 6 above
```

### Pod in CrashLoopBackOff
```bash
kubectl logs -n omninode <pod-name> --previous
# Shows logs from the crashed container
```

### Prometheus showing no data in Grafana
```bash
# ConfigMap may not have been created — check
kubectl get configmap -n omninode
# Should show: prometheus-config

# If missing — run Step 6 again
```

### Lighthouse and Ethereum JWT warning
```bash
# Expected in Kubernetes — Lighthouse and Geth cannot share JWT secret
# between pods without a shared volume mount
# This is a known limitation of this manifest setup
# Docker Compose stack has this fully wired — use that for full sync demo
```

### Reset a single deployment
```bash
kubectl rollout restart deployment/<name> -n omninode
# e.g. kubectl rollout restart deployment/prometheus -n omninode
```

---

## 12. Teardown

```bash
# Delete everything in the namespace
kubectl delete namespace omninode

# Stop minikube
minikube stop

# Full reset — deletes the cluster entirely
minikube delete
```

---

## Notes

- Kubernetes manifests are in `kubernetes/` folder in this repo
- Lighthouse and Geth cannot share JWT secret between pods without a shared PVC — known limitation, use Docker Compose for full beacon sync demo
- The prometheus ConfigMap fix (Step 6) must be run manually after every fresh deploy
- minikube-linux-amd64 binary must never be committed to git — add to .gitignore
