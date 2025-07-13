
import json
import base64
import boto3
import os
import re
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
customer_table = dynamodb.Table(os.environ['CUSTOMER_TABLE_NAME'])

def clean_phone(phone):
    # This is a simple example. You might need a more robust solution.
    return re.sub(r'\D', '', phone)

def handler(event, context):
    for record in event['Records']:
        # Kinesis data is base64 encoded
        payload = base64.b64decode(record['kinesis']['data']).decode('utf-8')
        transaction = json.loads(payload)

        customer_phone = clean_phone(transaction['customer_phone'])
        if not customer_phone:
            continue

        # Get customer from DynamoDB
        response = customer_table.get_item(Key={'customer_phone': customer_phone})
        customer = response.get('Item', {})

        # Update customer data
        if not customer:
            customer['customer_phone'] = customer_phone
            customer['first_transaction'] = transaction['transaction_date']
            customer['total_amount'] = 0
            customer['transaction_count'] = 0

        customer['last_transaction'] = transaction['transaction_date']
        customer['total_amount'] = Decimal(str(customer.get('total_amount', 0))) + Decimal(str(transaction['amount']))
        customer['transaction_count'] += 1
        customer['customer_name'] = transaction['customer_name']

        # Persist to DynamoDB
        customer_table.put_item(Item=customer)

    return {
        'statusCode': 200,
        'body': json.dumps('Success')
    }
