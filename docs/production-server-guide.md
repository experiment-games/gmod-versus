# 🚀 Production Server Guide

**This guide picks up where the [Dev Server Guide](dev-server-guide.md) leaves off.** It covers what's different about running Versus for real players: multiple `srcds` instances that link to each other, keeping them running unattended, and deploying the web content that goes alongside them.

## Architecture Overview

A production Versus deployment is usually one Linux box running a dedicated `steam` user, hosting several `srcds` instances side by side:

* One **Hideout** server: the non-combat social hub map players start in.
* One or more **Contracts** servers: combat maps players get sent to.
* Optionally an **Endurance** server: the wave-survival mode.

Each instance lives in its own directory (`server_1`, `server_2`, `server_3`, ...), listens on its own port, uses its own [GSLT token](#6-authenticate-each-instance-gslt), and points at the same Workshop Collection for content. They're wired together with a handful of `versus_*` cvars (see [step 5](#5-per-instance-servercfg)) so the game can advertise "go to the Hideout" or "go fight" and hand players off between them.

Alongside the game servers, a web server (this guide assumes [Caddy](https://caddyserver.com/), matching the `Caddyfile` in the repo root) serves the loading screen and landing page that `sv_loadingurl` points at.

## Prerequisites

* A Linux server (this guide assumes Ubuntu/Debian) with a public IP.
* A dedicated `steam` system user to run everything as.
* [`tmux`](https://github.com/tmux/tmux) installed: `sudo apt-get install tmux`.
* A domain pointed at the server, if you want to serve the loading screen/landing page.
* One firewall port open per instance you plan to run (default `27015`, then `27016`, `27017`, ...).

## Step-by-Step Guide

### 1. Install SteamCMD

Same as the dev server guide, so follow the [Linux instructions here](https://developer.valvesoftware.com/wiki/SteamCMD#Linux) first.

### 2. Install the dedicated server software for each instance

[`tools/server/update_gmod.sh`](../tools/server/update_gmod.sh) wraps SteamCMD in a small helper. Add one call per instance you want to run:

```bash
update_server() {
    APP_ID=$1
    DIR=$2

    if [ ! -d "$HOME/$DIR" ]; then
        mkdir -p "$HOME/$DIR"
    fi

    /usr/games/steamcmd +force_install_dir "$HOME/$DIR" +login anonymous +app_update $APP_ID validate +quit
}

update_server 4020 "server_1"  # Hideout
update_server 4020 "server_2"  # Contracts
update_server 4020 "server_3"  # Endurance
```

Run this script whenever you need to install or update the Garry's Mod dedicated server binaries (e.g. after a Source engine update). Stop the affected instances first (see [step 9](#9-managing-running-servers)).

### 3. Set up the directory layout & addon

Clone this repository once, e.g. to `/srv/versus`, and symlink the `addon/` folder into **each** instance's `garrysmod/addons` directory using the same technique as the dev guide:

```bash
git clone https://github.com/experiment-games/gmod-versus /srv/versus

ln -s /srv/versus/addon /home/steam/server_1/garrysmod/addons/versus
ln -s /srv/versus/addon /home/steam/server_2/garrysmod/addons/versus
ln -s /srv/versus/addon /home/steam/server_3/garrysmod/addons/versus
```

Because every instance symlinks to the same checkout, a single `git pull` updates all of them at once (see [step 10](#10-deploying-code-updates)).

Also install [timschumi/gmod-chttp](https://github.com/timschumi/gmod-chttp) into each instance's `garrysmod/lua/bin/`, as described in the dev guide.

### 4. (Optional) Set up your own Workshop Collection

If you're hosting custom content, create a [Workshop Collection](https://wiki.facepunch.com/gmod/Workshop_for_Dedicated_Servers) and note its ID. You'll use that workshop collection ID for every instance via `+host_workshop_collection`.

### 5. Per-instance `server.cfg`

Each instance has its own `server_N/garrysmod/cfg/server.cfg`. Here's what a Hideout server's config looks like, with the cvars explained below:

```txt
hostname "My Versus Server | Hideout"
sv_location eu
sv_allowupload "0"
sv_allowdownload "0"
sv_loadingurl "https://your-domain.example/loading/"
lua_log_sv "1"
writeid
versus_combat_servers "<contracts-ip>:<port>"
versus_endurance_server "<endurance-ip>:<port>"
versus_moderation_openai_key "<your-openai-api-key>"
sv_voiceenable 0
```

| Cvar | Purpose |
| --- | --- |
| `hostname` | Name shown in the server browser. |
| `sv_location` | Region code shown in the server browser. |
| `sv_allowupload` / `sv_allowdownload` | Disable custom client content up/downloading. |
| `sv_loadingurl` | Custom loading screen, served by Caddy (see [step 11](#11-serving-the-loading-screen--landing-page-caddy)). |
| `lua_log_sv` | Enables serverside Lua error logging (used by the [Discord error reporting](#13-monitoring-discord-error-reports) job). |
| `writeid` | Writes the server's SteamID whitelist/ban files. |
| `versus_combat_servers` | Comma-separated `ip:port` list of Contracts servers, advertised on the contract board. Set on the **Hideout** instance. |
| `versus_hideout_server` | `ip:port` of the Hideout server, advertised to clients. Set on **Contracts**/**Endurance** instances. |
| `versus_endurance_server` | `ip:port` players are sent to after Endurance matchmaking. Set on the **Hideout** instance. |
| `versus_moderation_openai_key` | OpenAI API key used by the chat moderation plugin. This is a protected cvar (never sent to clients) (**never commit it to git.**) |
| `sv_voiceenable` | Optional, to disable in-game voice chat. |
| `versus_sunday_exclusive` | Optional, testing-only. Locks the server to only allow connections on Sundays; not needed for a normal deployment. |

In short: the **Hideout** instance points outward at its Contracts/Endurance siblings, and each **Contracts**/**Endurance** instance points back at the Hideout server so players can be routed home.

### 6. Authenticate each instance (GSLT)

Follow the dev guide's [Authenticating your server](dev-server-guide.md#authenticating-your-server-recommended) steps to generate a token, with one important difference for production:

**Generate a separate GSLT token per instance**, using that instance's actual public IP and port when creating it. Don't reuse one token across multiple servers as Steam ties each token to a specific address.

### 7. Launch scripts

[`tools/server/start_server.sh`](../tools/server/start_server.sh) is the launcher template. It starts `srcds_run` inside a detached `tmux` session so it keeps running after you log out, and logs to `/home/steam/server_launcher.log`:

```bash
cmd="/home/steam/server_1/srcds_run -console \
        -game garrysmod \
        -tickrate 100 \
        +maxplayers 64 \
        +gamemode versus \
        +map versus_c18_v1 \
        +host_workshop_collection 3674693854 \
        +sv_setsteamaccount <gslt-token>"

if [ "$1" == "debug" ]; then
    $cmd >> /home/steam/server_launcher.log
else
    /usr/bin/tmux new-session -d -s srcds "$cmd >> /home/steam/server_launcher.log"
fi
```

*Run with the `debug` argument (e.g: `./start_server.sh debug`) to start the server attached to your terminal instead of detached in tmux. This is useful for starting a temporary test server and spotting startup errors, or running commands in the server console. Once you enter `quit` or press CTRL+C, the server will be stopped.*

To run more than one instance, copy this script per instance and change:

* The install directory (`/home/steam/server_2/srcds_run`)
* `+port` (only the first instance needs to omit this, since `27015` is the default)
* The tmux session name (`-s`), so instances don't collide
* `-tickrate`, `+maxplayers`, `+map` as needed per instance
* `+sv_setsteamaccount` with that instance's own GSLT token

For example, a second (Contracts) instance on port `27016`:

```bash
cmd="/home/steam/server_2/srcds_run -console \
        -game garrysmod \
        -tickrate 66 \
        +port 27016 \
        +maxplayers 64 \
        +gamemode versus \
        +map versus_c18_v1 \
        +host_workshop_collection 3674693854 \
        +sv_setsteamaccount <gslt-token>"

/usr/bin/tmux new-session -d -s srcds_contracts "$cmd >> /home/steam/server_launcher.log"
```

### 8. Auto-start on boot

For each launch script, add an `@reboot` entry to the `steam` user's crontab so the servers come back up automatically after a reboot:

```bash
crontab -e
```

```bash
@reboot /home/steam/start_server_hideout.sh
@reboot /home/steam/start_server_contracts.sh
@reboot /home/steam/start_server_endurance.sh
```

### 9. Managing running servers

* [`tools/server/follow_logs.sh`](../tools/server/follow_logs.sh): tails an instance's console log.
* [`tools/server/reattach_server.sh`](../tools/server/reattach_server.sh): attaches to the `srcds` tmux session (detach again with `Ctrl+B` then `D` — **not** `Ctrl+C`, which kills the server).
* [`tools/server/stop_server.sh`](../tools/server/stop_server.sh): kills any running `srcds_run`/`srcds_linux` process.

**Caveat for multi-instance setups:** both `reattach_server.sh` (hardcoded to the `srcds` session name) and `stop_server.sh` (kills *every* `srcds_run`/`srcds_linux` process on the box) are written for a single-instance box. Once you're running several instances, use `tmux attach -t <your-session-name>` directly instead of the reattach script, and be aware that running `stop_server.sh` stops **all** instances at once.

### 10. Deploying code updates

[`tools/update-versus.sh`](../tools/update-versus.sh) pulls the latest code into `/srv/versus` and fixes permissions:

```bash
cd /srv/versus
eval "$(ssh-agent -s)"
ssh-add /home/<your-username>/.ssh/<your-deploy-key>
git restore .
git pull
sudo chmod +x /srv/versus/tools/discord-process-errors.sh
sudo chown -R www-data:www-data /srv/versus/
```

Because every instance symlinks to this same checkout, one `git pull` updates the gamemode everywhere. **Stop and start each instance** (not just change the map) for the update to fully take effect.

### 11. Serving the loading screen & landing page (Caddy)

The repo root [`Caddyfile`](../Caddyfile) serves `web/loadingscreen/dist` at `/loading/*` (what `sv_loadingurl` points at) and `web/landing/dist` everywhere else. To wire it up:

```bash
# Add caddy and steam to the www-data group, and hand the repo over to it
sudo usermod -aG www-data caddy
sudo usermod -aG www-data steam
sudo chown -R www-data:www-data /srv/versus/

# Point Caddy's systemd service at this repo's Caddyfile
sudo systemctl edit caddy
```

Add this override:

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/caddy run --environ --config /srv/versus/Caddyfile
ExecReload=
ExecReload=/usr/bin/caddy reload --config /srv/versus/Caddyfile
```

Then restart Caddy: `sudo systemctl restart caddy`.

*The `Caddyfile` also contains a commented-out block for an optional Laravel-based leaderboards site — see the comments in that file if you want to enable it later.*

### 12. Publishing Workshop content updates

If you maintain custom server content, [`tools/update-workshop-content.sh`](../tools/update-workshop-content.sh) packages `addon/` and any built maps into a `.gma` and publishes it to your Workshop item via `gmad`/`gmpublish`. It's a Windows-only script (`gmad.exe`/`gmpublish.exe`). Run it from a Windows machine with the Garry's Mod tools installed, configured via `GM_BIN_PATH` in `tools/.env` (see `tools/.env.example`).

### 13. Monitoring: Discord error reports

[`tools/discord-process-errors.sh`](../tools/discord-process-errors.sh) tails each instance's clientside/serverside Lua error logs and posts new errors to a Discord webhook. Set it up as a cron job running every minute as the `steam` user:

```bash
chmod +x /srv/versus/tools/discord-process-errors.sh
sudo -u steam crontab -e
```

```txt
*/1 * * * * /srv/versus/tools/discord-process-errors.sh
```

Configure it via `tools/.env` (copy from `tools/.env.example`): a webhook URL, and colon-separated `CLIENTSIDE_ERRORS`/`SERVERSIDE_ERRORS` paths (one per instance) with matching `SERVER_LABELS`.

## Secrets Checklist

Keep these out of git, and confirm the files they live in are ignored:

* **GSLT tokens**: launch scripts (`+sv_setsteamaccount`).
* **`versus_moderation_openai_key`**: each instance's `server.cfg`.
* **Database credentials**: `addon/gamemodes/versus/gamemode/core/sv_configuration.lua` (see the [dev server guide](dev-server-guide.md), step 11).
* **Discord webhook URL & Workshop publish credentials**: `tools/.env`.
