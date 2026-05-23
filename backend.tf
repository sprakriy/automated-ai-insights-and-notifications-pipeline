terraform {
    backend "s3" {
    bucket = "sprakriya-tf-state-storage"
    key    = "automation/bedrock_summrizer/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    }
}