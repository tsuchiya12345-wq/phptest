output "alb_dns_name" {
  description = "アプリにアクセスする ALB の DNS 名"
  value       = aws_lb.this.dns_name
}

output "ecr_base_repository_url" {
  description = "ベースイメージの ECR リポジトリ URI"
  value       = aws_ecr_repository.base.repository_url
}

output "ecr_app_repository_url" {
  description = "アプリイメージの ECR リポジトリ URI"
  value       = aws_ecr_repository.app.repository_url
}

output "github_actions_role_arn" {
  description = "GitHub Secrets の AWS_ROLE_ARN に設定する値"
  value       = aws_iam_role.github_actions.arn
}

output "aws_account_id" {
  description = "AWS アカウント ID"
  value       = data.aws_caller_identity.current.account_id
}

# --- GitHub Actions に設定する Variables 一覧 ---
output "github_variables" {
  description = "GitHub の Repository variables に設定する値"
  value = {
    AWS_REGION      = var.aws_region
    ECR_BASE_REPO   = aws_ecr_repository.base.name
    ECR_APP_REPO    = aws_ecr_repository.app.name
    ECS_CLUSTER     = aws_ecs_cluster.this.name
    ECS_SERVICE     = aws_ecs_service.this.name
    ECS_TASK_FAMILY = aws_ecs_task_definition.this.family
    CONTAINER_NAME  = var.container_name
  }
}
