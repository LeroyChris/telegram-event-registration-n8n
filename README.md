# Automated Student Workshop Registration System via n8n, Docker, and Supabase

A production-grade, self-hosted backend automation architecture tailored for handling campus student workshop registrations. This repository demonstrates secure systems integration, infrastructure virtualization, automated edge network tunneling, and relational database design—built with a focus on optimization and zero-hardcoded security.

## 🚀 Architectural Overview & Data Workflow

The system operates as an asynchronous State Machine via n8n orchestration. It handles incoming event data from user interactions on Telegram, routes them based on context, and commits transactions to a relational database layer.

[Telegram Bot Trigger]
│ (Asynchronous Inbound Webhook via Cloudflare Edge Network)
▼
[Extract Update (Code Node)] ──> Normalizes Message & Callback query payloads
│
[Route: Switch Router]
├── (Native Message) ──> Processes commands (e.g., /start initiation)
└── (Inline Callback) ──> [Parse Callback Data (Code Node)]
│
Splits composite keys (fac_, evt_, cat_*)
│
[Route: Target Action Router]
├── (fac) ──> Fetch Active Events (Supabase REST API)
├── (evt) ──> Fetch Targeted Event Details
└── (cat) ──> Execute Student Registration Database Write


---

## 🛠️ Infrastructure & Tech Stack

- **Orchestration Engine:** n8n (Self-hosted workflow platform running JavaScript data normalization nodes).
- **Database Layer:** Supabase / PostgreSQL (Relational schema modeling with cascade constraints and indexing).
- **Virtualization & DevOps:** Docker & Docker Compose (Container isolation, multi-service networks, and persistent state volume management).
- **Network Routing & Security:** Cloudflare Quick Tunnels (Exposing local internal container gateways to the public internet securely without public port forwarding).

---

## 🧩 Key Engineering Decisions & Logic Implementations

### 1. Payload Normalization (`Extract Update` Node)
To minimize redundant routing branches down the pipeline, a unified JavaScript Code node intercepts disparate inbound payloads (`callback_query` and native `message`). The data is mapped into a strict, predictable JSON schema containing:
- `update_type` (Explicitly cast as string: `'callback'` | `'message'`)
- `chat_id` (Explicitly cast as string to prevent integer data type mutation across systems)
- Extracted user attributes (`first_name`, `text`, or `callback_data`).

### 2. Composite Key Strategy (`Parse Callback Data` Node)
To bypass Telegram's strict **64-byte payload limit** on inline keyboard callback data, this architecture implements a custom compact prefix routing engine. Data tokens are bound at the frontend with explicit entity identifiers (e.g., `fac_[UUID]`, `evt_[UUID]`). The parsing node extracts these tokens using sub-string delimiters to dynamically evaluate the pipeline's next state machine routing.

### 3. Server-Side Filtering & REST Ingestion
Instead of fetching bulk unstructured records into the automation memory, the workflow directly queries Supabase REST API endpoints utilizing explicit inline query filters (`faculty_id=eq.[UUID]`, `is_active=eq.true`). This guarantees highly optimized network payloads and reduces overall computing load.

### 4. Zero-Inbound Network Exposure
By nesting the Cloudflare agent (`cloudflared`) directly inside the local bridge network created by Docker Compose, port `5678` (n8n instance) remains fully hidden from the public internet. No router configuration or physical port forwarding is exposed on the host machine. All traffic travels via secure, outbound-initiated encrypted reverse proxy tunnels.

---

## 📁 Repository Structure

```text
telegram-event-registration-n8n/
├── database/
│   └── schema.sql             <- Clean Data Definition Language (DDL) schema for Supabase
├── docker/
│   └── docker-compose.yml     <- Multi-container network virtualization script
├── workflow/
│   └── workflow.json          <- Sanitized n8n workflow core blueprint JSON
└── README.md                  <- Technical documentation & systems breakdown
```

---

## ⚙️ Deployment & Installation Guide

To spin up this backend infrastructure in your local environment, follow these steps:

### Prerequisite
Ensure you have **Docker** and **Docker Compose** installed on your host system.

### Steps
1. Clone this repository to your local directory:
   ```bash
   git clone https://github.com/LeroyChris/telegram-event-registration-n8n
   cd telegram-event-registration-n8n/docker
   ```
2. Initialize the containers in detached mode:
   ```bash
   docker-compose up -d
   ```
3. Check container logs to verify network connectivity and retrieve your unique Cloudflare URL:
   ```bash
   docker logs cloudflare_edge_tunnel
   ```
4. Access your n8n automation panel at the generated domain, import the `workflow/workflow.json` file, and deploy your instance.
