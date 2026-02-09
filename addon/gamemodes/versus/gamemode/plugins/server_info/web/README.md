# Source Engine Server Query API

A PHP-based HTTP API that acts as a middleman for querying Source engine game servers using the A2S protocol.

## Installation

### 1. PHP API Setup

1. Upload `index.php` to your web server
2. Ensure your PHP installation has the `sockets` extension enabled:
    - Check `php.ini` for `extension=sockets`
    - Restart your web server after enabling
3. Make sure your server allows outbound UDP connections
4. Note the URL where you uploaded the file (e.g., `https://example.com/`)
5. Copy `config.php.example` to `config.php` and update the allowlist to specify which IPs/ports can use the API.

## API Usage

### Test during development

To quickly spin up a local test server, you can use PHP's built-in server:

```bash
php -S localhost:8000
```

### Direct HTTP Requests

#### Get Server Info

```
GET https://example.com/index.php?ip=127.0.0.1&port=27015&type=info
```

### Response Format

**Success Response:**

```json
{
    "success": true,
    "server": "127.0.0.1:27015",
    "type": "info",
    "data": {
        "name": "My GMod Server",
        "map": "gm_flatgrass",
        "game": "Garry's Mod",
        "players": 5,
        "max_players": 32,
        "vac": "secured",
        ...
    }
}
```

**Error Response:**

```json
{
    "success": false,
    "error": "Failed to receive response - server may be offline"
}
```

## Server Info Data Fields

The `info` query returns:

- `protocol` - Protocol version
- `name` - Server name
- `map` - Current map
- `folder` - Game folder
- `game` - Game description
- `app_id` - Steam App ID
- `players` - Current player count
- `max_players` - Maximum players
- `bots` - Number of bots
- `server_type` - "dedicated", "listen", or "proxy"
- `environment` - "linux", "windows", or "mac"
- `visibility` - "public" or "private"
- `vac` - "secured" or "unsecured"
- `version` - Game version
- `port` - Server port (if available)
- `steam_id` - Server Steam ID (if available)
- `keywords` - Server keywords (if available)

## Troubleshooting

### "Failed to create socket"

- Ensure PHP's `sockets` extension is enabled
- Check `php.ini` for `extension=sockets`

### "Failed to receive response - server may be offline"

- Verify the server IP and port are correct
- Check if the server is actually online
- Ensure your web server can make outbound UDP connections
- Some hosting providers block UDP traffic

### GMod HTTP Error

- Make sure you've specified the correct API URL with the `versus_server_info_api_endpoint` convar:

  ```
  versus_server_info_api_endpoint "https://experiment.games/server-info-mhSShrvoxY/"
  ```

- Verify your web server has CORS enabled (the script includes this)
- Check GMod console for detailed error messages
- Take note that Garry's Mod will not connect with HTTP to localhost (place it on a public IP or use a tunneling service like ngrok for local testing)
