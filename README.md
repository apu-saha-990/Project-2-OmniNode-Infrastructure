# OmniNode Infrastructure Manager

A hands-on project where I built a working system to run, watch, and manage two live blockchain nodes on one machine — with automatic alerts, a live dashboard, and a simple tool to control everything from the command line.

---

## What Problem Does This Solve

Running a blockchain node is not just about switching it on. It needs to stay online, stay connected to the network, and someone needs to know immediately when something goes wrong. Most people who run nodes do it manually — they check in when they remember, and they find out something broke hours after it happened. I built this project to solve that. The nodes run automatically, the system watches them around the clock, and if anything goes wrong it sends an alert within minutes. No manual checking. No surprises.

---

## How It Works

1. Two blockchain nodes start up in separate isolated boxes on the same machine — one for Bitcoin, one for Ethereum
2. Ethereum needs two separate programs running together to stay in sync — a third isolated box runs the second program alongside the first two
3. A small script I wrote checks the Bitcoin node every 15 seconds and pulls out the key numbers — how many blocks it has, how many peers it's connected to, how far through the sync it is
4. A central collection system pulls numbers from all nodes every 15 seconds and stores them
5. A live dashboard reads those numbers and shows the health of every node at a glance
6. Six alert rules watch those numbers continuously — if a node goes down, loses connections, stops syncing, or the disk starts filling up, an alert fires
7. The alert goes through a small bridge I built and arrives in a Discord channel as a readable message
8. A separate independent watcher runs outside all of this — if the main monitoring system itself has a problem, this is the last line of defence and sends its own alert straight to Discord
9. A command-line tool wraps the whole thing — one simple command to start, stop, restart, check health, run backups, or export logs

---

## What's Built

**Two live blockchain nodes** — Bitcoin running on a test network and Ethereum running on a test network. Same software as the real networks, just pointed at test versions so they sync in hours instead of weeks.

**The second Ethereum program** — Ethereum needs two separate programs running together to work. This is the second one. It talks to the first one using a shared secret file to prove they belong to the same setup.

**A custom Bitcoin numbers script** — I wrote this myself. Bitcoin doesn't produce numbers in the format the monitoring system expects, so I built a small script that asks Bitcoin for its numbers, translates them, and passes them on in the right format.

**A central numbers collector** — pulls data from all four sources every 15 seconds and stores it locally. Everything the dashboard and alerts need comes from here.

**A live dashboard** — shows node status, sync progress, connection counts, and network activity in real time. Loads automatically on startup with no manual setup.

**Six alert rules** — watches for nodes going down, connections dropping too low, syncing stalling, and disk space filling up. Fires within two minutes of a problem starting.

**A custom Discord alert bridge** — I built this myself because the ready-made options available for this job had a bug where messages arrived broken and unreadable. Forty lines of code, fully under my control.

**An independent watchdog** — runs completely separately from everything else. If the main monitoring system goes down, this is still standing. It checks everything directly and sends its own alert to Discord.

**A command-line tool** — one tool that controls the whole stack. Start everything, stop everything, check health, view logs, run backups, and automatically detect what hardware is available and set limits accordingly.

**A setup script** — takes a brand new machine from nothing to fully running in under 60 seconds. Two modes: automatic for demos, step by step for learning.

**Cloud server setup files** — five files that spin up a cloud server, open the right ports, and attach storage. Tested in dry-run mode — no real account needed to verify they work.

**A server configuration playbook** — a 22-step automated process that sets up a fresh server from scratch: installs everything needed, sets up the firewall, registers the stack to start automatically, and downloads the project. Tested in dry-run mode.

**Eight cluster deployment files** — deploy the full stack on a shared local cluster. Includes storage, settings management, and secrets handling.

---

## A Bug I Found

The Bitcoin node kept restarting every 30 seconds. No useful error in the logs — just a crash and restart, crash and restart, on a loop.

