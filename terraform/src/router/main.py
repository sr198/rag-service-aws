import json
import os
from typing import Dict, Any
from bedrock_client import handle_bedrock_request
from opensearch_client import handle_opensearch_request

def create_response(status_code: int, body: Any) -> Dict[str, Any]:
    """Create a standardized API response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'  # Configure as needed
        },
        'body': json.dumps(body)
    }

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main router Lambda handler
    Routes requests to appropriate service handler based on path
    """
    try:
        # Extract tenant information from authorizer context
        authorizer = event.get('requestContext', {}).get('authorizer', {})
        tenant_id = authorizer.get('tenant_id')
        environment = authorizer.get('environment')
        
        if not tenant_id or not environment:
            return create_response(400, {
                'error': 'Missing tenant information'
            })

        # Parse request body
        body = {}
        if event.get('body'):
            body = json.loads(event['body'])

        # Get path and route to appropriate handler
        path = event.get('path', '').lower()
        
        if 'opensearch' in path:
            return handle_opensearch_request(body, tenant_id)
        elif 'bedrock' in path:
            return handle_bedrock_request(body)
        else:
            return create_response(404, {
                'error': 'Invalid service path'
            })

    except json.JSONDecodeError:
        return create_response(400, {
            'error': 'Invalid JSON in request body'
        })
    except Exception as e:
        print(f"Error processing request: {str(e)}")
        return create_response(500, {
            'error': 'Internal server error'
        })