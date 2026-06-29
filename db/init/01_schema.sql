-- MySQLコンテナ初回起動時に自動実行される初期スキーマ

CREATE TABLE IF NOT EXISTS messages (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    body VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO messages (body) VALUES
    ('ようこそ！PHP + Apache のサンプルアプリです。'),
    ('このメッセージはMySQLから取得しています。');
