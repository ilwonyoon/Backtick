# ChatGPT Setup Guide

Connect Backtick to ChatGPT so you can read and save notes and memory documents from ChatGPT conversations.

## How It Works

Backtick runs a local MCP server on your Mac. ChatGPT is a web service that cannot reach your Mac directly, so a **tunnel** creates a public HTTPS URL that bridges the two.

```
ChatGPT web ──▶ tunnel (public URL) ──▶ your Mac (localhost:8844) ──▶ Backtick MCP
```

## Option 1: ngrok (Easiest)

### Step 1: Install ngrok

```bash
brew install ngrok
```

### Step 2: Create a free ngrok account

Go to [ngrok.com](https://ngrok.com) and sign up (free). Then connect your account:

```bash
ngrok config add-authtoken YOUR_TOKEN
```

You'll find your auth token in the ngrok dashboard after signing in.

### Step 3: Enable in Backtick

1. Open Backtick → Settings → Connectors
2. Turn on **ChatGPT & Web Connectors**
3. Click **Launch ngrok** — a Terminal window opens with ngrok running
4. The **Tunnel URL** field will show your ngrok URL

### Step 4: Connect in ChatGPT

1. Copy the **Remote MCP URL** from Backtick Settings
2. In ChatGPT web → Settings → Apps → Add App
3. Paste the URL and authorize

### Note

- ngrok must be running whenever you want to use Backtick from ChatGPT
- If you close the Terminal, click **Launch ngrok** again in Backtick Settings
- Free ngrok gives you a fixed URL per account

---

## Option 2: Cloudflare Tunnel (More Stable)

Cloudflare Tunnel provides a permanent, always-on connection. Recommended if you use ChatGPT with Backtick frequently.

### Step 1: Install cloudflared

```bash
brew install cloudflare/cloudflare/cloudflared
```

### Step 2: Authenticate

```bash
cloudflared login
```

This opens a browser to link your Cloudflare account.

### Step 3: Create a tunnel

```bash
cloudflared tunnel create backtick
```

### Step 4: Configure the tunnel

Edit `~/.cloudflared/config.yml`:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /Users/<you>/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: mcp.yourdomain.com
    service: http://localhost:8844
  - service: http_status:404
```

### Step 5: Add DNS record

```bash
cloudflared tunnel route dns backtick mcp.yourdomain.com
```

### Step 6: Run as a service

```bash
cloudflared service install
```

This creates a launchd service that starts automatically on login. No Terminal window needed.

### Step 7: Configure Backtick

1. Open Backtick → Settings → Connectors → Show Details
2. Set **Tunnel URL** to `https://mcp.yourdomain.com`

### Step 8: Connect in ChatGPT

1. Copy the **Remote MCP URL** from Backtick Settings
2. In ChatGPT web → Settings → Apps → Add App
3. Paste the URL and authorize

### Advantages over ngrok

- **Always on** — runs as a system service, no Terminal window
- **Permanent URL** — never changes, even after reboot
- **No session limits** — ngrok free has 2-hour session resets
- **Faster** — uses QUIC/HTTP2, no response buffering

---

## Troubleshooting

### ChatGPT says "Resource not found" or "Token exchange failed"

- Make sure the tunnel is running (check Backtick Settings → Status)
- Click **Launch tunnel** to restart
- In ChatGPT: disconnect Backtick and reconnect

### "Install tunnel" button appears

- You need to install ngrok or cloudflared first (see above)
- After installing, restart Backtick

### Connection works briefly then drops

- This is common with ngrok free tier — consider switching to Cloudflare Tunnel
- Make sure only one tunnel is running at a time

### Status shows "Connected" but ChatGPT can't reach it

- Try a new ChatGPT conversation (old conversations may cache stale connections)
- Check that your tunnel URL matches what's in Backtick Settings
