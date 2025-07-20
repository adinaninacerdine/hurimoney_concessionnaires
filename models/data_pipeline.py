# -*- coding: utf-8 -*-
import json
import boto3
import logging
import os
from datetime import datetime, timedelta
from odoo import models, fields, api
from odoo.exceptions import UserError
import threading
from queue import Queue
import time

_logger = logging.getLogger(__name__)

class DataPipelineConnector(models.Model):
    _name = 'hurimoney.data.pipeline'
    _description = 'Connecteur Pipeline de donnees B2C'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    
    name = fields.Char(string='Nom', default='Pipeline B2C HuriMoney')
    
    # Configuration Kinesis
    kinesis_stream_name = fields.Char(
        string='Nom du Stream Kinesis', 
        default=lambda self: self._get_stream_name()
    )
    kinesis_region = fields.Char(string='Region AWS', default='eu-west-1')
    kinesis_access_key = fields.Char(string='AWS Access Key')
    kinesis_secret_key = fields.Char(string='AWS Secret Key')
    kinesis_enabled = fields.Boolean(string='Kinesis active', default=True)
    
    # Configuration DynamoDB
    dynamodb_table_name = fields.Char(
        string='Table DynamoDB', 
        default=lambda self: self._get_table_name()
    )
    dynamodb_enabled = fields.Boolean(string='DynamoDB active', default=True)
    
    # Configuration MongoDB (DocumentDB)
    mongodb_connection = fields.Char(
        string='MongoDB Connection String',
        default=lambda self: self._get_documentdb_connection()
    )
    mongodb_database = fields.Char(string='Base MongoDB', default='hurimoney_analytics')
    mongodb_enabled = fields.Boolean(string='MongoDB active', default=True)
    
    # Etat et metriques
    state = fields.Selection([
        ('stopped', 'Arrete'),
        ('running', 'En cours'),
        ('error', 'Erreur'),
    ], string='Etat', default='stopped')
    
    last_sequence_number = fields.Char(string='Dernier numero de sequence')
    records_processed = fields.Integer(string='Enregistrements traites', readonly=True)
    last_processing_date = fields.Datetime(string='Dernier traitement')
    error_message = fields.Text(string='Dernier message d\'erreur')
    
    # Configuration de traitement
    batch_size = fields.Integer(string='Taille du batch', default=100)
    processing_interval = fields.Integer(string='Intervalle (secondes)', default=30)
    enable_real_time = fields.Boolean(string='Traitement temps reel', default=True)
    
    @api.model
    def _get_stream_name(self):
        """Recuperer le nom du stream depuis les outputs Terraform ou variable d'environnement"""
        return os.environ.get('KINESIS_STREAM_NAME', 'transaction_stream')
    
    @api.model
    def _get_table_name(self):
        """Recuperer le nom de la table depuis les outputs Terraform ou variable d'environnement"""
        return os.environ.get('DYNAMODB_TABLE_NAME', 'customer_table')
    
    @api.model
    def _get_documentdb_connection(self):
        """Recuperer la chaine de connexion DocumentDB"""
        return os.environ.get('DOCUMENTDB_CONNECTION_STRING', '')
    
    def start_pipeline(self):
        """Demarrer le pipeline de donnees"""
        self.ensure_one()
        
        if self.state == 'running':
            raise UserError("Le pipeline est deja en cours d'execution")
        
        # Verifier la configuration
        if self.kinesis_enabled and not all([self.kinesis_stream_name, self.kinesis_access_key]):
            raise UserError("Configuration Kinesis incomplete")
        
        self.state = 'running'
        self.error_message = False
        
        # Demarrer le processus en arriere-plan
        if self.enable_real_time:
            threading.Thread(target=self._process_stream_background, daemon=True).start()
        
        self.message_post(body="Pipeline demarre")
        
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Pipeline demarre',
                'message': 'Le pipeline de donnees est maintenant actif',
                'type': 'success',
            }
        }
    
    def stop_pipeline(self):
        """Arreter le pipeline de donnees"""
        self.ensure_one()
        self.state = 'stopped'
        self.message_post(body="Pipeline arrete")
    
    def _process_stream_background(self):
        """Processus de traitement en arriere-plan"""
        with api.Environment.manage():
            with self.pool.cursor() as new_cr:
                new_env = api.Environment(new_cr, self.env.uid, self.env.context)
                pipeline = new_env['hurimoney.data.pipeline'].browse(self.id)
                
                while pipeline.state == 'running':
                    try:
                        pipeline.process_kinesis_records()
                        new_cr.commit()
                        time.sleep(pipeline.processing_interval)
                    except Exception as e:
                        _logger.error(f"Erreur pipeline: {str(e)}")
                        pipeline.write({
                            'state': 'error',
                            'error_message': str(e)
                        })
                        new_cr.commit()
                        break
    
    def process_kinesis_records(self):
        """Traiter les enregistrements depuis Kinesis"""
        self.ensure_one()
        
        if not self.kinesis_enabled:
            return
        
        try:
            # Initialiser le client Kinesis
            kinesis_client = boto3.client(
                'kinesis',
                region_name=self.kinesis_region,
                aws_access_key_id=self.kinesis_access_key,
                aws_secret_access_key=self.kinesis_secret_key
            )
            
            # Obtenir les shards
            stream_description = kinesis_client.describe_stream(
                StreamName=self.kinesis_stream_name
            )
            
            records_batch = []
            
            for shard in stream_description['StreamDescription']['Shards']:
                shard_id = shard['ShardId']
                
                # Obtenir l'iterateur
                if self.last_sequence_number:
                    iterator_response = kinesis_client.get_shard_iterator(
                        StreamName=self.kinesis_stream_name,
                        ShardId=shard_id,
                        ShardIteratorType='AFTER_SEQUENCE_NUMBER',
                        StartingSequenceNumber=self.last_sequence_number
                    )
                else:
                    iterator_response = kinesis_client.get_shard_iterator(
                        StreamName=self.kinesis_stream_name,
                        ShardId=shard_id,
                        ShardIteratorType='TRIM_HORIZON'
                    )
                
                shard_iterator = iterator_response['ShardIterator']
                
                # Lire les enregistrements
                records_response = kinesis_client.get_records(
                    ShardIterator=shard_iterator,
                    Limit=self.batch_size
                )
                
                for record in records_response['Records']:
                    data = json.loads(record['Data'])
                    records_batch.append({
                        'sequence_number': record['SequenceNumber'],
                        'data': data,
                        'timestamp': record.get('ApproximateArrivalTimestamp', datetime.now())
                    })
                
                # Mettre a jour le dernier numero de sequence
                if records_response['Records']:
                    self.last_sequence_number = records_response['Records'][-1]['SequenceNumber']
            
            # Traiter le batch
            if records_batch:
                self._process_batch(records_batch)
                
        except Exception as e:
            _logger.error(f"Erreur Kinesis: {str(e)}")
            self.error_message = str(e)
            raise
    
    def _process_batch(self, records):
        """Traiter un batch d'enregistrements"""
        processed = 0
        customer_updates = {}
        
        for record in records:
            try:
                data = record['data']
                customer_phone = data.get('customer_phone')
                
                if not customer_phone:
                    continue
                
                # Agreger les donnees par client
                if customer_phone not in customer_updates:
                    customer_updates[customer_phone] = {
                        'transactions': [],
                        'total_amount': 0,
                        'last_transaction': None,
                        'customer_name': data.get('customer_name')
                    }
                
                customer_updates[customer_phone]['transactions'].append(data)
                customer_updates[customer_phone]['total_amount'] += data.get('amount', 0)
                
                if not customer_updates[customer_phone]['last_transaction'] or \
                   data['transaction_date'] > customer_updates[customer_phone]['last_transaction']:
                    customer_updates[customer_phone]['last_transaction'] = data['transaction_date']
                
                processed += 1
                
            except Exception as e:
                _logger.error(f"Erreur traitement record: {str(e)}")
        
        # Mettre a jour DynamoDB
        if self.dynamodb_enabled:
            self._update_dynamodb(customer_updates)
        
        # Mettre a jour MongoDB/DocumentDB
        if self.mongodb_enabled:
            self._update_mongodb(records)
        
        # Mettre a jour Odoo
        self._update_odoo_analytics(customer_updates)
        
        # Mettre a jour les metriques
        self.write({
            'records_processed': self.records_processed + processed,
            'last_processing_date': fields.Datetime.now()
        })
    
    def _update_dynamodb(self, customer_updates):
        """Mettre a jour les agregations dans DynamoDB"""
        if not self.dynamodb_enabled:
            return
        
        try:
            dynamodb = boto3.resource(
                'dynamodb',
                region_name=self.kinesis_region,
                aws_access_key_id=self.kinesis_access_key,
                aws_secret_access_key=self.kinesis_secret_key
            )
            
            table = dynamodb.Table(self.dynamodb_table_name)
            
            for customer_phone, updates in customer_updates.items():
                # Mettre a jour ou creer l'agregation client
                response = table.update_item(
                    Key={'customer_phone': customer_phone},
                    UpdateExpression="""
                        ADD transaction_count :count,
                            total_amount :amount,
                            monthly_amount :monthly
                        SET last_transaction_date = :last_date,
                            customer_name = if_not_exists(customer_name, :name),
                            updated_at = :now
                    """,
                    ExpressionAttributeValues={
                        ':count': len(updates['transactions']),
                        ':amount': updates['total_amount'],
                        ':monthly': updates['total_amount'],  # A ajuster selon la logique metier
                        ':last_date': updates['last_transaction'],
                        ':name': updates['customer_name'],
                        ':now': datetime.now().isoformat()
                    },
                    ReturnValues="ALL_NEW"
                )
                
                # Calculer et mettre a jour le segment
                self._calculate_segment_dynamodb(table, customer_phone, response['Attributes'])
                
        except Exception as e:
            _logger.error(f"Erreur DynamoDB: {str(e)}")
    
    def _calculate_segment_dynamodb(self, table, customer_phone, attributes):
        """Calculer le segment client dans DynamoDB"""
        transaction_count = attributes.get('transaction_count', 0)
        total_amount = attributes.get('total_amount', 0)
        last_date = attributes.get('last_transaction_date')
        
        # Calculer la recence
        if last_date:
            last_date_obj = datetime.fromisoformat(last_date)
            recency_days = (datetime.now() - last_date_obj).days
        else:
            recency_days = 999
        
        # Determiner le segment
        if total_amount >= 1000000 and transaction_count >= 20:
            segment = 'HIGH_VALUE'
        elif recency_days <= 30 and transaction_count >= 10:
            segment = 'LOYAL'
        elif recency_days > 60 and transaction_count >= 5:
            segment = 'AT_RISK'
        elif transaction_count <= 3:
            segment = 'NEW'
        else:
            segment = 'OTHER'
        
        # Mettre a jour le segment
        table.update_item(
            Key={'customer_phone': customer_phone},
            UpdateExpression="SET segment = :segment, recency_days = :recency",
            ExpressionAttributeValues={
                ':segment': segment,
                ':recency': recency_days
            }
        )
    
    def _update_mongodb(self, records):
        """Stocker les donnees detaillees dans MongoDB/DocumentDB"""
        if not self.mongodb_enabled or not self.mongodb_connection:
            return
        
        try:
            from pymongo import MongoClient, UpdateOne
            
            client = MongoClient(self.mongodb_connection)
            db = client[self.mongodb_database]
            
            # Collection des transactions
            transactions_collection = db.transactions
            
            # Inserer les transactions
            if records:
                transactions_collection.insert_many([
                    {
                        **record['data'],
                        'processed_at': datetime.now(),
                        'sequence_number': record['sequence_number']
                    }
                    for record in records
                ])
            
            # Mettre a jour les agregations
            analytics_collection = db.customer_analytics
            
            # Pipeline d'agregation MongoDB
            pipeline = [
                {
                    '$group': {
                        '_id': '$customer_phone',
                        'customer_name': {'$first': '$customer_name'},
                        'transaction_count': {'$sum': 1},
                        'total_amount': {'$sum': '$amount'},
                        'avg_amount': {'$avg': '$amount'},
                        'last_transaction': {'$max': '$transaction_date'},
                        'first_transaction': {'$min': '$transaction_date'},
                        'transaction_types': {'$addToSet': '$transaction_type'}
                    }
                },
                {
                    '$project': {
                        'customer_phone': '$_id',
                        'customer_name': 1,
                        'metrics': {
                            'frequency': '$transaction_count',
                            'monetary': '$total_amount',
                            'avg_transaction': '$avg_amount',
                            'recency': {
                                '$dateDiff': {
                                    'startDate': '$last_transaction',
                                    'endDate': '$$NOW',
                                    'unit': 'day'
                                }
                            }
                        },
                        'behavior': {
                            'first_transaction': '$first_transaction',
                            'last_transaction': '$last_transaction',
                            'preferred_types': '$transaction_types'
                        }
                    }
                }
            ]
            
            # Executer l'agregation
            results = list(transactions_collection.aggregate(pipeline))
            
            # Mettre a jour les analytics
            bulk_operations = []
            for result in results:
                bulk_operations.append(
                    UpdateOne(
                        {'customer_phone': result['customer_phone']},
                        {'$set': result},
                        upsert=True
                    )
                )
            
            if bulk_operations:
                analytics_collection.bulk_write(bulk_operations)
            
            client.close()
            
        except Exception as e:
            _logger.error(f"Erreur MongoDB: {str(e)}")
    
    def _update_odoo_analytics(self, customer_updates):
        """Mettre a jour les analytics dans Odoo"""
        CustomerAnalytics = self.env['hurimoney.customer.analytics']
        
        for customer_phone, updates in customer_updates.items():
            # Chercher ou creer le client
            customer = CustomerAnalytics.search([
                ('customer_phone', '=', customer_phone)
            ], limit=1)
            
            if not customer:
                customer = CustomerAnalytics.create({
                    'customer_phone': customer_phone,
                    'customer_name': updates['customer_name'],
                    'first_transaction_date': updates['last_transaction'],
                })
            
            # Mettre a jour les metriques
            customer.write({
                'last_transaction_date': updates['last_transaction'],
                'frequency': customer.frequency + len(updates['transactions']),
                'monetary_value': customer.monetary_value + updates['total_amount'],
                'recency_days': 0,  # Transaction aujourd'hui
                'data_source': 'kinesis'
            })
        
        # Recalculer les scores RFM
        CustomerAnalytics.calculate_rfm_scores()
    
    @api.model
    def get_dynamodb_stats(self):
        """Obtenir les statistiques depuis DynamoDB pour le dashboard"""
        if not self.dynamodb_enabled:
            return {}
        
        try:
            dynamodb = boto3.resource(
                'dynamodb',
                region_name=self.kinesis_region,
                aws_access_key_id=self.kinesis_access_key,
                aws_secret_access_key=self.kinesis_secret_key
            )
            
            table = dynamodb.Table(self.dynamodb_table_name)
            
            # Scanner pour obtenir les stats par segment
            response = table.scan(
                ProjectionExpression='segment, total_amount, transaction_count'
            )
            
            stats = {
                'HIGH_VALUE': {'count': 0, 'volume': 0},
                'LOYAL': {'count': 0, 'volume': 0},
                'AT_RISK': {'count': 0, 'volume': 0},
                'NEW': {'count': 0, 'volume': 0},
                'OTHER': {'count': 0, 'volume': 0}
            }
            
            for item in response['Items']:
                segment = item.get('segment', 'OTHER')
                if segment in stats:
                    stats[segment]['count'] += 1
                    stats[segment]['volume'] += item.get('total_amount', 0)
            
            return stats
            
        except Exception as e:
            _logger.error(f"Erreur get stats DynamoDB: {str(e)}")
            return {}


