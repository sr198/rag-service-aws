# Token-based Authentication Design for Multi-tenant RAG Platform

## Background
The RAG platform consists of OpenSearch for vector storage and Bedrock for model access. Multiple tenants access these services through their applications running in Kubernetes clusters. Access needs to be controlled and validated using a token-based approach.

## Current Architecture
- OpenSearch domain in VPC with necessary configurations for vector search
- Bedrock access configured for model invocations
- API Gateway as the entry point for all requests
- Lambda function to handle request routing and role assumption
- Tenant isolation through IAM roles and index patterns

## Authentication Requirements

### Token Validation
1. Token Source:
   - Requests from K8s clusters include a token
   - Token contains tenant_id, environment, and other claims
   - Similar to JWT/OAuth tokens

2. Two-Level Validation:
   - Offline Validation:
     * Public keys available from auth provider
     * Local validation using these keys
     * First line of defense
   - Online Validation:
     * Auth provider endpoint for token validation
     * Checks for recently revoked tokens
     * Second line of defense

### Post-validation Flow
- Extract tenant information from validated token
- Use information for:
  * OpenSearch index access control
  * Bedrock access management
  * Role assumption and request routing

## Proposed Solution

### Components
1. Lambda Authorizer:
   - Separate from main request processing
   - Handles both offline and online token validation
   - Caches validation results
   - Returns IAM policy for API Gateway

2. Auth Provider Integration:
   - Public key endpoint configuration
   - Token validation endpoint configuration
   - Key rotation handling
   - Token revocation checks

3. Request Processing:
   - Use validated token claims
   - Route to appropriate service
   - Enforce access controls

### Security Considerations
- Token expiration and renewal
- Key rotation strategy
- Caching of validation results
- Rate limiting for validation calls
- Audit logging requirements

## Implementation Areas for Discussion
1. Lambda Authorizer configuration
2. Token validation logic and caching
3. Integration with auth provider
4. Error handling and fallbacks
5. Monitoring and logging strategy
6. Performance optimization

## Next Steps
1. Define exact token structure and claims
2. Set up Lambda Authorizer
3. Implement validation logic
4. Configure auth provider integration
5. Update request processing Lambda