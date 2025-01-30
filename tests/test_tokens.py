import jwt
import time
from typing import Dict, Any

def generate_test_token(tenant_id: str, environment: str, secret_key: str) -> str:
    """Generate a test JWT token"""
    payload = {
        'tenant_id': tenant_id,
        'environment': environment,
        'iat': int(time.time()),
        'exp': int(time.time()) + 3600  # 1 hour expiry
    }
    
    return jwt.encode(payload, secret_key, algorithm='HS256')

def validate_test_token(token: str, secret_key: str) -> Dict[str, Any]:
    """Validate a test JWT token"""
    try:
        return jwt.decode(token, secret_key, algorithms=['HS256'])
    except jwt.ExpiredSignatureError:
        raise ValueError("Token has expired")
    except jwt.InvalidTokenError as e:
        raise ValueError(f"Invalid token: {str(e)}")

def main():
    # Test configuration
    SECRET_KEY = "your-test-secret-key"  # Use environment variable in practice
    TENANT_ID = "test-tenant"
    ENVIRONMENT = "test"

    try:
        # Generate token
        token = generate_test_token(TENANT_ID, ENVIRONMENT, SECRET_KEY)
        print(f"\nGenerated Token:\n{token}")

        # Validate token
        claims = validate_test_token(token, SECRET_KEY)
        print(f"\nToken Claims:\n{claims}")

        print("\n✓ Token generation and validation successful!")
        
    except Exception as e:
        print(f"\n✗ Token test failed: {str(e)}")
        exit(1)

if __name__ == "__main__":
    main()