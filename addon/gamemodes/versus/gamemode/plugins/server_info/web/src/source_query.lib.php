<?php

define('QUERY_TIMEOUT', 2); // seconds

class SourceQuery
{
  private $socket;
  private $ip;
  private $port;

  // A2S packet headers
  const A2S_INFO = "\xFF\xFF\xFF\xFF\x54Source Engine Query\x00";

  // Response types
  const S2A_INFO_SRC = 0x49; // 'I' - New format (post-2003)
  const S2A_INFO_DETAILED = 0x6D; // 'm' - Obsolete GoldSource format

  public function __construct($ip, $port)
  {
    $this->ip = $ip;
    $this->port = (int)$port;
  }

  /**
   * Create and configure UDP socket
   */
  private function createSocket()
  {
    $this->socket = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
    if (!$this->socket) {
      throw new Exception("Failed to create socket");
    }

    socket_set_option($this->socket, SOL_SOCKET, SO_RCVTIMEO, [
      'sec' => QUERY_TIMEOUT,
      'usec' => 0
    ]);

    socket_set_option($this->socket, SOL_SOCKET, SO_SNDTIMEO, [
      'sec' => QUERY_TIMEOUT,
      'usec' => 0
    ]);
  }

  /**
   * Send packet and receive response
   */
  private function sendPacket($packet)
  {
    if (!$this->socket) {
      $this->createSocket();
    }

    $sent = socket_sendto($this->socket, $packet, strlen($packet), 0, $this->ip, $this->port);
    if ($sent === false) {
      throw new Exception("Failed to send packet");
    }

    $response = '';
    $from = '';
    $fromPort = 0;

    $received = socket_recvfrom($this->socket, $response, 4096, 0, $from, $fromPort);
    if ($received === false) {
      throw new Exception("Failed to receive response - server may be offline");
    }

    return $response;
  }

  /**
   * Query server info (A2S_INFO)
   */
  public function getInfo()
  {
    $response = $this->sendPacket(self::A2S_INFO);
    $responseLen = strlen($response);

    if ($responseLen < 5) {
      throw new Exception("Response too short (" . $responseLen . " bytes) - invalid server response");
    }

    // Check response type
    $header = substr($response, 0, 4);
    $responseType = ord($response[4]);

    // Verify it's a valid A2S_INFO response
    if ($header !== "\xFF\xFF\xFF\xFF") {
      throw new Exception("Invalid response header");
    }

    // Check if server wants a challenge (0x41 = 'A')
    if ($responseType === 0x41) {
      // Server sent challenge, extract it and retry
      if ($responseLen < 9) {
        throw new Exception("Challenge response too short");
      }

      $challenge = substr($response, 5, 4);

      // Resend query with challenge appended
      $challengePacket = self::A2S_INFO . $challenge;
      $response = $this->sendPacket($challengePacket);
      $responseLen = strlen($response);

      if ($responseLen < 5) {
        throw new Exception("Response too short after challenge");
      }

      // Re-check response type
      $responseType = ord($response[4]);
    }

    if ($responseType === self::S2A_INFO_DETAILED) {
      // Obsolete GoldSource format (some old Source servers still use this)
      return $this->parseObsoleteInfo($response);
    } elseif ($responseType === self::S2A_INFO_SRC) {
      // Modern Source format
      return $this->parseSourceInfo($response);
    } else {
      throw new Exception("Unknown response type: 0x" . dechex($responseType) . " (expected 0x49 or 0x6D)");
    }
  }

  /**
   * Parse modern Source engine info response (0x49)
   */
  private function parseSourceInfo($response)
  {
    $responseLen = strlen($response);
    $pos = 5; // Skip header (4 bytes 0xFF) + type (1 byte)

    $info = [];

    // Read protocol version
    if ($pos >= $responseLen) throw new Exception("Truncated response at protocol");
    $info['protocol'] = ord($response[$pos++]);

    // Read strings with bounds checking
    $info['name'] = $this->readString($response, $pos);
    $info['map'] = $this->readString($response, $pos);
    $info['folder'] = $this->readString($response, $pos);
    $info['game'] = $this->readString($response, $pos);

    // Read App ID (2 bytes)
    if ($pos + 2 > $responseLen) {
      throw new Exception("Truncated response at app_id (pos: $pos, len: $responseLen, need: 2 more bytes)");
    }
    $appId = unpack('v', substr($response, $pos, 2))[1];
    $pos += 2;
    $info['app_id'] = $appId;

    // Read player counts
    if ($pos + 3 > $responseLen) throw new Exception("Truncated response at player counts");
    $info['players'] = ord($response[$pos++]);
    $info['max_players'] = ord($response[$pos++]);
    $info['bots'] = ord($response[$pos++]);

    // Read server type
    if ($pos >= $responseLen) throw new Exception("Truncated response at server_type");
    $serverType = $response[$pos++];
    $info['server_type'] = $serverType === 'd' ? 'dedicated' : ($serverType === 'l' ? 'listen' : 'proxy');

    // Read environment
    if ($pos >= $responseLen) throw new Exception("Truncated response at environment");
    $environment = $response[$pos++];
    $info['environment'] = $environment === 'l' ? 'linux' : ($environment === 'w' ? 'windows' : 'mac');

    // Read visibility
    if ($pos >= $responseLen) throw new Exception("Truncated response at visibility");
    $info['visibility'] = ord($response[$pos++]) === 1 ? 'private' : 'public';

    // Read VAC
    if ($pos >= $responseLen) throw new Exception("Truncated response at vac");
    $info['vac'] = ord($response[$pos++]) === 1 ? 'secured' : 'unsecured';

    // Version string
    $info['version'] = $this->readString($response, $pos);

    // EDF (Extra Data Flag) - optional
    if ($pos < $responseLen) {
      $edf = ord($response[$pos++]);

      if (($edf & 0x80) && $pos + 2 <= $responseLen) { // Port
        $info['port'] = unpack('v', substr($response, $pos, 2))[1];
        $pos += 2;
      }

      if (($edf & 0x10) && $pos + 8 <= $responseLen) { // SteamID
        $info['steam_id'] = unpack('P', substr($response, $pos, 8))[1];
        $pos += 8;
      }

      if (($edf & 0x40) && $pos + 2 <= $responseLen) { // SourceTV
        $info['spectator_port'] = unpack('v', substr($response, $pos, 2))[1];
        $pos += 2;
        $info['spectator_name'] = $this->readString($response, $pos);
      }

      if ($edf & 0x20) { // Keywords
        $info['keywords'] = $this->readString($response, $pos);
      }

      if (($edf & 0x01) && $pos + 8 <= $responseLen) { // GameID
        $info['game_id'] = unpack('P', substr($response, $pos, 8))[1];
        $pos += 8;
      }
    }

    return $info;
  }

