# AI Platform Infrastructure Automation Design Specification

## Purpose
Infrastructure automation to support Retrieval Augmented Generation (RAG) based AI solutions:
- OpenSearch: Vector database for storing and searching embeddings
- Bedrock: Access to Claude 3 models for:
  * Text generation
  * Embedding generation
  * RAG-based responses
- Multi-tenant architecture allowing isolated access to shared infrastructure

## Solution Architecture
1. Service Level (Shared Infrastructure):
   - OpenSearch cluster optimized for vector search
   - Secure network infrastructure
   - Core service management roles

2. Tenant Level:
   - Isolated access to shared resources
   - Tenant-specific vector indices
   - Dedicated IAM roles for workload identity

[Previous sections remain same until Testing Strategy]

## Pipeline Configuration

### Service Level Pipeline (GitLab CI)
```yaml
Stages:
1. Validate
   - Config validation
   - Network range verification
2. Plan
   - Terraform plan
   - Cost estimation
3. Apply
   - Infrastructure creation
   - Post-deploy validation
```

### Tenant Level Pipeline
```yaml
Stages:
1. Validate
   - Tenant ID validation
   - Permission checks
2. Deploy
   - IAM role creation
   - Index setup
3. Test
   - Connectivity validation
   - Permission validation
```

## State Management
1. Backend Configuration:
   - S3 bucket for state storage
   - DynamoDB table for state locking
   - Separate state files:
     * service-state/terraform.tfstate
     * tenant-state/[tenant-id]/terraform.tfstate

2. State Locking:
   - DynamoDB TTL: 24 hours
   - Lock monitoring
   - Force unlock procedure

## Required Variables

### Service Level
```hcl
Required:
- aws_region
- environment
- vpc_cidr
- opensearch_domain_name
- service_principal_arn

Optional:
- opensearch_instance_type (default: r6g.large.search)
- opensearch_instance_count (default: 2)
```

### Tenant Level
```hcl
Required:
- tenant_id
- tenant_account_id
- service_vpc_id
- opensearch_domain_arn

Optional:
- index_prefix (default: tenant-id)
- max_indices (default: 3)
```

## OpenSearch Configuration

### Vector Search Setup
```yaml
Index Template:
  - index_patterns: "tenant-*"
  - settings:
      - number_of_shards: 3
      - number_of_replicas: 1
      - index.knn: true
  - mappings:
      - vector_field:
          - type: knn_vector
          - dimension: 1536
          - method:
              - name: hnsw
              - space_type: cosine
```

### Backup Configuration
- Automated snapshots to S3
- Retention: 14 days
- Snapshot schedule: Daily

## Monitoring & Alerting

### CloudWatch Metrics
1. OpenSearch:
   - Cluster health
   - Search latency
   - Vector search performance
   - Index size

2. Bedrock:
   - API latency
   - Error rates
   - Cost metrics

### Log Groups
```
/aws/opensearch/[domain]/
/aws/bedrock/[environment]/
```

### Alerts
1. Critical:
   - Cluster health RED
   - API error rate > 5%
   - Index creation failures

2. Warning:
   - High latency (>2s)
   - Disk space > 80%
   - Concurrent request throttling

## Testing Framework

### Service Level Tests
1. Infrastructure:
   - VPC creation
   - OpenSearch deployment
   - IAM role validation

2. Performance:
   - Vector search latency < 100ms
   - Concurrent request handling
   - Resource utilization

### Tenant Level Tests
1. Access:
   - Role assumption
   - Index creation
   - Search permissions

2. Integration:
   - End-to-end RAG flow
   - Cross-account access
   - Network connectivity

### Test Data
- Sample vectors
- Test documents
- Query patterns

## Resource Cleanup

### Tenant Cleanup
1. Pre-cleanup:
   - Validate tenant ID
   - Check dependencies
   - Backup if needed

2. Cleanup Steps:
   - Delete indices
   - Remove IAM roles
   - Update security groups

3. Validation:
   - Verify resource removal
   - Check for orphaned resources
   - Validate access removal

## Deployment Prerequisites
1. Network Team:
   - CIDR range allocation
   - VPC peering setup
   - Route table updates

2. Security Team:
   - IAM role review
   - Security group rules
   - Compliance validation

3. Operations Team:
   - Service principal creation
   - State backend setup
   - Pipeline configuration