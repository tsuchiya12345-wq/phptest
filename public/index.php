<?php

declare(strict_types=1);

require __DIR__ . '/../src/Config/database.php';

$dbStatus = 'unknown';
$messages = [];

try {
    $pdo = createPdoConnection();

    $stmt = $pdo->query('SELECT id, body, created_at FROM messages ORDER BY id DESC LIMIT 20');
    $messages = $stmt->fetchAll();

    $dbStatus = 'connected';
} catch (Throwable $e) {
    $dbStatus = 'error: ' . $e->getMessage();
}

require __DIR__ . '/../src/Views/home.php';
