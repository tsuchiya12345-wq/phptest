data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# デフォルト VPC とそのサブネットを利用する
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  ecr_base_repo  = "${var.project}-base"
  ecr_app_repo   = "${var.project}-app"
  cluster_name   = "${var.project}-cluster"
  service_name   = "${var.project}-service"
  task_family    = "${var.project}-task"
  log_group_name = "/ecs/${var.project}-task"
}
