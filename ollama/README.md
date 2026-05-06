# Ollama + DeepSeek-R1 — Local LLM Stack

Local Ollama daemon for the Calories Guard backend. Runs `deepseek-r1:8b` and
optionally exposes itself to the public backend through a Cloudflare Tunnel.

## Layout

| File | Role |
|------|------|
| `Dockerfile` | Wraps `ollama/ollama` with a pre-warm script |
| `pull-and-serve.sh` | On first boot, pulls `deepseek-r1:8b` then `ollama serve` |
| `docker-compose.yml` | `ollama` service (always) + `cloudflared` (prod profile) |
| `.env.example` | Tunnel token + runtime knobs |

## Dev (local-only)

```bash
cp .env.example .env
docker compose up -d ollama
# First boot pulls ~5 GB — watch logs:
docker compose logs -f ollama
# Smoke
curl http://127.0.0.1:11434/api/tags
curl http://127.0.0.1:11434/api/chat -d '{
  "model": "deepseek-r1:8b",
  "stream": false,
  "messages": [{"role": "user", "content": "สวัสดี ตอบเป็นภาษาไทย"}]
}'
```

Backend `.env` (in `backend/.env`):

```
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=deepseek-r1:8b
```

## Production (Cloudflare Tunnel)

1. Cloudflare Zero Trust → **Networks → Tunnels → Create tunnel**
   → name `caloriesguard-ollama` → copy the token.
2. **Public hostnames** → add `ai.caloriesguard.com` → service
   `http://ollama:11434` (Docker service name).
3. (Recommended) **Access → Applications → Add** → Self-hosted →
   `ai.caloriesguard.com` → policy *Service Auth* → generate a Service
   Token → keep `Client ID` and `Client Secret`.
4. On the host:

   ```bash
   cp .env.example .env
   $EDITOR .env   # paste TUNNEL_TOKEN
   docker compose --profile prod up -d
   ```

5. Backend (Railway env vars):

   ```
   OLLAMA_BASE_URL=https://ai.caloriesguard.com
   OLLAMA_API_KEY=<service-token-secret>     # if Cloudflare Access is enabled
   ```

## Operations

| Task | Command |
|------|---------|
| Tail logs | `docker compose logs -f ollama` |
| Pull a different model | `docker exec caloriesguard-ollama ollama pull <model>` |
| List installed models | `docker exec caloriesguard-ollama ollama list` |
| Restart cleanly | `docker compose restart ollama` |
| Wipe model cache | `docker compose down && docker volume rm caloriesguard_ollama_data` |
| GPU support | Uncomment the `deploy.resources` block in `docker-compose.yml` and install `nvidia-container-toolkit` on the host |
