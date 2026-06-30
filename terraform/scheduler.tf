# 本番デプロイのトリガー基盤。
# EventBridge Scheduler は API Destination を直接ターゲットにできないため、
#   Scheduler(ワンタイム予約) -> PutEvents(custom bus)
#     -> EventBridge ルール(event pattern 一致)
#       -> API Destination(GitHub /dispatches)
# の連鎖で GitHub の repository_dispatch(production-deploy) を発火させる。
#
# 静的部分(bus / connection / api destination / rule / 各ロール)を Terraform で作成し、
# ワンタイム予約(schedule)だけ release-deploy.yml が動的に作成する。

# --- イベントを受けるカスタムバス ---
resource "aws_cloudwatch_event_bus" "deploy" {
  name = local.event_bus_name
}

# --- GitHub API 用の Connection (認可ヘッダを保管) ---
resource "aws_cloudwatch_event_connection" "github" {
  name               = "${var.project}-github-dispatch"
  description        = "GitHub repository_dispatch 用の認可情報"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      # GitHub の Authorization ヘッダ (Bearer トークン)
      key   = "Authorization"
      value = "Bearer ${var.github_dispatch_token}"
    }

    invocation_http_parameters {
      header {
        key             = "Accept"
        value           = "application/vnd.github+json"
        is_value_secret = false
      }
      # GitHub API は User-Agent ヘッダを要求する
      header {
        key             = "User-Agent"
        value           = "${var.project}-eventbridge"
        is_value_secret = false
      }
    }
  }
}

# --- GitHub /dispatches を叩く API Destination ---
resource "aws_cloudwatch_event_api_destination" "github" {
  name                             = "${var.project}-github-dispatch"
  description                      = "GitHub repository_dispatch エンドポイント"
  invocation_endpoint              = "https://api.github.com/repos/${var.github_repo}/dispatches"
  http_method                      = "POST"
  invocation_rate_limit_per_second = 1
  connection_arn                   = aws_cloudwatch_event_connection.github.arn
}

# --- カスタムバス上で production-deploy イベントを拾うルール ---
resource "aws_cloudwatch_event_rule" "prod_deploy" {
  name           = "${var.project}-prod-deploy"
  description    = "Scheduler からの production-deploy イベントを GitHub へ転送"
  event_bus_name = aws_cloudwatch_event_bus.deploy.name

  event_pattern = jsonencode({
    source        = [local.event_source]
    "detail-type" = [local.event_detail_type]
  })
}

# --- ルールのターゲット: API Destination へ転送し、GitHub dispatch のボディへ変換 ---
resource "aws_cloudwatch_event_target" "prod_deploy" {
  rule           = aws_cloudwatch_event_rule.prod_deploy.name
  event_bus_name = aws_cloudwatch_event_bus.deploy.name
  arn            = aws_cloudwatch_event_api_destination.github.arn
  role_arn       = aws_iam_role.eventbridge_invoke.arn

  input_transformer {
    input_paths = {
      image_tag = "$.detail.image_tag"
    }
    # GitHub /dispatches のリクエストボディ。
    # image_tag は文字列のため、JSON として有効にするため明示的に引用符で囲む。
    input_template = <<EOF
{"event_type":"${local.event_detail_type}","client_payload":{"image_tag":"<image_tag>"}}
EOF
  }
}

# --- EventBridge ルールが API Destination を起動するためのロール ---
data "aws_iam_policy_document" "eventbridge_invoke_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_invoke" {
  name               = "${var.project}-eventbridge-invoke-role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_invoke_assume.json
}

data "aws_iam_policy_document" "eventbridge_invoke" {
  statement {
    sid       = "InvokeApiDestination"
    actions   = ["events:InvokeApiDestination"]
    resources = [aws_cloudwatch_event_api_destination.github.arn]
  }
}

resource "aws_iam_role_policy" "eventbridge_invoke" {
  name   = "${var.project}-eventbridge-invoke-policy"
  role   = aws_iam_role.eventbridge_invoke.id
  policy = data.aws_iam_policy_document.eventbridge_invoke.json
}

# --- EventBridge Scheduler が PutEvents するためのロール (GHA が schedule の RoleArn に指定) ---
data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${var.project}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    sid       = "PutEvents"
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.deploy.arn]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "${var.project}-scheduler-policy"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}