# Configuration wizard pour le pipeline
class DataPipelineConfigWizard(models.TransientModel):
    _name = 'hurimoney.pipeline.config.wizard'
    _description = 'Assistant de configuration du pipeline'
    
    pipeline_id = fields.Many2one('hurimoney.data.pipeline', string='Pipeline')
    
    # Test de connexion
    test_kinesis = fields.Boolean(string='Tester Kinesis', default=True)
    test_dynamodb = fields.Boolean(string='Tester DynamoDB', default=True)
    test_mongodb = fields.Boolean(string='Tester MongoDB', default=True)
    
    test_results = fields.Html(string='Resultats des tests', readonly=True)
    
    def action_test_connections(self):
        """Tester toutes les connexions"""
        results = []
        
        # Test Kinesis
        if self.test_kinesis and self.pipeline_id.kinesis_enabled:
            try:
                kinesis_client = boto3.client(
                    'kinesis',
                    region_name=self.pipeline_id.kinesis_region,
                    aws_access_key_id=self.pipeline_id.kinesis_access_key,
                    aws_secret_access_key=self.pipeline_id.kinesis_secret_key
                )
                kinesis_client.describe_stream(StreamName=self.pipeline_id.kinesis_stream_name)
                results.append('<p style="color: green;">✅ Kinesis: Connexion reussie</p>')
            except Exception as e:
                results.append(f'<p style="color: red;">❌ Kinesis: {str(e)}</p>')
        
        # Test DynamoDB
        if self.test_dynamodb and self.pipeline_id.dynamodb_enabled:
            try:
                dynamodb = boto3.resource(
                    'dynamodb',
                    region_name=self.pipeline_id.kinesis_region,
                    aws_access_key_id=self.pipeline_id.kinesis_access_key,
                    aws_secret_access_key=self.pipeline_id.kinesis_secret_key
                )
                table = dynamodb.Table(self.pipeline_id.dynamodb_table_name)
                table.table_status
                results.append('<p style="color: green;">✅ DynamoDB: Connexion reussie</p>')
            except Exception as e:
                results.append(f'<p style="color: red;">❌ DynamoDB: {str(e)}</p>')
        
        # Test MongoDB
        if self.test_mongodb and self.pipeline_id.mongodb_enabled:
            try:
                from pymongo import MongoClient
                client = MongoClient(self.pipeline_id.mongodb_connection)
                client.server_info()
                client.close()
                results.append('<p style="color: green;">✅ MongoDB: Connexion reussie</p>')
            except Exception as e:
                results.append(f'<p style="color: red;">❌ MongoDB: {str(e)}</p>')
        
        self.test_results = ''.join(results)
        
        return {
            'type': 'ir.actions.act_window',
            'res_model': 'hurimoney.pipeline.config.wizard',
            'view_mode': 'form',
            'res_id': self.id,
            'target': 'new',
        }