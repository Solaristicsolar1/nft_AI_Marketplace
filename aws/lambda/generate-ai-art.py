import json
import boto3
import base64
import uuid
from datetime import datetime

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
s3 = boto3.client('s3')
rekognition = boto3.client('rekognition')

BUCKET_NAME = 'nft-ai-assets-{account-id}'  # Replace with actual bucket

def lambda_handler(event, context):
    try:
        # Parse request
        body = json.loads(event['body']) if isinstance(event.get('body'), str) else event
        prompt = body.get('prompt', 'Abstract digital art')
        style = body.get('style', 'digital art')
        
        # Generate image with Bedrock Stable Diffusion
        full_prompt = f"{prompt}, {style}, high quality, detailed, NFT art"
        
        request_body = {
            "text_prompts": [{"text": full_prompt}],
            "cfg_scale": 10,
            "seed": 0,
            "steps": 50,
            "width": 512,
            "height": 512
        }
        
        response = bedrock.invoke_model(
            modelId='stability.stable-diffusion-xl-v1',
            body=json.dumps(request_body)
        )
        
        # Parse response and extract image
        response_body = json.loads(response['body'].read())
        image_data = base64.b64decode(response_body['artifacts'][0]['base64'])
        
        # Generate unique filename
        image_id = str(uuid.uuid4())
        image_key = f"generated-art/{image_id}.png"
        
        # Upload to S3
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=image_key,
            Body=image_data,
            ContentType='image/png'
        )
        
        # Analyze image with Rekognition
        rekognition_response = rekognition.detect_labels(
            Image={'S3Object': {'Bucket': BUCKET_NAME, 'Name': image_key}},
            MaxLabels=10
        )
        
        labels = [label['Name'] for label in rekognition_response['Labels']]
        
        # Create metadata
        metadata = {
            "id": image_id,
            "prompt": prompt,
            "style": style,
            "image_url": f"https://{BUCKET_NAME}.s3.amazonaws.com/{image_key}",
            "labels": labels,
            "created_at": datetime.utcnow().isoformat(),
            "attributes": {
                "AI_Generated": True,
                "Model": "Stable Diffusion XL",
                "Style": style
            }
        }
        
        # Store metadata
        metadata_key = f"metadata/{image_id}.json"
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=metadata_key,
            Body=json.dumps(metadata),
            ContentType='application/json'
        )
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(metadata)
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
