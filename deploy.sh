#!/bin/bash

# NFT AI Marketplace Deployment Script

echo "Deploying NFT AI Marketplace..."

# 1. Deploy AWS Infrastructure
echo "Creating AWS resources..."
aws cloudformation deploy \
    --template-file aws/infrastructure.yaml \
    --stack-name nft-ai-marketplace \
    --capabilities CAPABILITY_IAM \
    --region us-east-1

# Get outputs
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name nft-ai-marketplace \
    --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
    --output text)

CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
    --stack-name nft-ai-marketplace \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomain`].OutputValue' \
    --output text)

echo "Bucket: $BUCKET_NAME"
echo "CloudFront: $CLOUDFRONT_DOMAIN"

# 2. Package and deploy Lambda function
echo "Deploying Lambda function..."
cd aws/lambda
zip -r generate-ai-art.zip generate-ai-art.py

aws lambda create-function \
    --function-name generate-ai-art \
    --runtime python3.9 \
    --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/LambdaExecutionRole \
    --handler generate-ai-art.lambda_handler \
    --zip-file fileb://generate-ai-art.zip \
    --timeout 300

# 3. Create API Gateway
aws apigateway create-rest-api --name nft-ai-api

echo "Deployment complete!"
echo "Next steps:"
echo "1. Deploy Clarity contract to Stacks testnet"
echo "2. Update frontend with contract address and API endpoint"
echo "3. Configure Bedrock model access in your AWS account"
