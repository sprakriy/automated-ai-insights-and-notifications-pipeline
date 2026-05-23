provider "aws" {
  region = var.aws_region
}
# S3 bucket to store the Lambda function code
resource "aws_s3_bucket" "input_bucket" {
    bucket = "sp-payload-processing-bucket-1"
    force_destroy = true   
    }
resource "aws_s3_bucket_versioning" "input_bucket_versioning" {
    bucket = aws_s3_bucket.input_bucket.id
    versioning_configuration {
        status = "Enabled"
    }
}
#SNS Notification topic
resource "aws_sns_topic" "sns_topic" {
  name = "bedrock-document-summaries"
}
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
# IAM Execution Role for Lambda function
resource "aws_iam_role" "lambda_role" {
    name = "bedrock-summaries-lambda-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
            Service = "lambda.amazonaws.com"
            }
        }
        ]
    })
    }
#Policy to allow Lambda to read from S3 and publish to SNS
resource "aws_iam_policy" "lambda_policy" {
    name = "bedrock-summaries-lambda-policy"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = [
            "s3:GetObject",
            "s3:GetObjectVersion"
            ]
            Effect = "Allow"
            Resource = "${aws_s3_bucket.input_bucket.arn}/*"
        },
        {
            Action = "sns:Publish"
            Effect = "Allow"
            Resource = aws_sns_topic.sns_topic.arn
        },
        {
            Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
            ]
            Effect = "Allow"
            Resource = "arn:aws:logs:*:*:*"
        },
        {   
            Action = ["bedrock:InvokeModel"]
            Effect = "Allow"
            Resource = [
                "arn:aws:bedrock:*:*:foundation-model/*",
                "arn:aws:bedrock:*:*:inference-profile/*"
            ]    
        }
        ]
    })
}
# Attach the policy to the role 
resource "aws_iam_role_policy_attachment" "lambda_attachment" {
    role = aws_iam_role.lambda_role.name
    policy_arn = aws_iam_policy.lambda_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
    role       = aws_iam_role.lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
# Lambda function to process S3 events and generate summaries using Bedrock
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_file  = "${path.module}/src/lambda_function.py"
    output_path = "${path.module}/lambda_function.zip"
}
resource "aws_lambda_function" "summarizer" {
    function_name = "s3-bedrock-document-summaries"
    role          = aws_iam_role.lambda_role.arn
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.9"
    timeout       = 60 # Give Bedrock enough time to generate summaries for larger documents
    filename      = data.archive_file.lambda_zip.output_path
    source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)
    environment {
        variables = {
            SNS_TOPIC_ARN = aws_sns_topic.sns_topic.arn
        }
    }
}
# Connect S3 event notification to trigger Lambda on new object creation
resource "aws_lambda_permission" "allow_s3" {
    statement_id  = "AllowS3Invoke"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.summarizer.function_name
    principal     = "s3.amazonaws.com"
    source_arn    = aws_s3_bucket.input_bucket.arn
}
resource "aws_s3_bucket_notification" "bucket_notification" {
    bucket = aws_s3_bucket.input_bucket.id
    lambda_function {
        lambda_function_arn = aws_lambda_function.summarizer.arn
        events              = ["s3:ObjectCreated:*"]
    }
    depends_on = [aws_lambda_permission.allow_s3]
}
