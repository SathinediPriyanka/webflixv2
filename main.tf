# Defining provider and region
provider "aws" {
  region = "us-east-1"
}

# Random suffix for bucket names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Buckets
resource "aws_s3_bucket" "uploads_bucket" {
  bucket = "video-platform-uploads-${random_string.suffix.result}"
}

resource "aws_s3_bucket" "csv_bucket" {
  bucket = "video-platform-csv-${random_string.suffix.result}"
}

resource "aws_s3_bucket" "raw_feeds_bucket" {
  bucket = "video-platform-feeds-${random_string.suffix.result}"
}

#S3 Bucket Allow Public Access Block
resource "aws_s3_bucket_public_access_block" "uploads_block" {
  bucket = aws_s3_bucket.uploads_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "csv_block" {
  bucket = aws_s3_bucket.csv_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "feeds_block" {
  bucket = aws_s3_bucket.raw_feeds_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#S3 Bucket Policies
resource "aws_s3_bucket_policy" "uploads_bucket_public_policy" {
  bucket = aws_s3_bucket.uploads_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPublicReadForAssets",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.uploads_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "csv_bucket_public_policy" {
  bucket = aws_s3_bucket.csv_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPublicReadForCSVFiles",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.csv_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "raw_feeds_bucket_public_policy" {
  bucket = aws_s3_bucket.raw_feeds_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPublicReadForFeeds",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.raw_feeds_bucket.arn}/*"
      }
    ]
  })
}

# RDS MySQL Instance
resource "aws_db_instance" "metadata_db" {
  identifier           = "video-platform-db"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "admin"
  password            = random_password.db_password.result
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

# Random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# Security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "video-platform-rds-sg"
  description = "Allow Lambda access to RDS"
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "video-platform-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda IAM policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "video-platform-lambda-policy"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:getObjectTagging"
        ]
        Resource = [
          "${aws_s3_bucket.uploads_bucket.arn}/*",
          "${aws_s3_bucket.csv_bucket.arn}/*",
          "${aws_s3_bucket.raw_feeds_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = aws_db_instance.metadata_db.arn
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:DeleteRule",
          "events:RemoveTargets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Functions
resource "aws_lambda_function" "csv_parser" {
  function_name = "video-platform-csv-parser"
  handler       = "csv_parser.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  filename      = "csv_parser.zip"
  environment {
    variables = {
      RDS_HOST   = aws_db_instance.metadata_db.endpoint
      RDS_PASSWORD = random_password.db_password.result
      MUX_TOKEN  = var.mux_token
      MUX_SECRET = var.mux_secret
    }
  }
}

resource "aws_lambda_function" "upload_listener" {
  function_name = "video-platform-upload-listener"
  handler       = "upload_listener.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  filename      = "upload_listener.zip"
  environment {
    variables = {
      RDS_HOST   = aws_db_instance.metadata_db.endpoint
      RDS_PASSWORD = random_password.db_password.result
      MUX_TOKEN  = var.mux_token
      MUX_SECRET = var.mux_secret
    }
  }
}

resource "aws_lambda_function" "mrss_poller" {
  function_name = "video-platform-mrss-poller"
  handler       = "mrss_poller.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  filename      = "mrss_poller.zip"
  environment {
    variables = {
      RDS_HOST   = aws_db_instance.metadata_db.endpoint
      RDS_PASSWORD = random_password.db_password.result
      MUX_TOKEN  = var.mux_token
      MUX_SECRET = var.mux_secret
    }
  }
}

resource "aws_lambda_function" "mux_submitter" {
  function_name = "video-platform-mux-submitter"
  handler       = "mux_submitter.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  filename      = "mux_submitter.zip"
  environment {
    variables = {
      RDS_HOST   = aws_db_instance.metadata_db.endpoint
      RDS_PASSWORD = random_password.db_password.result
      MUX_TOKEN  = var.mux_token
      MUX_SECRET = var.mux_secret
    }
  }
}

resource "aws_lambda_function" "webhook_listener" {
  function_name = "video-platform-webhook-listener"
  handler       = "webhook_listener.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  filename      = "webhook_listener.zip"
  environment {
    variables = {
      RDS_HOST   = aws_db_instance.metadata_db.endpoint
      RDS_PASSWORD = random_password.db_password.result
    }
  }
}

# Lambda Permissions for S3 Notifications
resource "aws_lambda_permission" "s3_csv_trigger" {
  statement_id  = "AllowS3InvokeCSVParser"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_parser.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.csv_bucket.arn
}

resource "aws_lambda_permission" "s3_upload_trigger" {
  statement_id  = "AllowS3InvokeUploadListener"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_listener.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads_bucket.arn
}

# S3 Event Notifications
resource "aws_s3_bucket_notification" "csv_notification" {
  bucket = aws_s3_bucket.csv_bucket.id
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.csv_parser.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.s3_csv_trigger,
    aws_lambda_function.csv_parser
  ]

}

resource "aws_s3_bucket_notification" "upload_notification" {
  bucket = aws_s3_bucket.uploads_bucket.id
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.upload_listener.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [
    aws_lambda_function.upload_listener,
    aws_lambda_permission.s3_upload_trigger
  ]
}

# API Gateway for Webhook
resource "aws_api_gateway_rest_api" "webhook_api" {
  name = "video-platform-webhook"
}

resource "aws_api_gateway_resource" "webhook_resource" {
  rest_api_id = aws_api_gateway_rest_api.webhook_api.id
  parent_id   = aws_api_gateway_rest_api.webhook_api.root_resource_id
  path_part   = "webhook"
}

resource "aws_api_gateway_method" "webhook_method" {
  rest_api_id   = aws_api_gateway_rest_api.webhook_api.id
  resource_id   = aws_api_gateway_resource.webhook_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "webhook_integration" {
  rest_api_id             = aws_api_gateway_rest_api.webhook_api.id
  resource_id             = aws_api_gateway_resource.webhook_resource.id
  http_method            = aws_api_gateway_method.webhook_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.webhook_listener.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_listener.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.webhook_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "webhook_deployment" {
  rest_api_id = aws_api_gateway_rest_api.webhook_api.id

  depends_on = [
    aws_api_gateway_integration.webhook_integration
  ]
}

# API Gateway Stage (this actually creates the stage)
resource "aws_api_gateway_stage" "webhook_stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.webhook_api.id
  deployment_id = aws_api_gateway_deployment.webhook_deployment.id
}

# Variables
variable "mux_token" {
  type = string
}

variable "mux_secret" {
  type = string
}

variable "region" {
  default = "us-east-1"
}

# Outputs
output "webhook_url" {
  value = "https://${aws_api_gateway_rest_api.webhook_api.id}.execute-api.${var.region}.amazonaws.com/dev/webhook"
}

output "rds_endpoint" {
  value = aws_db_instance.metadata_db.endpoint
}

output "uploads_bucket" {
  value = aws_s3_bucket.uploads_bucket.bucket
}

output "csv_bucket" {
  value = aws_s3_bucket.csv_bucket.bucket
}