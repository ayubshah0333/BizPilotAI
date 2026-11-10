<?php
declare(strict_types=1);

/**
 * BizPilot AI - API Response & Request Utility Helpers
 */

function setupCors(): void
{
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
    header("Content-Type: application/json; charset=UTF-8");

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit(0);
    }
}

function jsonSuccess(mixed $data = null, string $message = 'Success', int $statusCode = 200): void
{
    http_response_code($statusCode);
    echo json_encode([
        'success' => true,
        'message' => $message,
        'data'    => $data
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit(0);
}

function jsonError(string $message = 'An error occurred', int $statusCode = 400, mixed $errors = null): void
{
    http_response_code($statusCode);
    $response = [
        'success' => false,
        'message' => $message
    ];
    if ($errors !== null) {
        $response['errors'] = $errors;
    }
    echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit(0);
}

function getRequestData(): array
{
    $input = file_get_contents('php://input');
    $jsonData = [];
    if (!empty($input)) {
        $decoded = json_decode($input, true);
        if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
            $jsonData = $decoded;
        }
    }
    // Merge json payload, $_POST, and $_GET
    return array_merge($_GET, $_POST, $jsonData);
}

function sanitizeString(?string $str): string
{
    if ($str === null) {
        return '';
    }
    return trim(htmlspecialchars($str, ENT_QUOTES, 'UTF-8'));
}
