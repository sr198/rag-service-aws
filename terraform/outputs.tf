# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnets
}

# OpenSearch Outputs
output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = aws_opensearch_domain.vector_store.endpoint
}

output "opensearch_domain_name" {
  description = "OpenSearch domain name"
  value       = aws_opensearch_domain.vector_store.domain_name
}

# API Gateway Outputs
output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_stage.api_stage.invoke_url}"
}

output "opensearch_api_endpoint" {
  description = "OpenSearch API endpoint"
  value       = "${aws_api_gateway_stage.api_stage.invoke_url}/opensearch"
}

output "bedrock_api_endpoint" {
  description = "Bedrock API endpoint"
  value       = "${aws_api_gateway_stage.api_stage.invoke_url}/bedrock"
}

# Lambda Outputs
output "authorizer_lambda_arn" {
  description = "ARN of the Authorizer Lambda"
  value       = aws_lambda_function.authorizer.arn
}

output "router_lambda_arn" {
  description = "ARN of the Router Lambda"
  value       = aws_lambda_function.router.arn
}

# Security Group Outputs
output "lambda_security_group_id" {
  description = "ID of Lambda security group"
  value       = aws_security_group.lambda.id
}

output "opensearch_security_group_id" {
  description = "ID of OpenSearch security group"
  value       = aws_security_group.opensearch.id
}

# Service Role Output
output "service_role_arn" {
  description = "ARN of the service IAM role"
  value       = aws_iam_role.service_role.arn
}