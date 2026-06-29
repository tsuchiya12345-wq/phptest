<?php
/** @var string $dbStatus */
/** @var array<int, array<string, mixed>> $messages */
$isConnected = $dbStatus === 'connected';
?>
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PHP + Apache App</title>
    <link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
    <div class="container">
        <h1>PHP + Apache アプリ</h1>
        <p>
            DB接続状態:
            <span class="status <?= $isConnected ? 'ok' : 'ng' ?>">
                <?= htmlspecialchars($dbStatus, ENT_QUOTES, 'UTF-8') ?>
            </span>
        </p>

        <div class="card">
            <h2>最新メッセージ</h2>
            <?php if ($isConnected && count($messages) > 0): ?>
                <ul class="messages">
                    <?php foreach ($messages as $row): ?>
                        <li>
                            <?= htmlspecialchars((string) $row['body'], ENT_QUOTES, 'UTF-8') ?>
                            <span class="time">
                                <?= htmlspecialchars((string) $row['created_at'], ENT_QUOTES, 'UTF-8') ?>
                            </span>
                        </li>
                    <?php endforeach; ?>
                </ul>
            <?php elseif ($isConnected): ?>
                <p>まだメッセージがありません。</p>
            <?php else: ?>
                <p>データベースに接続できませんでした。<code>docker compose up -d</code> でDBが起動しているか確認してください。</p>
            <?php endif; ?>
        </div>
    </div>
    <h1>10:50テスト</h1>
    <script src="/assets/js/app.js"></script>
</body>
</html>
