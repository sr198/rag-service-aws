import os
import json
import time
import jwt
import requests
from typing import Dict, Any, Optional

def generate_policy(principal_id: str, effect: str, resource: str, context: Optional[Dict] = None) -> Dict:
    """
    Generate an IAM policy for API Gateway
    """
    policy = {
        'principalId': principal_id,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [{
                'Action': 'execute-api:Invoke',
                'Effect': effect,
                'Resource': resource
            }]
        }
    }
    
    if context:
        policy['context'] = context
        
    return policy

def extract_token(auth_header: str) -> str:
    """
    Extract token from Authorization header
    """
    if auth_header.lower().startswith('bearer '):
        return auth_header[7:]
    return auth_header

def validate_token(token: str) -> Dict[str, Any]:
    """
    Validate JWT token
    In production, this would validate against your auth provider
    """
    try:
        # For testing/development - use environment variables
        if os.environ.get('BYPASS_AUTH', '').lower() == 'true':
            test_token = os.environ.get('TEST_TOKEN', 'integration-test-token')
            if token == test_token:
                return {
                    'tenant_id': os.environ.get('TEST_TENANT_ID', 'test-tenant'),
                    'environment': os.environ.get('TEST_ENVIRONMENT', 'test')
                }
                
        # Production validation
        # Note: Replace this with your actual token validation logic
        secret = os.environ.get('JWT_SECRET')
        if not secret:
            raise ValueError("JWT_SECRET not configured")
            
        claims = jwt.decode(
            token,
            secret,
            algorithms=['HS256'],
            options={
                'verify_exp': True,
                'require': ['tenant_id', 'environment']
            }
        )
        
        # Additional validation could be added here
        # For example, checking tenant status, rate limits, etc.
        
        return claims
        
    except jwt.ExpiredSignatureError:
        raise ValueError("Token has expired")
    except jwt.InvalidTokenError as e:
        raise ValueError(f"Invalid token: {str(e)}")
    except Exception as e:
        raise ValueError(f"Token validation failed: {str(e)}")

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda authorizer for API Gateway
    """
    try:
        # Extract token
        token = event.get('authorizationToken')
        if not token:
            raise ValueError("No authorization token provided")
            
        token = extract_token(token)
        
        # Get methodArn from event
        method_arn = event['methodArn']
        
        # Validate token and get claims
        claims = validate_token(token)
        
        # Extract required information
        tenant_id = claims.get('tenant_id')
        environment = claims.get('environment')
        
        if not tenant_id or not environment:
            raise ValueError("Missing required claims: tenant_id and environment")
            
        # Generate policy with tenant context
        return generate_policy(
            tenant_id,
            'Allow',
            method_arn,
            {
                'tenant_id': tenant_id,
                'environment': environment,
                'authorized_at': int(time.time())
            }
        )
        
    except Exception as e:
        print(f"Authorization failed: {str(e)}")
        # Always return Deny policy on error
        return generate_policy(
            'unauthorized',
            'Deny',
            event.get('methodArn', '*')
        )