I spent time ruling out the obvious things. The box was starting. The ports were open. The login details looked right. Everything pointed to a settings problem but nothing in the logs told me what.

Eventually I found it. Bitcoin has a quirk with its settings file — when you run it in test mode, it only reads settings that are written under a section called `[test]`. Anything written above that section gets completely ignored. No warning. No error. Just silently ignored.

My settings file had all the connection and login details at the top, outside that section. Bitcoin was starting up with no valid settings, failing to connect on the right port, and restarting. Over and over.

The broken settings file looked like this:

```ini
rpcuser=omninode_btc
rpcpassword=OmniNode@2025!
rpcport=8332
rpcbind=0.0.0.0
```

The fix was moving everything under the right section:

```ini
[test]
rpcuser=omninode_btc
rpcpassword=OmniNode@2025!
rpcport=8332
rpcbind=0.0.0.0
```

One line added. Node came up immediately. I confirmed it was working by asking the node a question directly from the terminal and getting a valid answer back.

The lesson: when something fails with no useful error message, the software is probably quietly ignoring the settings you gave it. Always check that it actually read what you gave it.

---

## How I Built This

I came from a factory and manufacturing background.

I use AI (Claude) throughout development — as a learning tool, code reviewer, and debugging partner. Every error message went back to Claude. The decisions are mine — what to build, how to structure it, what broke, what I changed.

I made every call: running test networks instead of real ones so the demo syncs in hours not weeks, building my own Discord bridge instead of using a ready-made option that had a bug, writing my own Bitcoin numbers script because Bitcoin doesn't produce what the monitoring system expects, choosing to take a snapshot of node state for backups instead of copying the full raw data. I validated everything by running it. If it's in this repo, it works.

The systems run. The tests pass. I can demo everything live.

---

## What I Learned

- Bitcoin's settings file is split into sections — test mode settings must go under a `[test]` header or they get silently ignored. This caused a restart loop that took time to track down
- Ethereum needs two separate programs running together to work. They prove they belong together using a shared secret file — if that file is missing or different between the two, the second program won't sync
- Ethereum removed its fast sync option in recent versions. The only real choices now are sync everything, or sync everything including the full historical archive. I picked the faster of the two
- The monitoring system uses the names of the isolated boxes to find things on the network, not their addresses — the name-to-address translation happens automatically
- Dashboard settings IDs must match exactly between two different config files. One character off and the dashboard loads with no data and no explanation why
- There is a way to add extra settings to the stack without touching the main settings file. The resource manager uses this to set CPU and memory limits based on what hardware it detects
- Ready-made options for routing alerts to Discord had a formatting bug — messages arrived broken. Building a small custom bridge fixed it and gave me full control
- The automated configuration tool has a dry-run mode that walks through every step without making real changes. The only step that fails in dry-run is downloading the project — because the project didn't exist yet on the test machine. Everything else checks out clean

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

# Dry run — no real account needed
cd terraform
terraform plan -var="do_token=dummy_token" -var="ssh_public_key=ssh-rsa AAAAB3NzaC1yc2E demo"

# Server setup dry run
ansible-playbook -i ansible/inventory-local.ini ansible/playbooks/setup.yml --check
```

For teams running this on a shared cluster rather than one machine, a full guide is in `kubernetes/COMMANDS.md`. Quick start:

```bash
minikube start --driver=docker --cpus=4 --memory=8192
kubectl apply -f kubernetes/namespace.yml
kubectl apply -f kubernetes/configmap.yml
kubectl apply -f kubernetes/secrets.yml
kubectl apply -f kubernetes/persistent-volumes.yml
kubectl apply -f kubernetes/bitcoin-deployment.yml
kubectl apply -f kubernetes/ethereum-deployment.yml
kubectl apply -f kubernetes/lighthouse-deployment.yml
kubectl apply -f kubernetes/monitoring-deployment.yml
kubectl create configmap prometheus-config \
  --from-file=prometheus.yml=monitoring/prometheus/prometheus.yml \
  --from-file=alerts.yml=monitoring/prometheus/alerts.yml \
  -n omninode
