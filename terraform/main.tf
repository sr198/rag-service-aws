terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "terraform-state-bucket"  # Replace with your state bucket
    key            = "service-state/terraform.tfstate"
    region         = "us-west-2"  
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Configuration
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "rag-service-vpc-${var.environment}"
  cidr = var.vpc_cidr
  
  azs             = var.availability_zones
  private_subnets = var.private_subnets_cidr
  
  enable_nat_gateway = false
  enable_vpn_gateway = false
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Environment = var.environment
    Service     = "rag-platform"
  }
}

# Security Groups
resource "aws_security_group" "opensearch" {
  name        = "opensearch-${var.environment}"
  description = "Security group for OpenSearch domain"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Service     = "rag-platform"
  }
}

resource "aws_security_group" "lambda" {
  name        = "lambda-${var.environment}"
  description = "Security group for Lambda functions"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Service     = "rag-platform"
  }
}

# OpenSearch Domain
resource "aws_opensearch_domain" "vector_store" {
  domain_name    = var.opensearch_domain_name
  engine_version = "OpenSearch_2.9"

  cluster_config {
    instance_type            = var.opensearch_instance_type
    instance_count          = var.opensearch_instance_count
    zone_awareness_enabled  = true
    
    zone_awareness_config {
      availability_zone_count = 2
    }
  }

  vpc_options {
    subnet_ids         = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 100
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.opensearch_master_user
      master_user_password = var.opensearch_master_password
    }
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
    "indices.query.bool.max_clause_count"    = "8192"
    "knn.algo_param.ef_search"              = "512"
    "knn.algo_param.ef_construction"        = "512"
    "knn.algo_param.m"                      = "16"
    "knn.memory.circuit_breaker.enabled"    = "true"
    "knn.memory.circuit_breaker.limit"      = "60"
  }

  tags = {
    Environment = var.environment
    Service     = "rag-platform"
  }
}

# Lambda Layer
data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/src/lambda_layer/python"
  output_path = "${path.module}/dist/lambda_layer.zip"
}

resource "aws_lambda_layer_version" "dependencies" {
  filename            = data.archive_file.lambda_layer.output_path
  layer_name          = "rag-dependencies-${var.environment}"
  description         = "Dependencies for RAG service Lambda functions"
  compatible_runtimes = ["python3.9"]
}

# Service Role for Lambda Functions
resource "aws_iam_role" "service_role" {
  name = "rag-service-role-${var.environment}"

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

  tags = {
    Environment = var.environment
    Service     = "rag-platform"
  }
}

# Service Role Policies
resource "aws_iam_role_policy" "opensearch_access" {
  name = "opensearch-access"
  role = aws_iam_role.service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "es:ESHttp*"
      ]
      Resource = [
        aws_opensearch_domain.vector_store.arn,
        "${aws_opensearch_domain.vector_store.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_access" {
  name = "bedrock-access"
  role = aws_iam_role.service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel"
      ]
      Resource = [
        "arn:aws:bedrock:${var.aws_region}::foundation-model/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambdas
data "archive_file" "authorizer_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src/authorizer"
  output_path = "${path.module}/dist/authorizer.zip"
}

data "archive_file" "router_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src/router"
  output_path = "${path.module}/dist/router.zip"
}

resource "aws_lambda_function" "authorizer" {
  filename         = data.archive_file.authorizer_lambda.output_path
  function_name    = "rag-authorizer-${var.environment}"
  role            = aws_iam_role.service_role.arn
  handler         = "main.lambda_handler"
  runtime         = "python3.9"
  timeout         = 29
  memory_size     = 256

  layers = [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = {
      ENVIRONMENT = var.environment
      BYPASS_AUTH = var.environment == "test" ? "true" : "false"
      TEST_TOKEN = var.environment == "test" ? "integration-test-token" : ""
      TEST_TENANT_ID = var.environment == "test" ? "test-tenant" : ""
    }
  }

  tags = {
    Environment = var.environment
    Service     = "rag-platform"
  }
}

resource "aws_lambda_function" "router" {
  filename         = data.archive_file.router_lambda.output_path
  function_name    = "rag-router-${var.environment}"
  role            = aws_iam_role.service_role.arn
  handler         = "main.lambda_handler"
  runtime         = "python3.9"
  timeout         = 29
  memory_size     = 256

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }

  layers = [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = {
      ENVIRONMENT = var.environment
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.vector_store.endpoint
      AWS_REGION = var.aws_region
    }
  }

  tags = {
    Environment = var.environment
    Service     = "rag-platform"
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "rag_api" {
  name = "rag-api-${var.environment}"
  description = "RAG Service API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Environment = var.environment
    Service     = "rag-platform"
  }
}

# Authorizer
resource "aws_api_gateway_authorizer" "token_authorizer" {
  name                             = "token-authorizer-${var.environment}"
  rest_api_id                      = aws_api_gateway_rest_api.rag_api.id
  type                            = "TOKEN"
  authorizer_uri                   = aws_lambda_function.authorizer.invoke_arn
  authorizer_credentials           = aws_iam_role.service_role.arn
  identity_source                  = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 300
}

# API Resources and Methods
resource "aws_api_gateway_resource" "opensearch" {
  rest_api_id = aws_api_gateway_rest_api.rag_api.id
  parent_id   = aws_api_gateway_rest_api.rag_api.root_resource_id
  path_part   = "opensearch"
}

resource "aws_api_gateway_resource" "bedrock" {
  rest_api_id = aws_api_gateway_rest_api.rag_api.id
  parent_id   = aws_api_gateway_rest_api.rag_api.root_resource_id
  path_part   = "bedrock"
}

# Methods
resource "aws_api_gateway_method" "opensearch_post" {
  rest_api_id   = aws_api_gateway_rest_api.rag_api.id
  resource_id   = aws_api_gateway_resource.opensearch.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.token_authorizer.id

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "opensearch_integration" {
  rest_api_id = aws_api_gateway_rest_api.rag_api.id
  resource_id = aws_api_gateway_resource.opensearch.id
  http_method = aws_api_gateway_method.opensearch_post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.router.invoke_arn
}

resource "aws_api_gateway_method" "bedrock_post" {
  rest_api_id   = aws_api_gateway_rest_api.rag_api.id
  resource_id   = aws_api_gateway_resource.bedrock.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.token_authorizer.id

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "bedrock_integration" {
  rest_api_id = aws_api_gateway_rest_api.rag_api.id
  resource_id = aws_api_gateway_resource.bedrock.id
  http_method = aws_api_gateway_method.bedrock_post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.router.invoke_arn
}

# Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rag_api.id
  
  depends_on = [
    aws_api_gateway_integration.opensearch_integration,
    aws_api_gateway_integration.bedrock_integration
  ]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.opensearch.id,
      aws_api_gateway_resource.bedrock.id,
      aws_api_gateway_method.opensearch_post.id,
      aws_api_gateway_method.bedrock_post.id,
      aws_api_gateway_integration.opensearch_integration.id,
      aws_api_gateway_integration.bedrock_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id  = aws_api_gateway_rest_api.rag_api.id
  stage_name   = var.environment
}