# Local Development

Use one stable entrypoint for local testing:

```powershell
cd C:\Users\hbj10\Documents\Codex\2026-06-27\dlr\work
.\scripts\start-local.ps1
```

This starts:

- Flutter web: `http://127.0.0.1:52733`
- API: `http://127.0.0.1:8082`
- PocketBase: `http://127.0.0.1:8090`

The local API uses port `8082` because port `8080` is already used by `TNSLSNR` on this PC.

Normal local startup uses `server/server-main/docker-compose.local.yml`. It always uses the normal PocketBase volume:

```text
server-main_pocketbase_data
```

Do not use `docker-compose.fresh.yml` for normal play testing. It uses a separate empty database:

```text
server-main_pocketbase_fresh_data
```

That empty database will not have the usual test account or character data, so login may look broken even when the server is healthy.

To check status:

```powershell
.\scripts\status-local.ps1
```

To stop intentionally:

```powershell
.\scripts\stop-local.ps1
```

If the web page is open but still points at an old API build, restart only Flutter:

```powershell
.\scripts\start-local.ps1 -RestartFlutter
```

After pulling backend or migration changes, rebuild Docker once:

```powershell
.\scripts\start-local.ps1 -Rebuild
```

To test with the existing production account and progress data, run:

```powershell
.\scripts\start-prod-web.ps1
```

That starts the same local Flutter web app, but points it at:

```text
http://15.165.116.173:8080
```

Use this when local PocketBase shows a new level 1 character but you want to test the real server account.
