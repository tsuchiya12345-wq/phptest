variable "aws_region" {
  description = "リソースを作成する AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "リソース名のプレフィックスに使うプロジェクト名"
  type        = string
  default     = "phptest"
}

variable "github_repo" {
  description = "OIDC で信頼する GitHub リポジトリ (owner/repo)"
  type        = string
  default     = "tsuchiya12345-wq/phptest"
}

variable "container_name" {
  description = "タスク定義内のコンテナ名 (CI の CONTAINER_NAME と一致させる)"
  type        = string
  default     = "phptest-web"
}

variable "container_port" {
  description = "コンテナの公開ポート"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate タスクの CPU ユニット"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate タスクのメモリ (MiB)"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "ECS サービスの希望タスク数"
  type        = number
  default     = 1
}

variable "bootstrap_image" {
  description = "初回 apply 用のプレースホルダイメージ (CI が実イメージへ差し替える)"
  type        = string
  default     = "public.ecr.aws/docker/library/httpd:2.4"
}

variable "prod_listener_port" {
  description = "本番サービスを公開する ALB リスナーのポート (ステージングは 80)"
  type        = number
  default     = 8080
}

variable "github_dispatch_token" {
  description = "EventBridge から GitHub の repository_dispatch を叩くためのトークン (repo / contents 権限)。EventBridge Connection に保管される"
  type        = string
  sensitive   = true
}
