resource "aws_iam_role" "brainstore_ec2_role" {
  name = "${var.deployment_name}-brainstore-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.deployment_name}-brainstore-ec2-role"
  }
}

resource "aws_iam_role_policy" "brainstore_s3_access" {
  name = "brainstore-s3-bucket"
  role = aws_iam_role.brainstore_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:Get*",
          "s3:PutObject*",
          "s3:List*",
          "s3:DeleteObject*"
        ]
        Resource = [
          aws_s3_bucket.brainstore.arn,
          "${aws_s3_bucket.brainstore.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "brainstore_secrets_access" {
  name = "secrets-access"
  role = aws_iam_role.brainstore_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.database_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "brainstore_cloudwatch_logs_access" {
  name = "cloudwatch-logs-access"
  role = aws_iam_role.brainstore_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/brainstore:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/brainstore/*:*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "brainstore" {
  name = "${var.deployment_name}-brainstore-instance-profile"
  role = aws_iam_role.brainstore_ec2_role.name
}
