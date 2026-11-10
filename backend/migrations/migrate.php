<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';

try {
    echo "[MIGRATE] Connecting to database...\n";
    $pdo = Database::getConnection();

    echo "[MIGRATE] Reading schema.sql...\n";
    $sql = file_get_contents(__DIR__ . '/schema.sql');
    if ($sql === false) {
        throw new RuntimeException("Failed to read schema.sql");
    }

    // Split and execute statements
    $pdo->exec($sql);
    echo "[MIGRATE] Schema migrated successfully!\n";

    // Show created tables
    $stmt = $pdo->query("SHOW TABLES");
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    echo "[MIGRATE] Verified tables in database (" . count($tables) . "):\n";
    foreach ($tables as $table) {
        echo "  - {$table}\n";
    }

} catch (Throwable $e) {
    echo "[MIGRATE ERROR] " . $e->getMessage() . "\n";
    exit(1);
}
