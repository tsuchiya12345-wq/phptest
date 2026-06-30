# 本番(production)環境。既存の単一サービス(ecs.tf)はステージング扱いとし、
# 本番は別サービス/タスク定義/ロググループ/ターゲットグループ/リスナーとして分離する。

resource "aws_cloudwatch_log_group" "ecs_prod" {
  name              = local.prod_log_group_name
  retention_in_days = 14
}

# 初期タスク定義。実イメージは CI (production-deploy.yml) が
# .aws/task-definition.prod.json から新リビジョンを登録して差し替える。
resource "aws_ecs_task_definition" "prod" {
  family                   = local.prod_task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.bootstrap_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_prod.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "web"
        }
      }
    }
  ])
}

# 本番用ターゲットグループ。ステージングと同じ ALB に別リスナーでぶら下げる。
resource "aws_lb_target_group" "prod" {
  name        = "${var.project}-prod-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# 本番は別ポート(既定 8080)のリスナーで公開する。
resource "aws_lb_listener" "prod" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.prod_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod.arn
  }
}

# ALB SG に本番リスナーのポートを許可する ingress を追加。
resource "aws_security_group_rule" "alb_prod_ingress" {
  type              = "ingress"
  description       = "HTTP (production listener)"
  from_port         = var.prod_listener_port
  to_port           = var.prod_listener_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_ecs_service" "prod" {
  name            = local.prod_service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.prod.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prod.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.prod]

  # 継続デプロイは CI が担うため、task_definition / desired_count の
  # ドリフトは無視して Terraform と CI の衝突を避ける。
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
