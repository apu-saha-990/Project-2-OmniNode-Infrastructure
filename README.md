# OmniNode Infrastructure Manager

A hands-on project where I built a working system to run, monitor, and manage two live blockchain nodes on one machine — with automatic alerts, a live dashboard, and a simple command-line tool to control everything.

---

## What Problem Does This Solve

Running a blockchain node is not just about switching it on. It needs to stay online, stay connected to the network, and someone needs to know immediately when something goes wrong. Most people who run nodes do it manually — they check in when they remember, and they find out something broke hours after it happened. I built this project to solve that. The nodes run automatically, the system watches them around the clock, and if anything goes wrong it sends an alert to my phone within minutes. No manual checking. No surprises.

---

## How It Works

1. Two blockchain nodes start up inside isolated containers on the same machine — one for Bitcoin, one for Ethereum
2. A third container runs alongside them as the Ethereum consensus layer — it keeps Ethereum in sync with the rest of the network
3. A custom script I wrote queries the Bitcoin node every 15 seconds and pulls out key numbers — block height, peer connections, sync progress
4. A metrics collection system scrapes those numbers from all nodes every 15 seconds and stores them
5. A live dashboard reads those numbers and displays them visually — you can see the health of every node at a glance
6. Six alert rules watch those numbers continuously — if a node goes down, loses peers, or stops syncing, an alert fires
7. The alert gets routed through a small bridge I built and lands in a Discord channel as a readable message
8. A separate watchdog process runs outside all of this — it checks everything independently every 60 seconds and sends its own alert directly to Discord if Prometheus itself goes down
9. A command-line tool wraps all of this so I can start, stop, restart, check health, run backups, and export logs with simple one-line commands

---

## What's Built

**Two live blockchain nodes** — Bitcoin Core running on testnet and Ethereum running on the Sepolia test network. Same software as mainnet, just pointed at test networks so it syncs in hours instead of weeks.

**An Ethereum consensus client** — Ethereum requires two separate pieces of software to run together. This is the second piece. It communicates with the Ethereum node using a shared secret key to prove they belong to the same setup.

**A custom Bitcoin metrics script** — I wrote this myself. Bitcoin does not expose metrics in the format the monitoring system expects, so I built a small script that queries Bitcoin, translates the numbers, and serves them in the right format.

**A metrics collection and storage system** — pulls numbers from all four sources every 15 seconds and stores them locally. Everything the dashboard and alerts need comes from here.

**A live dashboard** — shows node status, sync progress, peer counts, and network traffic in real time. Auto-loads on startup with no manual setup needed.

**An alerting system with six rules** — watches for nodes going down, peers dropping too low, sync stalling, and disk filling up. Fires within two minutes of a problem starting.

**A custom Discord alert bridge** — I built this myself because the third-party images available for this job had a bug where the message format was wrong and alerts arrived unreadable. Forty lines of Python, fully under my control.

**An independent watchdog** — runs separately from the rest of the monitoring system. If the monitoring system itself has a problem, this is the last thing standing. It checks everything directly and reports straight to Discord.

**A command-line tool** — wraps the entire stack. Start everything, stop everything, check health, view logs, run backups, detect available hardware and set resource limits automatically.

**A setup script** — takes a fresh machine from zero to fully running in under 60 seconds. Two modes: automatic for demos, step-by-step for learning.

**Cloud server provisioning** — five configuration files that spin up a cloud server, open the right ports, and attach storage. Dry-run tested — no real account needed to verify it works.

**Server configuration automation** — a 22-step playbook that configures a fresh server from scratch: installs dependencies, sets up the firewall, registers the stack as a system service, and clones the project. Dry-run tested.

**Kubernetes manifests** — eight files that deploy the full stack on a local Kubernetes cluster. Includes persistent storage, config management, and secrets handling.

---

## A Bug I Found

The Bitcoin node kept restarting every 30 seconds. No useful error message in the logs — just a crash and restart, crash and restart, on a loop.

I spent time ruling out the obvious things. The container was starting. The ports were open. The credentials looked right. Everything pointed to a config problem but nothing in the logs told me what.

Eventually I found it. Bitcoin Core has a quirk with its config file — when you run it in testnet mode, it only reads settings that are written under a section header called `[test]`. Any settings written above that header get completely ignored. No warning. No error. Just silently ignored.

