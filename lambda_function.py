import json
import base64
import boto3
import os
import re
import requests
from decimal import Decimal
from datetime import datetime, timedelta
from pymongo import MongoClient

# AWS DynamoDB
dynamodb = boto3.resource('dynamodb')
customer_table = dynamodb.Table(os.environ['CUSTOMER_TABLE_NAME'])

# MongoDB
mongodb_client = MongoClient(os.environ['MONGODB_URI'])
mongodb_db = mongodb_client['hurimoney_analytics']
customers_collection = mongodb_db['customers']
transactions_collection = mongodb_db['transactions']

# Odoo API
ODOO_API_URL = os.environ['ODOO_API_URL']
ODOO_API_KEY = os.environ['ODOO_API_KEY']

def clean_phone(phone):
    return re.sub(r'\D', '', phone)

def calculate_customer_segment(customer_data):
    """Calcule le segment du client basé sur ses données"""
    total_amount = float(customer_data.get('total_amount', 0))
    transaction_count = customer_data.get('transaction_count', 0)
    
    # Calcul de la récence (jours depuis la dernière transaction)
    last_transaction = customer_data.get('last_transaction')
    if last_transaction:
        last_date = datetime.fromisoformat(last_transaction.replace('Z', '+00:00'))
        days_since_last = (datetime.now() - last_date).days
    else:
        days_since_last = 999
    
    # Calcul du score RFM (Récence, Fréquence, Montant)
    recency_score = 5 if days_since_last <= 7 else 4 if days_since_last <= 30 else 3 if days_since_last <= 90 else 1
    frequency_score = 5 if transaction_count >= 20 else 4 if transaction_count >= 10 else 3 if transaction_count >= 5 else 2 if transaction_count >= 2 else 1
    monetary_score = 5 if total_amount >= 1000000 else 4 if total_amount >= 500000 else 3 if total_amount >= 100000 else 2 if total_amount >= 50000 else 1
    
    # Détermination du segment
    if monetary_score >= 4 and frequency_score >= 4:
        return 'HIGH_VALUE'
    elif recency_score >= 4 and frequency_score >= 3:
        return 'LOYAL'
    elif recency_score <= 2 and frequency_score <= 2:
        return 'AT_RISK'
    elif transaction_count <= 2:
        return 'NEW'
    else:
        return 'OTHER'

def should_sync_to_crm(segment, customer_data):
    """Détermine si le client doit être synchronisé avec le CRM Odoo"""
    # Segments à synchroniser
    sync_segments = ['HIGH_VALUE', 'LOYAL']
    
    # Critères supplémentaires
    total_amount = float(customer_data.get('total_amount', 0))
    transaction_count = customer_data.get('transaction_count', 0)
    
    return (
        segment in sync_segments or
        total_amount >= 500000 or  # Volume élevé
        transaction_count >= 15    # Fréquence élevée
    )

def sync_to_odoo_crm(customer_data):
    """Synchronise le client avec le CRM Odoo"""
    try:
        # Préparer les données pour Odoo
        partner_data = {
            'name': customer_data.get('customer_name', customer_data.get('customer_phone')),
            'phone': customer_data.get('customer_phone'),
            'x_b2c_segment': customer_data.get('segment'),
            'x_total_transactions': customer_data.get('transaction_count', 0),
            'x_total_amount': float(customer_data.get('total_amount', 0)),
            'x_first_transaction': customer_data.get('first_transaction'),
            'x_last_transaction': customer_data.get('last_transaction'),
            'is_company': False,
            'customer_rank': 1,
        }
        
        # Appel API Odoo pour créer/mettre à jour le contact
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {ODOO_API_KEY}'
        }
        
        # Chercher si le contact existe déjà
        search_response = requests.post(
            f'{ODOO_API_URL}/api/v1/search',
            json={
                'model': 'res.partner',
                'domain': [['phone', '=', customer_data.get('customer_phone')]]
            },
            headers=headers
        )
        
        if search_response.status_code == 200:
            existing_ids = search_response.json().get('result', [])
            
            if existing_ids:
                # Mettre à jour le contact existant
                update_response = requests.post(
                    f'{ODOO_API_URL}/api/v1/update',
                    json={
                        'model': 'res.partner',
                        'ids': existing_ids,
                        'values': partner_data
                    },
                    headers=headers
                )
                print(f"Updated partner {customer_data.get('customer_phone')}: {update_response.status_code}")
            else:
                # Créer un nouveau contact
                create_response = requests.post(
                    f'{ODOO_API_URL}/api/v1/create',
                    json={
                        'model': 'res.partner',
                        'values': partner_data
                    },
                    headers=headers
                )
                print(f"Created partner {customer_data.get('customer_phone')}: {create_response.status_code}")
                
    except Exception as e:
        print(f"Error syncing to Odoo: {str(e)}")

def handler(event, context):
    for record in event['Records']:
        try:
            # Décoder les données Kinesis
            payload = base64.b64decode(record['kinesis']['data']).decode('utf-8')
            transaction = json.loads(payload)
            
            customer_phone = clean_phone(transaction.get('customer_phone', ''))
            if not customer_phone:
                continue
            
            # 1. Traitement DynamoDB (cache rapide)
            response = customer_table.get_item(Key={'customer_phone': customer_phone})
            customer = response.get('Item', {})
            
            if not customer:
                customer['customer_phone'] = customer_phone
                customer['first_transaction'] = transaction['transaction_date']
                customer['total_amount'] = Decimal('0')
                customer['transaction_count'] = 0
            
            customer['last_transaction'] = transaction['transaction_date']
            customer['total_amount'] = Decimal(str(customer.get('total_amount', 0))) + Decimal(str(transaction['amount']))
            customer['transaction_count'] += 1
            customer['customer_name'] = transaction.get('customer_name', customer_phone)
            
            # Calcul du segment
            segment = calculate_customer_segment(customer)
            customer['segment'] = segment
            
            # Persister dans DynamoDB
            customer_table.put_item(Item=customer)
            
            # 2. Traitement MongoDB (analyses avancées)
            # Convertir Decimal en float pour MongoDB
            customer_mongo = {k: float(v) if isinstance(v, Decimal) else v for k, v in customer.items()}
            
            # Upsert dans MongoDB
            customers_collection.replace_one(
                {'customer_phone': customer_phone},
                customer_mongo,
                upsert=True
            )
            
            # Stocker la transaction dans MongoDB
            transaction_mongo = {
                'customer_phone': customer_phone,
                'transaction_date': transaction['transaction_date'],
                'amount': float(transaction['amount']),
                'transaction_type': transaction.get('transaction_type'),
                'concessionnaire_id': transaction.get('concessionnaire_id'),
                'processed_at': datetime.now().isoformat()
            }
            
            transactions_collection.insert_one(transaction_mongo)
            
            # 3. Synchronisation sélective avec CRM Odoo
            if should_sync_to_crm(segment, customer_mongo):
                sync_to_odoo_crm(customer_mongo)
                
        except Exception as e:
            print(f"Error processing record: {str(e)}")
            continue
    
    return {
        'statusCode': 200,
        'body': json.dumps('Success')
    }