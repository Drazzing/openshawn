# Connect Cursor to OpenClaw

If you see **"disconnected (1008): unauthorized: gateway token missing"** in Cursor’s OpenClaw panel:

## 1. Get your gateway token

From the repo folder:

```powershell
# PowerShell
(Get-Content .env | Select-String "OPENCLAW_GATEWAY_TOKEN").ToString().Split("=",2)[1].Trim()
```

Or open `.env` and copy the value of `OPENCLAW_GATEWAY_TOKEN` (long hex string).

## 2. Add it in Cursor

1. Open **Cursor Settings** (Ctrl+,).
2. Search for **OpenClaw** or **gateway**.
3. Set:
   - **Gateway URL:** `http://127.0.0.1:18789`
   - **Token:** paste the token from step 1.
4. Save and reconnect (reload the OpenClaw / Claw panel if needed).

## 3. Restart gateway (optional)

```powershell
.\docker-start-secure.ps1
```

The token is also printed when you run the start script.
