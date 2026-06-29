<?php

declare(strict_types=1);

/**
 * 画面ごとのロジックをまとめるコントローラの雛形。
 *
 * 例として、メッセージ一覧の取得処理を切り出している。
 * index.php から利用する形に発展させることを想定。
 */
final class HomeController
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function latestMessages(int $limit = 20): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT id, body, created_at FROM messages ORDER BY id DESC LIMIT :limit'
        );
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll();
    }
}
