<?php
declare(strict_types=1);

/**
 * BizPilot AI - Database Configuration & PDO Connection Wrapper
 * Singleton pattern with auto-creation of database and transaction support.
 */

class Database
{
    private static ?Database $instance = null;
    private ?PDO $pdo = null;

    private string $host;
    private int $port;
    private string $dbName;
    private string $username;
    private string $password;
    private string $charset;

    private function __construct()
    {
        $this->host = getenv('DB_HOST') ?: '127.0.0.1';
        $this->port = (int)(getenv('DB_PORT') ?: 3306);
        $this->dbName = getenv('DB_NAME') ?: 'bizpilot_ai';
        $this->username = getenv('DB_USER') ?: 'root';
        $this->password = getenv('DB_PASS') !== false ? getenv('DB_PASS') : '';
        $this->charset = 'utf8mb4';

        $this->connect();
    }

    private function connect(): void
    {
        // 1. Connect without dbname to ensure the database exists
        $serverDsn = sprintf('mysql:host=%s;port=%d;charset=%s', $this->host, $this->port, $this->charset);
        $options = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
            PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES {$this->charset} COLLATE utf8mb4_unicode_ci"
        ];

        try {
            $tempPdo = new PDO($serverDsn, $this->username, $this->password, $options);
            // Create database if it does not exist
            $safeDbName = str_replace('`', '``', $this->dbName);
            $tempPdo->exec("CREATE DATABASE IF NOT EXISTS `{$safeDbName}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
            $tempPdo = null; // Close temporary connection
        } catch (PDOException $e) {
            throw new RuntimeException("Database initialization error: " . $e->getMessage(), (int)$e->getCode(), $e);
        }

        // 2. Connect directly to target database
        $databaseDsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s', $this->host, $this->port, $this->dbName, $this->charset);
        try {
            $this->pdo = new PDO($databaseDsn, $this->username, $this->password, $options);
        } catch (PDOException $e) {
            throw new RuntimeException("Database connection error: " . $e->getMessage(), (int)$e->getCode(), $e);
        }
    }

    public static function getInstance(): Database
    {
        if (self::$instance === null) {
            self::$instance = new Database();
        }
        return self::$instance;
    }

    public static function getConnection(): PDO
    {
        return self::getInstance()->getPdo();
    }

    public function getPdo(): PDO
    {
        if ($this->pdo === null) {
            $this->connect();
        }
        return $this->pdo;
    }

    public function beginTransaction(): bool
    {
        return $this->pdo->beginTransaction();
    }

    public function commit(): bool
    {
        return $this->pdo->commit();
    }

    public function rollBack(): bool
    {
        if ($this->pdo->inTransaction()) {
            return $this->pdo->rollBack();
        }
        return false;
    }

    public function inTransaction(): bool
    {
        return $this->pdo->inTransaction();
    }

    // Prevent cloning and serialization
    private function __clone() {}
    public function __wakeup()
    {
        throw new Exception("Cannot unserialize singleton");
    }
}
