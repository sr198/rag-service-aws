#!/bin/bash
set -e

# Configuration
ENVIRONMENT=${1:-dev}
export TEST_TOKEN="integration-test-token"

# Get API URL from Terraform output
cd "$(dirname "$0")/../terraform"
export API_URL=$(terraform output -raw api_endpoint)

if [ -z "$API_URL" ]; then
    echo "Error: Could not get API URL from Terraform output"
    exit 1
fi

echo "Running tests against API: $API_URL"

# Run token tests
cd ../tests
echo "Running token tests..."
python test_tokens.py

# Run integration tests
echo "Running integration tests..."
python integration_test.py

echo "All tests completed!"