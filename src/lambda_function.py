import os
import json
import boto3
import urllib.parse
from botocore.exceptions import ClientError
def lambda_handler(event, context):
    s3_client = boto3.client('s3')
    bedrock_client = boto3.client('bedrock-runtime', region_name='us-east-1')
    sns_client = boto3.client('sns')
    # Grab our envir variables configured by Terraform
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    # Parse the incoming S3 notification payload
    try:
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        file_key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])
        print(f"New file detected: s3://{bucket_name}/{file_key}")
    except KeyError as e:
        print(f"Error parsing S3 event: {e}")
        return {
            'statusCode': 400,
            'body': json.dumps('Invalid S3 event structure')
        }
    # Read the content of the uploaded file    
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=file_key)   
        document_content = response['Body'].read().decode('utf-8')
        print(f"Document content read successfully from s3://{bucket_name}/{file_key}")
    except ClientError as e:
        print(f"Error downloading file from S3://{bucket_name}/{file_key}: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps('Error reading file from S3')
        }
    system_prompt = "You are an expert infrastructure analyst. Provide a clear bulleted executive summary of the following document."
    # Bedrock Claude 3 model payload specification
    model_payload = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 500,
        "system": system_prompt,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": f"Please summarize this document: {document_content}"
                    }
                ]
            }
        ],
        "temperature":0.2 # Lower temperature for more focused and deterministic output
    }
    # 4. Invoke the Bedrock model to generate a summary
    # Using Claude 4.6 for better performance and understanding of complex documents
    model_id = "global.anthropic.claude-sonnet-4-20250514-v1:0"
    try:
        print(f"Invoking Bedrock model {model_id} for summarization...")
        response = bedrock_client.invoke_model(modelId=model_id, body=json.dumps(model_payload))
        # Parse the raw dynamic response from Bedrock
        response_body = json.loads(response['body'].read())
        print(f" Inference successful. Summary compiled.")
        # Fix 3: Safely extract the generated string from Anthropic's response model
        summary_text = response_body['content'][0]['text']
    except ClientError as e:
        print(f"Error invoking Bedrock model: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps('Error invoking Bedrock model')
        }
    email_subject = f"Summary of Document: {file_key}"
    email_body = f"Automated AI summary for s3://{bucket_name}/{file_key}\n\n"
    email_body += "============================="
    email_body += summary_text + "\n"
    email_body += "=============================\n"
    try:
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=email_subject,
            Message=email_body
        )
        print(f"Summary sent successfully to SNS topic: {sns_topic_arn}")
    except ClientError as e:
        print(f"Error publishing summary to SNS: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps('Error sending summary to SNS')
        }
    return {
        'statusCode': 200,
        'body': json.dumps('Summary generated and sent successfully')
    }