My config had all the connection and authentication settings at the top of the file, outside that section. Bitcoin was starting up with no valid config, failing to bind to the right port, and restarting. Over and over.

The broken config looked like this:

```ini
rpcuser=omninode_btc
rpcpassword=OmniNode@2025!
rpcport=8332
rpcbind=0.0.0.0
```

The fix was moving everything under the right header:

```ini
[test]
rpcuser=omninode_btc
rpcpassword=OmniNode@2025!
rpcport=8332
rpcbind=0.0.0.0
```

One line added. Node came up immediately. I confirmed it was working by querying the node directly from the terminal and getting a valid response back.

The lesson: when something fails silently with no useful error, the problem is usually a config the software is quietly ignoring. Always verify the software actually read what you gave it.

---

## How I Built This

I'm a career changer from a factory and manufacturing background. No CS degree. No bootcamp.

I use AI (Claude) throughout development — as a learning tool, code reviewer, and debugging partner. Every terminal error went back to Claude. The decisions are mine — what to build, how to structure it, what broke, what I changed.

I made every call: running test networks instead of mainnet so the demo syncs in hours not weeks, building my own Discord bridge instead of using a third-party image that had a payload bug, writing my own Bitcoin metrics script because Bitcoin doesn't speak the format the monitoring system expects, choosing to snapshot node state for backups instead of copying raw blockchain data. I validated everything by running it. If it's in this repo, it works.

---

## What I Learned

- Bitcoin's config file is section-aware — testnet settings must go under a `[test]` header or they get silently ignored. This caused a restart loop that took time to track down.
- Ethereum needs two separate programs running together to work. They authenticate with each other using a shared secret file — if the file is missing or different between the two, the consensus layer won't sync.
- Ethereum removed the lightweight sync option in recent versions. There are only two real choices now: sync everything, or sync everything from an archive. I picked the faster of the two.
- The monitoring system uses container names to find things on the network, not IP addresses. Docker handles the name-to-address translation automatically.
- Dashboard config UIDs must match exactly between the dashboard file and the provisioning config. One character off and the dashboard loads with no data and no error explaining why.
- Docker Compose has a way to inject extra settings without touching the main config file. The resource manager uses this to set CPU and memory limits based on what hardware it detects.
- The third-party images for routing alerts to Discord had a formatting bug — the messages arrived broken. Building a small custom bridge fixed it cleanly and gave me full control over the output.
- Ansible has a dry-run mode that walks through every step without making changes. The only step that fails in dry-run is the git clone — because the repo didn't exist yet on the test machine. Everything else checks out clean.

---

## Running It

```bash
# Clone and enter
git clone https://github.com/apu-saha-990/Project02-omninode-infrastructure.git
cd omninode-infrastructure

# Run setup — interactive or automatic
bash omni-setup.sh

# Or manually
cp .env.example .env
# Edit .env with your values
./omninode start all

# Check status
./omninode status
./omninode health

# Stop (auto-exports logs)
./omninode stop all

# Resource manager
./omninode resources

# Backup
./scripts/backup.sh

# Terraform dry run — no real account needed
cd terraform
terraform plan -var="do_token=dummy_token" -var="ssh_public_key=ssh-rsa AAAAB3NzaC1yc2E demo"

# Ansible dry run
ansible-playbook -i ansible/inventory-local.ini ansible/playbooks/setup.yml --check
```

### Kubernetes

Full install and deploy guide is in `kubernetes/COMMANDS.md`. Quick start:

```bash
# Start local cluster
minikube start --driver=docker --cpus=4 --memory=8192

# Deploy full stack
kubectl apply -f kubernetes/namespace.yml
kubectl apply -f kubernetes/configmap.yml
kubectl apply -f kubernetes/secrets.yml
kubectl apply -f kubernetes/persistent-volumes.yml
kubectl apply -f kubernetes/bitcoin-deployment.yml
kubectl apply -f kubernetes/ethereum-deployment.yml
kubectl apply -f kubernetes/lighthouse-deployment.yml
kubectl apply -f kubernetes/monitoring-deployment.yml

# Required after deploy
kubectl create configmap prometheus-config \
  --from-file=prometheus.yml=monitoring/prometheus/prometheus.yml \
  --from-file=alerts.yml=monitoring/prometheus/alerts.yml \
  -n omninode
kubectl rollout restart deployment/prometheus -n omninode

# Verify
kubectl get pods -n omninode
```

