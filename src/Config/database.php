<?php

declare(strict_types=1);

/**
 * 環境変数からPDO(MySQL)接続を生成して返す。
 *
 * compose の environment で渡された DB_* を参照する。
 * DBホスト名は compose のサービス名 "db"。
 */
function createPdoConnection(): PDO
{
    $host = getenv('DB_HOST') ?: 'db';
    $port = getenv('DB_PORT') ?: '3306';
    $database = getenv('DB_DATABASE') ?: 'app';
    $username = getenv('DB_USERNAME') ?: 'app';
    $password = getenv('DB_PASSWORD') ?: 'secret';

    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $host,
        $port,
        $database
    );

    $options = [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ];

    return new PDO($dsn, $username, $password, $options);
}
