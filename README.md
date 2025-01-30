# RAG Service Infrastructure

This repository contains the infrastructure and Lambda functions for the RAG (Retrieval-Augmented Generation) service, which provides secure access to OpenSearch and Bedrock through an API Gateway.

## Architecture

- API Gateway with custom authorizer
- Lambda functions for authorization and request routing
- OpenSearch for vector storage
- Amazon Bedrock for model inference
- VPC with private subnets

## Project Structure

```
rag-service/
├── terraform/           # Infrastructure as code
│   ├── main.tf         # Main infrastructure configuration
│   ├── variables.tf    # Variable definitions
│   ├── outputs.tf      # Output definitions
│   └── src/            # Lambda function source code
│       ├── lambda_layer/
│       ├── authorizer/
│       └── router/
├── tests/              # Test files
├── scripts/            # Deployment and test scripts
└── docs/              # Documentation
```

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Python >= 3.9
- Docker (optional)

## Setup and Deployment

1. Configure AWS credentials:
```bash
aws configure
```

2. Install dependencies:
```bash
# Install Python dependencies
cd terraform/src/lambda_layer/python
pip install -r requirements.txt
```

3. Deploy:
```bash
./scripts/deploy.sh dev us-west-2
```

4. Run tests:
```bash
./scripts/test.sh dev
```

## Environment Variables

- `ENVIRONMENT`: Deployment environment (dev/staging/prod)
- `AWS_REGION`: AWS region for deployment
- `OPENSEARCH_DOMAIN_NAME`: Name for the OpenSearch domain

## Testing

The project includes:
- Integration tests
- Token validation tests
- API endpoint tests

Run tests:
```bash
./scripts/test.sh dev
```

## API Documentation

### OpenSearch Endpoint

POST `/opensearch`
```json
{
    "operation": "index|search",
    "index": "tenant-index-name",
    "documents": [...]
}
```

### Bedrock Endpoint

POST `/bedrock`
```json
{
    "model_id": "anthropic.claude-v2",
    "request": {
        "prompt": "...",
        "max_tokens": 100
    }
}
```

## Security

- Token-based authentication
- Tenant isolation
- VPC security
- Encryption at rest

## Contributing

1. Create a feature branch
2. Make changes
3. Run tests
4. Submit PR

## License

MIT License
