# UniFi Protect Color Night Vision Toggle

A small bash script that turns **Color Night Vision** on or off for a UniFi Protect camera (built and tested with a **G6 Entry**) and reports its current state. It talks directly to your UniFi OS console and needs only `bash` and `curl`.

It's designed to be called from automation tools such as Homebridge (via [homebridge-script2](https://github.com/pponce/homebridge-script2)), cron or Shortcuts, but you can run it by hand too.

> **Note:** This uses the private UniFi Protect API, the same one the Protect web UI uses. It isn't officially documented and could change with a Protect update.

## Files

| File | Purpose |
|---|---|
| `unifi-doorbell-color-night-vision/cnv.sh` | Main script: `on`, `off`, or `state` |
| `unifi-doorbell-color-night-vision/cnv-on.sh` | Wrapper that runs `cnv.sh on` |
| `unifi-doorbell-color-night-vision/cnv-off.sh` | Wrapper that runs `cnv.sh off` |
| `unifi-doorbell-color-night-vision/homebridge-config-snippet.json` | Example Script2 config |

## Requirements

- A UniFi OS console running UniFi Protect (UDM, UCK, UNVR, etc.)
- A camera that supports Color Night Vision
- `bash` and `curl` (both included with macOS and most Linux distributions)

## Setup

### 1. Create a local UniFi user

The script logs in with a username and password, so it needs a **local-only** account. UI.com cloud accounts with MFA won't work.

1. In UniFi OS, open **Admins & Users** and click **Create New**.
2. Enable **Restrict to Local Access Only**.
3. Set a username and a strong password. Avoid `"` and `\` in the password.
4. Under app permissions, give **Protect** a role that can change camera settings (for example **Full Management**). A view-only role can log in but can't make changes.

### 2. Find your camera ID

Log in and list your cameras (replace the IP, username and password). Run these from any machine on your network:

```bash
curl -sk -c /tmp/unifi.cookie -X POST "https://CONSOLE_IP/api/auth/login" -H "Content-Type: application/json" -d '{"username":"YOUR_USER","password":"YOUR_PASSWORD"}' -o /dev/null
```

```bash
curl -sk -b /tmp/unifi.cookie "https://CONSOLE_IP/proxy/protect/api/cameras" | jq '.[] | {id, name, cnv: .ispSettings.isColorNightVisionEnabled}'
```

Copy the `id` of your camera. If `cnv` is `null`, that camera doesn't support Color Night Vision. (No `jq`? Drop the `| jq ...` part and search the output for `"id"` and `"name"`.)

### 3. Configure the script

Edit the four settings at the top of `cnv.sh`:

```bash
HOST="192.168.1.1"                     # your console's IP
USERNAME="protect-api"                 # local user from step 1
PASSWORD="CHANGE_ME"
CAMERA_ID="xxxxxxxxxxxxxxxxxxxxxxxx"   # from step 2
```

Then make the scripts executable and readable only by you, since `cnv.sh` holds your password:

```bash
chmod 700 unifi-doorbell-color-night-vision/*.sh
```

Make sure the scripts are owned by the user that will run them (for example, your Homebridge user).

### 4. Test it

```bash
./unifi-doorbell-color-night-vision/cnv.sh state
```

It should print `true` or `false`. Then try `on` and `off` and check that the setting changes in the Protect UI. Reload the camera's settings page to see the update.

## Usage

```bash
cnv.sh on      # enable Color Night Vision
cnv.sh off     # disable Color Night Vision
cnv.sh state   # print the current setting
```

- **Output:** `true` or `false` on stdout: the camera's setting after the command.
- **Exit codes:** `0` on success, `1` on failure (the reason goes to stderr), `2` for bad usage.
- `on` and `off` check the camera's response and fail if the setting didn't actually change.

## How it works

1. Logs in at `POST /api/auth/login` and saves the session cookie and CSRF token next to the script (`.cnv-cookie`, `.cnv-csrf`, owner-only permissions).
2. Sends `PATCH /proxy/protect/api/cameras/<id>` with `{"ispSettings":{"isColorNightVisionEnabled":true|false}}`, or a `GET` for `state`.
3. Reuses the saved session on later runs and logs in again automatically if it has expired (HTTP 401/403).

The console's self-signed certificate is accepted (`curl -k`), so only use this on your local network.

## Tip: spotlight timeout

The **Turn Off Spotlight After No Motion** slider is `ispSettings.spotlightDuration`, in seconds (`5`, `15`, `30`, `45` or `60`). You can set it the same way by changing the JSON body in `cnv.sh`, for example:

```json
{"ispSettings":{"isColorNightVisionEnabled":true,"spotlightDuration":30}}
```

## Troubleshooting

| Message | Likely cause |
|---|---|
| `cnv: login failed` | Wrong host, username or password, the account isn't local-only, or the console is unreachable |
| `cnv: PATCH failed: HTTP 403` | The user's Protect role can't edit cameras |
| `cnv: ... not found in response` | Wrong camera ID, or the camera doesn't support Color Night Vision |
| `cnv: Protect accepted the request but the value is still ...` | The camera ignored the change; check the setting in the Protect UI |

To force a fresh login, delete `.cnv-cookie` and `.cnv-csrf`.
