import json
import boto3
from typing import Dict, Any

def create_response(status_code: int, body: Any) -> Dict[str, Any]:
    """Create a standardized API response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body)
    }

def handle_bedrock_request(body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle Bedrock model invocation requests
    """
    try:
        # Initialize Bedrock client
        client = boto3.client('bedrock-runtime')
        
        # Extract request parameters
        model_id = body.get('model_id', 'anthropic.claude-v2')
        request_body = body.get('request')
        
        if not request_body:
            return create_response(400, {
                'error': 'Missing request body for model invocation'
            })

        # Invoke model
        response = client.invoke_model(
            modelId=model_id,
            body=json.dumps(request_body)
        )
        
        # Parse and return response
        response_body = json.loads(response['body'].read())
        return create_response(200, response_body)
        
    except client.exceptions.ValidationException as e:
        return create_response(400, {
            'error': f'Invalid request: {str(e)}'
        })
    except client.exceptions.ModelTimeoutException:
        return create_response(504, {
            'error': 'Model invocation timed out'
        })
    except client.exceptions.ThrottlingException:
        return create_response(429, {
            'error': 'Rate limit exceeded'
        })
    except Exception as e:
        print(f"Error invoking Bedrock model: {str(e)}")
        return create_response(500, {
            'error': 'Failed to invoke model'
        })