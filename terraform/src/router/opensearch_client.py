import os
import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
from typing import Dict, Any

def create_response(status_code: int, body: Any) -> Dict[str, Any]:
    """Create a standardized API response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': body
    }

def get_opensearch_client() -> OpenSearch:
    """Create OpenSearch client with service role credentials"""
    credentials = boto3.Session().get_credentials()
    region = os.environ['AWS_REGION']
    
    auth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key,
        region,
        'es',
        session_token=credentials.token
    )
    
    return OpenSearch(
        hosts=[{'host': os.environ['OPENSEARCH_ENDPOINT'], 'port': 443}],
        http_auth=auth,
        use_ssl=True,
        verify_certs=True,
        connection_class=RequestsHttpConnection
    )

def handle_opensearch_request(body: Dict[str, Any], tenant_id: str) -> Dict[str, Any]:
    """
    Handle OpenSearch operations with tenant isolation
    """
    try:
        client = get_opensearch_client()
        
        # Extract request parameters
        operation = body.get('operation', 'search')
        index = body.get('index')
        
        if not index:
            return create_response(400, {
                'error': 'Index name is required'
            })
            
        # Enforce tenant isolation through index pattern
        if not index.startswith(f"{tenant_id}-"):
            return create_response(403, {
                'error': 'Access denied to this index'
            })

        if operation == 'search':
            search_body = body.get('body', {})
            response = client.search(
                index=index,
                body=search_body
            )
            return create_response(200, response)

        elif operation == 'index':
            documents = body.get('documents', [])
            if not isinstance(documents, list):
                documents = [documents]
            
            if len(documents) > 1:
                # Bulk indexing
                bulk_body = []
                for doc in documents:
                    # Index action
                    bulk_body.append({
                        "index": {
                            "_index": index,
                            "_id": doc.get('_id')
                        }
                    })
                    # Document data
                    bulk_body.append(doc.get('document', doc))
                
                response = client.bulk(body=bulk_body)
                
            else:
                # Single document index
                doc = documents[0]
                doc_id = doc.get('_id')
                document = doc.get('document', doc)
                
                if doc_id:
                    response = client.index(
                        index=index,
                        id=doc_id,
                        body=document
                    )
                else:
                    response = client.index(
                        index=index,
                        body=document
                    )
            
            return create_response(200, response)

        elif operation == 'delete':
            doc_id = body.get('id')
            if not doc_id:
                return create_response(400, {
                    'error': 'Document ID required for delete operation'
                })
            
            response = client.delete(
                index=index,
                id=doc_id
            )
            return create_response(200, response)

        else:
            return create_response(400, {
                'error': f'Unsupported operation: {operation}'
            })
            
    except Exception as e:
        print(f"OpenSearch operation failed: {str(e)}")
        return create_response(500, {
            'error': 'Operation failed'
        })