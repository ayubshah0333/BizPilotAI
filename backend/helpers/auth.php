<?php
declare(strict_types=1);

/**
 * BizPilot AI - Authentication & Authorization Helpers
 */

require_once __DIR__ . '/response.php';

function getBearerToken(): ?string
{
    $headers = null;
    if (isset($_SERVER['Authorization'])) {
        $headers = trim($_SERVER['Authorization']);
    } elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $headers = trim($_SERVER['HTTP_AUTHORIZATION']);
    } elseif (function_exists('apache_request_headers')) {
        $requestHeaders = apache_request_headers();
        // Server-side fix for bug in old Android versions where Authorization header wasn't capitalized
        $requestHeaders = array_combine(
            array_map('ucwords', array_keys($requestHeaders)),
            array_values($requestHeaders)
        );
        if (isset($requestHeaders['Authorization'])) {
            $headers = trim($requestHeaders['Authorization']);
        }
    }

    // Direct query parameter fallback for token (e.g., download / export / testing)
    if (empty($headers) && !empty($_GET['token'])) {
        return trim((string)$_GET['token']);
    }

    if (!empty($headers)) {
        if (preg_match('/Bearer\s(\S+)/', $headers, $matches)) {
            return $matches[1];
        }
    }

    return null;
}

function authenticateUser(PDO $pdo): array
{
    $token = getBearerToken();
    if (!$token) {
        jsonError('Missing API Authorization Bearer token.', 401);
    }

    $stmt = $pdo->prepare("
        SELECT u.id, u.business_id, u.name, u.email, u.role, u.api_token, u.created_at,
               b.name AS business_name, b.owner_name, b.phone AS business_phone, b.currency, b.address AS business_address
        FROM users u
        INNER JOIN businesses b ON u.business_id = b.id
        WHERE u.api_token = :token
        LIMIT 1
    ");
    $stmt->execute(['token' => $token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        jsonError('Invalid or expired API token.', 401);
    }

    return $user;
}

function generateApiToken(): string
{
    return bin2hex(random_bytes(32)); // 64 hex characters
}