kubectl rollout restart deployment/prometheus -n omninode
kubectl get pods -n omninode
```

---

## Environment Variables

```bash
BITCOIN_RPC_USER=your_username         # Bitcoin node login username
BITCOIN_RPC_PASS=your_password         # Bitcoin node login password
ETH_RPC_URL=http://localhost:8545      # Address of the Ethereum node
JWT_SECRET=your_secret                 # Shared secret between the two Ethereum programs
DISCORD_WEBHOOK_URL=your_webhook       # Where Discord alerts get sent
GRAFANA_PASSWORD=your_password         # Dashboard login password
```

---

## What's Next

- **Real network support** — the nodes currently run on test networks. Pointing them at real networks is the next step toward a deployment that could support a live operation rather than a demo environment.

- **Automatic secret refresh** — the shared secret between the two Ethereum programs currently has to be rotated by hand. Automating that — generate a new one, update both programs, restart — removes a step that is easy to forget and easy to get wrong.

- **One place for all logs with 90-day history** — right now logs live inside individual isolated boxes and disappear when a box restarts. Pulling everything into one place with a fixed history window means nothing gets lost and everything is searchable — a basic requirement for any environment where you need to reconstruct what happened and when.

- **Tighter security on each box** — the isolated boxes currently run with more access than they need. Restricting what each one can touch on the host machine reduces the damage if one of them is ever compromised.

- **Security checks before anything goes live** — automatically check each box against a baseline security standard before it starts, not after. Catch problems at the door rather than in a running system.

- **Separate lanes for separate jobs** — nodes talk to nodes, monitoring talks to monitoring, management stays on its own lane. Mixing them is a risk. Keeping them separate means a problem in one area can't spread sideways into another.

- **Disk space alert at 80%** — blockchain data grows continuously. An alert at 80% gives enough time to act before the node runs out of space and stops. Finding out at 100% is too late.

- **A simple health check anyone can query** — a single address that returns a yes or no on whether everything is running. Useful for connecting into a wider monitoring setup without giving direct access to the system.

- **Audit logging** — every command run against the stack recorded with a timestamp. No exceptions. In any environment where you need to account for who did what and when, this is not optional.

- **Automatic backup testing** — backups run on a schedule but are never verified. A backup that has never been restored is not a backup. Automatic restore tests confirm recovery actually works before it's needed.

---

## Tech Stack

| What it does | Technology |
|---|---|
| Bitcoin node | Bitcoin Core (lncm/bitcoind:v25.0) |
| Ethereum node | Geth (ethereum/client-go:stable) |
| Second Ethereum program | Lighthouse (sigp/lighthouse:latest) |
| Runs and isolates each program | Docker + Docker Compose |
| Runs the stack on a shared cluster | Kubernetes (minikube) |
| Spins up cloud servers | Terraform — DigitalOcean |
| Configures fresh servers automatically | Ansible |
| Collects and stores live numbers | Prometheus |
| Custom Bitcoin numbers script | Python (bitcoin-exporter.py) |
| Live dashboard | Grafana |
| Routes alerts | Alertmanager |
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
│   ├── bitcoin-exporter.py       # Custom Bitcoin numbers script
│   ├── discord-proxy.py          # Custom Discord alert bridge
│   ├── health-watch.sh           # Independent watchdog
│   ├── backup.sh                 # State snapshot backup
│   ├── resource-manager.sh       # Hardware detection
│   └── check-ports.sh            # Port availability checker
├── monitoring/
│   ├── prometheus/               # Numbers collection config and alert rules
│   └── grafana/                  # Dashboard and data source setup
├── terraform/                    # Cloud server setup files
├── ansible/                      # Server configuration playbook
├── kubernetes/                   # 8 deployment files + guide
├── backups/                      # Auto-generated snapshots (gitignored)
└── logs/                         # Session log exports (gitignored)
```

---
