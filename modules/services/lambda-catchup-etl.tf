resource "aws_lambda_function" "catchup_etl" {
  function_name = "${var.deployment_name}-CatchupETL"
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions["CatchupETL"]
  role          = aws_iam_role.default_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  memory_size   = 1024
  timeout       = 900
  architectures = ["arm64"]

  environment {
    variables = {
      ORG_NAME                       = var.braintrust_org_name
      PG_URL                         = local.postgres_url
      REDIS_HOST                     = var.redis_host
      REDIS_PORT                     = var.redis_port
      BRAINSTORE_ENABLED             = var.brainstore_enabled
      BRAINSTORE_URL                 = local.brainstore_url
      BRAINSTORE_REALTIME_WAL_BUCKET = local.brainstore_s3_bucket
    }
  }

  vpc_config {
    subnet_ids         = var.service_subnet_ids
    security_group_ids = var.service_security_group_ids
  }

  tracing_config {
    mode = "PassThrough"
  }
}

resource "aws_cloudwatch_event_rule" "catchup_etl_schedule" {
  name                = "${var.deployment_name}-catchup-etl-schedule"
  description         = "Schedule for Braintrust Catchup ETL Lambda function"
  schedule_expression = "rate(10 minutes)"
}

resource "aws_cloudwatch_event_target" "catchup_etl_target" {
  rule      = aws_cloudwatch_event_rule.catchup_etl_schedule.name
  target_id = "BraintrustCatchupETLFunction"
  arn       = aws_lambda_function.catchup_etl.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.catchup_etl.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.catchup_etl_schedule.arn
}
