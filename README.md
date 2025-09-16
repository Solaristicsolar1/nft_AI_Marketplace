# NFT Marketplace with AI-Generated Art

## Architecture
- **Blockchain**: Stacks (Clarity smart contracts)
- **AI Generation**: Amazon Bedrock (Stable Diffusion)
- **Storage**: AWS S3 for metadata and assets
- **CDN**: CloudFront for global delivery
- **Image Analysis**: Amazon Rekognition

## Components
1. Clarity smart contract for NFT minting/trading
2. AWS Lambda functions for AI generation
3. Frontend for marketplace interaction
4. S3 bucket structure for assets and metadata

## Setup Instructions
1. Deploy Clarity contract to Stacks testnet
2. Configure AWS services (S3, Lambda, Bedrock)
3. Set up CloudFront distribution
4. Deploy frontend application
