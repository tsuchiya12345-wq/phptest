# task-definition.json の awslogs-group (/ecs/phptest-task) と一致させる
resource "aws_cloudwatch_log_group" "ecs" {
  name              = local.log_group_name
  retention_in_days = 14
}