  /**
   * Parse obsolete GoldSource/old Source info response (0x6D)
   */
  private function parseObsoleteInfo($response)
  {
    $responseLen = strlen($response);
    $pos = 5; // Skip header + type

    $info = [];

    // Read address
    $info['address'] = $this->readString($response, $pos);

    // Read server name
    $info['name'] = $this->readString($response, $pos);

    // Read map
    $info['map'] = $this->readString($response, $pos);

    // Read folder
    $info['folder'] = $this->readString($response, $pos);

    // Read game
    $info['game'] = $this->readString($response, $pos);

    // Read player counts
    if ($pos + 2 > $responseLen) throw new Exception("Truncated obsolete response at player counts");
    $info['players'] = ord($response[$pos++]);
    $info['max_players'] = ord($response[$pos++]);

    // Read protocol version
    if ($pos >= $responseLen) throw new Exception("Truncated obsolete response at protocol");
    $info['protocol'] = ord($response[$pos++]);

    // Read server type
    if ($pos >= $responseLen) throw new Exception("Truncated obsolete response at server_type");
    $serverType = $response[$pos++];
    $info['server_type'] = $serverType === 'd' ? 'dedicated' : ($serverType === 'l' ? 'listen' : 'proxy');

    // Read environment
    if ($pos >= $responseLen) throw new Exception("Truncated obsolete response at environment");
    $environment = $response[$pos++];
    $info['environment'] = $environment === 'l' ? 'linux' : ($environment === 'w' ? 'windows' : 'mac');

    // Read visibility
    if ($pos >= $responseLen) throw new Exception("Truncated obsolete response at visibility");
    $info['visibility'] = ord($response[$pos++]) === 1 ? 'private' : 'public';

    // Read mod flag
    if ($pos >= $responseLen) {
      // Some servers don't send mod info
      return $info;
    }
    $isMod = ord($response[$pos++]);

    if ($isMod === 1) {
      // Mod information
      $info['mod_url_info'] = $this->readString($response, $pos);
      $info['mod_url_dl'] = $this->readString($response, $pos);
      $pos++; // NULL byte

      if ($pos + 8 <= $responseLen) {
        $info['mod_version'] = unpack('V', substr($response, $pos, 4))[1];
        $pos += 4;
        $info['mod_size'] = unpack('V', substr($response, $pos, 4))[1];
        $pos += 4;
      }

      if ($pos >= $responseLen) return $info;
      $info['mod_type'] = ord($response[$pos++]);

      if ($pos >= $responseLen) return $info;
      $info['mod_dll'] = ord($response[$pos++]);
    }

    // Read VAC
    if ($pos >= $responseLen) return $info;
    $info['vac'] = ord($response[$pos++]) === 1 ? 'secured' : 'unsecured';

    // Read bots
    if ($pos >= $responseLen) return $info;
    $info['bots'] = ord($response[$pos++]);

    return $info;
  }

  /**
   * Read null-terminated string from response
   */
  private function readString($data, &$pos)
  {
    $dataLen = strlen($data);
    $str = '';

    while ($pos < $dataLen && $data[$pos] !== "\x00") {
      $str .= $data[$pos++];
    }

    // Skip null terminator if present
    if ($pos < $dataLen && $data[$pos] === "\x00") {
      $pos++;
    }

    return $str;
  }

  /**
   * Close socket
   */
  public function close()
  {
    if ($this->socket) {
      socket_close($this->socket);
      $this->socket = null;
    }
  }

  public function __destruct()
  {
    $this->close();
  }
}
