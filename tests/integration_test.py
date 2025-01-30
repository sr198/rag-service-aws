import os
import json
import time
import requests
from typing import Dict, Any

class RagServiceIntegrationTest:
    def __init__(self, api_url: str, test_token: str = "integration-test-token"):
        self.api_url = api_url.rstrip('/')
        self.test_token = test_token
        self.headers = {
            'Authorization': f'Bearer {test_token}',
            'Content-Type': 'application/json'
        }
        self.test_tenant = f"test-tenant-{int(time.time())}"

    def test_opensearch_operations(self) -> bool:
        """Test OpenSearch index and search operations"""
        try:
            # Create test document
            index_payload = {
                "operation": "index",
                "index": f"{self.test_tenant}-test",
                "documents": [{
                    "document": {
                        "text": "Test document",
                        "embedding": [0.1] * 1536,  # Test embedding
                        "metadata": {
                            "test": True,
                            "timestamp": time.time()
                        }
                    }
                }]
            }

            # Index document
            response = requests.post(
                f"{self.api_url}/opensearch",
                headers=self.headers,
                json=index_payload
            )
            
            if response.status_code != 200:
                print(f"✗ Document indexing failed: {response.text}")
                return False

            # Allow time for indexing
            time.sleep(2)

            # Search for document
            search_payload = {
                "operation": "search",
                "index": f"{self.test_tenant}-test",
                "body": {
                    "query": {
                        "match": {
                            "text": "Test document"
                        }
                    }
                }
            }

            response = requests.post(
                f"{self.api_url}/opensearch",
                headers=self.headers,
                json=search_payload
            )

            if response.status_code != 200:
                print(f"✗ Search operation failed: {response.text}")
                return False

            results = response.json()
            if results['hits']['total']['value'] == 0:
                print("✗ No documents found")
                return False

            print("✓ OpenSearch operations successful")
            return True

        except Exception as e:
            print(f"✗ OpenSearch test failed: {str(e)}")
            return False

    def test_bedrock_operations(self) -> bool:
        """Test Bedrock model invocation"""
        try:
            payload = {
                "model_id": "anthropic.claude-3-sonnet-20240229",
                "request": {
                    "prompt": "What is 2+2?",
                    "max_tokens": 10
                }
            }

            response = requests.post(
                f"{self.api_url}/bedrock",
                headers=self.headers,
                json=payload
            )

            if response.status_code != 200:
                print(f"✗ Bedrock invocation failed: {response.text}")
                return False

            print("✓ Bedrock operations successful")
            return True

        except Exception as e:
            print(f"✗ Bedrock test failed: {str(e)}")
            return False

def main():
    # Get configuration from environment
    api_url = os.environ.get('API_URL')
    test_token = os.environ.get('TEST_TOKEN', 'integration-test-token')

    if not api_url:
        print("Error: API_URL environment variable not set")
        exit(1)

    print(f"\nRunning integration tests against {api_url}")
    tester = RagServiceIntegrationTest(api_url, test_token)

    # Run tests
    opensearch_success = tester.test_opensearch_operations()
    bedrock_success = tester.test_bedrock_operations()

    # Report results
    print("\nTest Results:")
    print(f"OpenSearch Tests: {'✓ Passed' if opensearch_success else '✗ Failed'}")
    print(f"Bedrock Tests: {'✓ Passed' if bedrock_success else '✗ Failed'}")

    # Exit with appropriate code
    if not (opensearch_success and bedrock_success):
        exit(1)
    print("\n✓ All tests passed!")

if __name__ == "__main__":
    main()