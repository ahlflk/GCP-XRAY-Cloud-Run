# GCP-V2RAY: Deploy Xray/V2Ray on Google Cloud Run

This repository provides a simple way to deploy Xray (V2Ray fork) on Google Cloud Run with support for VLESS-WS, VLESS-gRPC, and Trojan-WS protocols. It's optimized for serverless scaling and uses TLS for security.

## Features
- **Protocols**: VLESS + WebSocket/TLS, VLESS + gRPC/TLS, Trojan + WebSocket/TLS
- **Auto-Configuration**: Uses environment variables or script for UUID/password setup
- **Lightweight**: Alpine/Debian base image, minimal footprint
- **Deployment Script**: Included `deploy.sh` for one-command setup
- **Timezone Support**: Myanmar time (Asia/Yangon) for logs and notifications

## Prerequisites
- Google Cloud SDK (`gcloud`) installed
- A GCP project with billing enabled
- Git installed
- Optional: Telegram Bot for notifications

## Quick Start
1. **Clone the Repo**:
git clone https://github.com/ahlflk/GCP-XRAY-Cloud-Run.git cd GCP-XRAY-Cloud-Run

2. **Run Deployment Script**:
chmod +x deploy.sh ./deploy.sh

- Follow prompts for protocol, region, CPU/memory, etc.
- Defaults: VLESS-WS, us-central1, 2 CPU, 2Gi RAM
- Telegram integration optional for share links

3. **Configuration**:
- Edit `config.json` for custom inbounds/outbounds
- PLACEHOLDER_UUID will be replaced by script with your UUID

4. **Build & Deploy**:
- Script auto-builds and deploys to Cloud Run
- Access via generated URL (e.g., https://gcp-ahlflk-abc123-uc.a.run.app)

## Protocol Setup
- **VLESS-WS**: Path `/ahlflk`, UUID-based auth
- **VLESS-gRPC**: ServiceName `ahlflk`, gRPC transport
- **Trojan-WS**: Path `/ahlflk`, password `ahlflk`

Share links generated automatically (e.g., `vless://uuid@domain:443?...`).

## Customization
- **Dockerfile**: Modify for custom Xray version or add geoip.dat
- **Config.json**: Add fallbacks, routing rules
- **Env Vars**: Set in Cloud Run for dynamic config

## Telegram Integration
- Select "Send to Channel/Bot" in script
- Bot sends formatted message with link, times, and copy button

## Troubleshooting
- **Build Fails**: Check geo files download; use `--no-cache` in Docker
- **Port Issues**: Cloud Run uses 8080; map externally if needed
- **TLS**: Uses self-signed; for prod, upload certs
- **Costs**: ~$0.02/hour idle; scales to zero

## License
MIT License - Free to use/modify.

For issues, open a GitHub issue or contact ahlflk.

## 👤 Author

Made with ❤️ by [AHLFLK2025channel](https://t.me/AHLFLK2025channel)

---

## #Crd

---

## 🚀 Cloud Run One-Click GCP-VLESS

Run this script directly in **Google Cloud Shell**:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ahlflk/GCP-XRAY-Cloud-Run/refs/heads/main/gcp-xray-cloud-run.sh)
