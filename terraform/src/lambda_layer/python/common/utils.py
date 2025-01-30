import json
from typing import Dict, Any, Optional

def create_response(status_code: int, body: Any) -> Dict[str, Any]:
    """
    Create a standardized API response
    All Lambda responses should use this format
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'  # Configure as needed
        },
        'body': json.dumps(body)
    }

def generate_policy(principal_id: str, effect: str, resource: str, context: Optional[Dict] = None) -> Dict:
    """
    Generate IAM policy document for API Gateway authorization
    Used by the authorizer Lambda
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

def handle_error(error: Exception, status_code: int = 500) -> Dict[str, Any]:
    """
    Standardized error response handler
    Used by both Lambdas for consistent error reporting
    """
    error_types = {
        'ValueError': 400,
        'KeyError': 400,
        'PermissionError': 403,
        'TimeoutError': 504
    }
    
    # Use provided status code or get from error type
    response_code = status_code or error_types.get(error.__class__.__name__, 500)
    
    return create_response(
        response_code,
        {'error': str(error)}
    )