---

## What's Next

- **Mainnet support** — the nodes currently run on test networks. Pointing them at real networks is the next step toward a deployment that could support a live operation rather than a demo environment.

- **Automated secret rotation** — the shared authentication key between the two Ethereum components currently requires a manual process to rotate. Automating that — regenerate, redistribute, restart — removes a step that is easy to forget and easy to get wrong.

- **Centralised log storage with 90-day retention** — right now logs live inside individual containers and disappear when a container restarts. Pulling everything into one place with a fixed retention window means nothing gets lost and everything is searchable — a basic requirement for any environment where you need to reconstruct what happened and when.

- **Container hardening** — containers currently run with more permissions than they need. Locking them down — removing root access, restricting what each container can touch on the host — reduces the damage an attacker can do if one container is compromised.

- **Security compliance checks in the build pipeline** — automatically flag containers that don't meet baseline security standards before they deploy, not after. Catches problems at the door rather than in production.

- **Network separation** — nodes talk to nodes, monitoring talks to monitoring, management stays on its own lane. Mixing them is a risk. Separating them means a problem in one layer can't move sideways into another.

- **Disk alert at 80% capacity** — blockchain data grows continuously. An alert at 80% gives enough time to act before the node runs out of space and stops. Finding out at 100% is too late.

- **Health endpoint** — a simple status check that external tools can query without needing direct access to the stack. Useful for integrating into a broader monitoring environment without exposing internal systems.

- **Audit logging** — every command run against the stack recorded with a timestamp. No exceptions. In any environment where you need to account for who did what and when, this is not optional.

- **Automated backup testing** — backups run on a schedule but are never tested. A backup that has never been restored is not a backup. Automated restore tests confirm recovery actually works before it's needed.

---

## Tech Stack

| What it does | Technology |
|---|---|
| Bitcoin node | Bitcoin Core (lncm/bitcoind:v25.0) |
| Ethereum execution node | Geth (ethereum/client-go:stable) |
| Ethereum consensus layer | Lighthouse (sigp/lighthouse:latest) |
| Container runtime | Docker + Docker Compose |
| Local orchestration | Kubernetes — minikube |
| Cloud server provisioning | Terraform — DigitalOcean provider |
| Server configuration | Ansible |
| Metrics collection and storage | Prometheus |
| Custom Bitcoin metrics | Python (bitcoin-exporter.py) |
| Live dashboard | Grafana — auto-provisioned |
| Alert routing | Alertmanager |
| Discord alert bridge | Python + Flask (discord-proxy.py) |
| Independent watchdog | Bash + Python (health-watch) |
| Scripting | Bash + Python |

---

## Project Structure

```
omninode-infrastructure/
├── .env                          # Live credentials and config
├── .env.example                  # Template for new deployments
├── docker-compose.yml            # Main stack — 9 containers
├── omninode                      # Root CLI launcher
├── omni-setup.sh                 # Fresh machine setup script
├── docker/
│   ├── bitcoin/bitcoin.conf      # Bitcoin node config
│   ├── bitcoin/data/             # Bitcoin blockchain data (gitignored)
│   ├── ethereum/data/            # Ethereum blockchain data (gitignored)
│   └── lighthouse/data/          # Consensus layer data + shared secret
├── scripts/
│   ├── omninode.sh               # Main CLI logic
│   ├── bitcoin-exporter.py       # Custom Bitcoin metrics script
│   ├── discord-proxy.py          # Custom Discord alert bridge
│   ├── health-watch.sh           # Independent watchdog
│   ├── backup.sh                 # State snapshot backup
│   ├── resource-manager.sh       # Hardware detection
│   └── check-ports.sh            # Port availability checker
├── monitoring/
│   ├── prometheus/               # Metrics config and alert rules
│   └── grafana/                  # Dashboard and datasource provisioning
├── terraform/                    # Cloud server definitions
├── ansible/                      # Server configuration playbook
├── kubernetes/                   # 8 manifests + deploy guide
├── backups/                      # Auto-generated snapshots (gitignored)
└── logs/                         # Session log exports (gitignored)
```

---

