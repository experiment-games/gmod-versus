<?php

/**
 * Source Engine Server Query API
 *
 * Provides an HTTP API endpoint for querying Source engine game servers
 * using the A2S protocol over UDP.
 *
 * Usage: ?ip=SERVER_IP&port=SERVER_PORT&type=info|players|rules
 * Example: ?ip=127.0.0.1&port=27015&type=info
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *'); // Allow CORS for GMod HTTP requests

require_once 'source_query.lib.php';
require_once 'config.php';

try {
  // Validate IP access
  $clientIp = $_SERVER['REMOTE_ADDR'];
  if (is_array($accessList) && !in_array($clientIp, $accessList)) {
    throw new Exception("Unauthorized access from IP: $clientIp");
  }

  if (!is_array($accessList) && $accessList !== '*') {
    throw new Exception("Invalid accessList configuration");
  }

  // Validate input
  if (!isset($_GET['ip']) || !isset($_GET['port'])) {
    throw new Exception("Missing required parameters: ip and port");
  }

  $ip = $_GET['ip'];
  $port = $_GET['port'];
  $type = $_GET['type'] ?? 'info';

  // Validate IP
  if (!filter_var($ip, FILTER_VALIDATE_IP)) {
    throw new Exception("Invalid IP address");
  }

  // Validate port
  if (!is_numeric($port) || $port < 1 || $port > 65535) {
    throw new Exception("Invalid port number");
  }

  // Validate query type
  $validTypes = ['info', 'players', 'rules'];
  if (!in_array($type, $validTypes)) {
    throw new Exception("Invalid query type. Must be: info, players, or rules");
  }

  // Create query object
  $query = new SourceQuery($ip, $port);

  // Execute query based on type
  $result = null;
  switch ($type) {
    case 'info':
      $result = $query->getInfo();
      break;
  }

  // Build response
  $response = [
    'success' => true,
    'server' => $ip . ':' . $port,
    'type' => $type,
    'data' => $result
  ];

  // Return success response
  echo json_encode($response, JSON_PRETTY_PRINT);
} catch (Exception $e) {
  // Return error response
  http_response_code(400);

  $errorResponse = [
    'success' => false,
    'error' => $e->getMessage()
  ];

  echo json_encode($errorResponse, JSON_PRETTY_PRINT);
}
