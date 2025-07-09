# -*- coding: utf-8 -*-
import json
import logging
import requests
from datetime import datetime, timedelta
from odoo import models, fields, api
from odoo.exceptions import UserError, ValidationError

_logger = logging.getLogger(__name__)

class WakatiAPIConnector(models.Model):
    _name = 'wakati.api.connector'
    _description = 'Connecteur API WAKATI'
    _rec_name = 'name'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    
    name = fields.Char(string='Nom', default='Connecteur WAKATI', required=True)
    api_base_url = fields.Char(
        string='URL de base API', 
        default='https://api.wakati.com/v1', 
        required=True,
        help="URL de base de l'API WAKATI (ex: https://api.wakati.com/v1)"
    )
    api_key = fields.Char(string='Clé API', required=True, tracking=True)
    api_secret = fields.Char(string='Secret API', required=True)
    
    # Token d'authentification
    auth_token = fields.Char(string='Token actuel', readonly=True)
    token_expiry = fields.Datetime(string='Expiration du token', readonly=True)
    
    # Configuration de synchronisation
    auto_sync = fields.Boolean(string='Synchronisation automatique', default=True)
    sync_interval = fields.Integer(string='Intervalle de sync (heures)', default=4)
    last_sync_date = fields.Datetime(string='Dernière synchronisation', readonly=True)
    
    # Options de synchronisation
    sync_concessionnaires = fields.Boolean(string='Synchroniser concessionnaires', default=True)
    sync_transactions = fields.Boolean(string='Synchroniser transactions', default=True)
    sync_kits = fields.Boolean(string='Synchroniser kits', default=True)
    
    # Filtres de synchronisation
    sync_from_date = fields.Datetime(
        string='Synchroniser depuis', 
        help="Ne synchroniser que les données postérieures à cette date"
    )
    sync_zones = fields.Selection([
        ('all', 'Toutes les zones'),
        ('moroni', 'Moroni uniquement'),
        ('mutsamudu', 'Mutsamudu uniquement'),
        ('fomboni', 'Fomboni uniquement'),
    ], string='Zones à synchroniser', default='all')
    
    # Statistiques
    sync_success_count = fields.Integer(string='Synchronisations réussies', readonly=True)
    sync_error_count = fields.Integer(string='Erreurs de synchronisation', readonly=True)
    last_error_message = fields.Text(string='Dernier message d\'erreur', readonly=True)
    
    # État
    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('connected', 'Connecté'),
        ('error', 'Erreur'),
    ], string='État', default='draft', tracking=True)
    
    # Logs
    log_ids = fields.One2many('wakati.sync.log', 'connector_id', string='Logs de synchronisation')
    
    # Configuration avancée
    timeout = fields.Integer(string='Timeout (secondes)', default=30)
    retry_count = fields.Integer(string='Nombre de tentatives', default=3)
    verify_ssl = fields.Boolean(string='Vérifier SSL', default=True)
    
    # Mapping des champs
    field_mapping = fields.Text(
        string='Mapping des champs', 
        default='{}',
        help="Mapping JSON entre les champs WAKATI et Odoo"
    )
    
    _sql_constraints = [
        ('name_unique', 'UNIQUE(name)', 'Le nom du connecteur doit être unique!'),
    ]
    
    @api.constrains('api_base_url')
    def _check_api_url(self):
        for record in self:
            if record.api_base_url and not record.api_base_url.startswith(('http://', 'https://')):
                raise ValidationError("L'URL doit commencer par http:// ou https://")
    
    def _get_headers(self, auth_required=True):
        """Obtenir les headers pour les requêtes API"""
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'Odoo-HuriMoney/1.0',
        }
        
        if auth_required:
            token = self._ensure_valid_token()
            if token:
                headers['Authorization'] = f'Bearer {token}'
        
        return headers
    
    def _ensure_valid_token(self):
        """S'assurer que le token est valide, le renouveler si nécessaire"""
        if self.auth_token and self.token_expiry:
            # Vérifier si le token est encore valide (avec 5 minutes de marge)
            if fields.Datetime.now() < self.token_expiry - timedelta(minutes=5):
                return self.auth_token
        
        # Obtenir un nouveau token
        return self._get_auth_token()
    
    def _get_auth_token(self):
        """Obtenir le token d'authentification"""
        self.ensure_one()
        
        try:
            url = f"{self.api_base_url}/auth/token"
            data = {
                'api_key': self.api_key,
                'api_secret': self.api_secret
            }
            
            response = requests.post(
                url, 
                json=data, 
                timeout=self.timeout,
                verify=self.verify_ssl
            )
            
            if response.status_code == 200:
                result = response.json()
                token = result.get('token')
                expires_in = result.get('expires_in', 3600)  # Durée en secondes
                
                self.write({
                    'auth_token': token,
                    'token_expiry': fields.Datetime.now() + timedelta(seconds=expires_in),
                    'state': 'connected',
                    'last_error_message': False,
                })
                
                self.message_post(body="✅ Connexion à WAKATI établie avec succès")
                return token
            else:
                error_msg = f"Erreur auth WAKATI: {response.status_code} - {response.text}"
                self._handle_error(error_msg)
                return False
                
        except requests.exceptions.Timeout:
            self._handle_error("Timeout lors de la connexion à WAKATI")
            return False
        except requests.exceptions.ConnectionError:
            self._handle_error("Impossible de se connecter à WAKATI")
            return False
        except Exception as e:
            self._handle_error(f"Erreur connexion WAKATI: {str(e)}")
            return False
    
    def _handle_error(self, error_message):
        """Gérer les erreurs"""
        _logger.error(error_message)
        self.write({
            'state': 'error',
            'last_error_message': error_message,
            'sync_error_count': self.sync_error_count + 1,
        })
        self.message_post(body=f"❌ {error_message}", message_type='notification')
    
    def _make_api_request(self, endpoint, method='GET', data=None, params=None):
        """Faire une requête API générique avec gestion des erreurs"""
        self.ensure_one()
        
        url = f"{self.api_base_url}/{endpoint.lstrip('/')}"
        headers = self._get_headers()
        
        for attempt in range(self.retry_count):
            try:
                if method == 'GET':
                    response = requests.get(
                        url, 
                        headers=headers, 
                        params=params, 
                        timeout=self.timeout,
                        verify=self.verify_ssl
                    )
                elif method == 'POST':
                    response = requests.post(
                        url, 
                        headers=headers, 
                        json=data, 
                        timeout=self.timeout,
                        verify=self.verify_ssl
                    )
                elif method == 'PUT':
                    response = requests.put(
                        url, 
                        headers=headers, 
                        json=data, 
                        timeout=self.timeout,
                        verify=self.verify_ssl
                    )
                else:
                    raise ValueError(f"Méthode HTTP non supportée: {method}")
                
                # Si succès, retourner la réponse
                if response.status_code in [200, 201]:
                    return response.json()
                
                # Si erreur 401, renouveler le token et réessayer
                if response.status_code == 401 and attempt < self.retry_count - 1:
                    self._get_auth_token()
                    headers = self._get_headers()
                    continue
                
                # Autres erreurs
                error_msg = f"Erreur API {method} {endpoint}: {response.status_code} - {response.text}"
                self._handle_error(error_msg)
                return False
                
            except requests.exceptions.Timeout:
                if attempt < self.retry_count - 1:
                    _logger.warning(f"Timeout sur {endpoint}, tentative {attempt + 1}/{self.retry_count}")
                    continue
                self._handle_error(f"Timeout après {self.retry_count} tentatives sur {endpoint}")
                return False
                
            except Exception as e:
                if attempt < self.retry_count - 1:
                    _logger.warning(f"Erreur sur {endpoint}, tentative {attempt + 1}/{self.retry_count}: {str(e)}")
                    continue
                self._handle_error(f"Erreur API {endpoint}: {str(e)}")
                return False
        
        return False
    
    def action_test_connection(self):
        """Tester la connexion à l'API"""
        self.ensure_one()
        
        # Tester l'authentification
        token = self._get_auth_token()
        if not token:
            raise UserError("Impossible de se connecter à WAKATI. Vérifiez vos identifiants.")
        
        # Tester un endpoint simple
        result = self._make_api_request('status')
        if result:
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'Test réussi',
                    'message': f"Connexion à WAKATI établie. Version API: {result.get('version', 'N/A')}",
                    'type': 'success',
                }
            }
        else:
            raise UserError("La connexion est établie mais l'API ne répond pas correctement.")
    
    def sync_concessionnaires(self):
        """Synchroniser les concessionnaires depuis WAKATI"""
        self.ensure_one()
        
        if not self.sync_concessionnaires:
            return True
        
        # Créer un log
        log = self.env['wakati.sync.log'].create({
            'connector_id': self.id,
            'sync_type': 'concessionnaires',
            'start_date': fields.Datetime.now(),
        })
        
        try:
            # Préparer les paramètres
            params = {}
            if self.sync_from_date:
                params['updated_since'] = self.sync_from_date.isoformat()
            if self.sync_zones != 'all':
                params['zone'] = self.sync_zones
            
            # Récupérer les données
            result = self._make_api_request('concessionnaires', params=params)
            
            if not result:
                log.write({
                    'state': 'error',
                    'end_date': fields.Datetime.now(),
                    'error_message': self.last_error_message,
                })
                return False
            
            created_count = 0
            updated_count = 0
            error_count = 0
            
            for conc_data in result.get('data', []):
                try:
                    processed = self._process_concessionnaire(conc_data)
                    if processed == 'created':
                        created_count += 1
                    elif processed == 'updated':
                        updated_count += 1
                except Exception as e:
                    error_count += 1
                    _logger.error(f"Erreur traitement concessionnaire {conc_data.get('code')}: {str(e)}")
            
            # Mettre à jour le log
            log.write({
                'state': 'done',
                'end_date': fields.Datetime.now(),
                'records_created': created_count,
                'records_updated': updated_count,
                'records_failed': error_count,
            })
            
            # Message de succès
            self.message_post(
                body=f"✅ Synchronisation concessionnaires terminée: "
                     f"{created_count} créés, {updated_count} mis à jour, {error_count} erreurs"
            )
            
            return True
            
        except Exception as e:
            log.write({
                'state': 'error',
                'end_date': fields.Datetime.now(),
                'error_message': str(e),
            })
            self._handle_error(f"Erreur sync concessionnaires: {str(e)}")
            return False
    
    def _process_concessionnaire(self, data):
        """Traiter les données d'un concessionnaire"""
        Concessionnaire = self.env['hurimoney.concessionnaire']
        
        # Mapper les champs
        field_map = json.loads(self.field_mapping or '{}')
        
        # Rechercher par code externe
        code = data.get(field_map.get('code', 'code'))
        if not code:
            raise ValueError("Code concessionnaire manquant")
        
        concessionnaire = Concessionnaire.search([
            ('code', '=', code)
        ], limit=1)
        
        # Préparer les valeurs
        vals = {
            'name': data.get(field_map.get('name', 'name')),
            'phone': data.get(field_map.get('phone', 'phone')),
            'email': data.get(field_map.get('email', 'email')),
            'street': data.get(field_map.get('street', 'address')),
            'city': data.get(field_map.get('city', 'city')),
            'latitude': data.get(field_map.get('latitude', 'latitude')),
            'longitude': data.get(field_map.get('longitude', 'longitude')),
            'zone': data.get(field_map.get('zone', 'zone'), 'moroni'),
        }
        
        # État
        is_active = data.get(field_map.get('is_active', 'is_active'), True)
        if is_active and data.get('state') == 'active':
            vals['state'] = 'active'
        elif not is_active:
            vals['state'] = 'inactive'
        
        if concessionnaire:
            # Mise à jour
            concessionnaire.write(vals)
            return 'updated'
        else:
            # Création
            # Créer le contact d'abord
            partner_vals = {
                'name': vals['name'],
                'phone': vals['phone'],
                'email': vals.get('email'),
                'street': vals.get('street'),
                'city': vals.get('city'),
                'country_id': self.env.ref('base.km').id,
            }
            partner = self.env['res.partner'].create(partner_vals)
            
            vals.update({
                'partner_id': partner.id,
                'code': code,
            })
            
            Concessionnaire.create(vals)
            return 'created'
    
    def sync_transactions(self):
        """Synchroniser les transactions depuis WAKATI"""
        self.ensure_one()
        
        if not self.sync_transactions:
            return True
        
        # Créer un log
        log = self.env['wakati.sync.log'].create({
            'connector_id': self.id,
            'sync_type': 'transactions',
            'start_date': fields.Datetime.now(),
        })
        
        try:
            # Paramètres de requête
            params = {}
            if self.last_sync_date:
                params['from_date'] = self.last_sync_date.isoformat()
            else:
                # Par défaut, synchroniser les 7 derniers jours
                params['from_date'] = (fields.Datetime.now() - timedelta(days=7)).isoformat()
            
            # Récupérer les transactions
            result = self._make_api_request('transactions', params=params)
            
            if not result:
                log.write({
                    'state': 'error',
                    'end_date': fields.Datetime.now(),
                    'error_message': self.last_error_message,
                })
                return False
            
            created_count = 0
            updated_count = 0
            error_count = 0
            
            for trans_data in result.get('data', []):
                try:
                    processed = self._process_transaction(trans_data)
                    if processed == 'created':
                        created_count += 1
                    elif processed == 'updated':
                        updated_count += 1
                    elif processed == 'skipped':
                        pass  # Transaction déjà existante
                except Exception as e:
                    error_count += 1
                    _logger.error(f"Erreur traitement transaction {trans_data.get('id')}: {str(e)}")
            
            # Mettre à jour le log
            log.write({
                'state': 'done',
                'end_date': fields.Datetime.now(),
                'records_created': created_count,
                'records_updated': updated_count,
                'records_failed': error_count,
            })
            
            # Message de succès
            self.message_post(
                body=f"✅ Synchronisation transactions terminée: "
                     f"{created_count} créées, {updated_count} mises à jour, {error_count} erreurs"
            )
            
            return True
            
        except Exception as e:
            log.write({
                'state': 'error',
                'end_date': fields.Datetime.now(),
                'error_message': str(e),
            })
            self._handle_error(f"Erreur sync transactions: {str(e)}")
            return False
    
    def _process_transaction(self, data):
        """Traiter les données d'une transaction"""
        Transaction = self.env['hurimoney.transaction']
        
        # Vérifier si la transaction existe déjà
        external_id = str(data.get('id'))
        existing = Transaction.search([
            ('external_id', '=', external_id)
        ], limit=1)
        
        if existing:
            return 'skipped'
        
        # Trouver le concessionnaire
        conc_code = data.get('concessionnaire_code')
        if not conc_code:
            raise ValueError("Code concessionnaire manquant dans la transaction")
        
        concessionnaire = self.env['hurimoney.concessionnaire'].search([
            ('code', '=', conc_code)
        ], limit=1)
        
        if not concessionnaire:
            # Essayer de créer le concessionnaire si on a les infos
            if data.get('concessionnaire_data'):
                self._process_concessionnaire(data['concessionnaire_data'])
                concessionnaire = self.env['hurimoney.concessionnaire'].search([
                    ('code', '=', conc_code)
                ], limit=1)
            
            if not concessionnaire:
                raise ValueError(f"Concessionnaire {conc_code} introuvable")
        
        # Créer la transaction
        trans_vals = {
            'concessionnaire_id': concessionnaire.id,
            'transaction_date': data.get('date'),
            'transaction_type': data.get('type', 'deposit'),
            'amount': float(data.get('amount', 0)),
            'customer_name': data.get('customer_name'),
            'customer_phone': data.get('customer_phone'),
            'external_id': external_id,
            'state': 'done' if data.get('status') == 'completed' else 'pending',
        }
        
        # Commission
        if data.get('commission'):
            trans_vals['commission'] = float(data['commission'])
        elif data.get('commission_rate'):
            trans_vals['commission_rate'] = float(data['commission_rate'])
        
        Transaction.create(trans_vals)
        return 'created'
    
    def sync_kits(self):
        """Synchroniser les kits depuis WAKATI"""
        self.ensure_one()
        
        if not self.sync_kits:
            return True
        
        # Créer un log
        log = self.env['wakati.sync.log'].create({
            'connector_id': self.id,
            'sync_type': 'kits',
            'start_date': fields.Datetime.now(),
        })
        
        try:
            # Récupérer les kits
            result = self._make_api_request('kits')
            
            if not result:
                log.write({
                    'state': 'error',
                    'end_date': fields.Datetime.now(),
                    'error_message': self.last_error_message,
                })
                return False
            
            created_count = 0
            updated_count = 0
            error_count = 0
            
            for kit_data in result.get('data', []):
                try:
                    processed = self._process_kit(kit_data)
                    if processed == 'created':
                        created_count += 1
                    elif processed == 'updated':
                        updated_count += 1
                except Exception as e:
                    error_count += 1
                    _logger.error(f"Erreur traitement kit {kit_data.get('serial')}: {str(e)}")
            
            # Mettre à jour le log
            log.write({
                'state': 'done',
                'end_date': fields.Datetime.now(),
                'records_created': created_count,
                'records_updated': updated_count,
                'records_failed': error_count,
            })
            
            return True
            
        except Exception as e:
            log.write({
                'state': 'error',
                'end_date': fields.Datetime.now(),
                'error_message': str(e),
            })
            self._handle_error(f"Erreur sync kits: {str(e)}")
            return False
    
    def _process_kit(self, data):
        """Traiter les données d'un kit"""
        Kit = self.env['hurimoney.kit']
        
        # Rechercher par numéro de série
        serial = data.get('serial_number')
        if not serial:
            raise ValueError("Numéro de série manquant")
        
        kit = Kit.search([
            ('serial_number', '=', serial)
        ], limit=1)
        
        # Trouver le concessionnaire
        conc_code = data.get('concessionnaire_code')
        concessionnaire = False
        if conc_code:
            concessionnaire = self.env['hurimoney.concessionnaire'].search([
                ('code', '=', conc_code)
            ], limit=1)
        
        # Préparer les valeurs
        vals = {
            'kit_type': data.get('type', 'standard'),
            'phone_model': data.get('phone_model'),
            'phone_imei': data.get('imei'),
            'phone_cost': float(data.get('phone_cost', 0)),
            'kit_cost': float(data.get('kit_cost', 0)),
            'delivery_date': data.get('delivery_date'),
            'state': data.get('state', 'draft'),
        }
        
        if concessionnaire:
            vals['concessionnaire_id'] = concessionnaire.id
        
        if kit:
            kit.write(vals)
            return 'updated'
        else:
            vals['serial_number'] = serial
            Kit.create(vals)
            return 'created'
    
    def sync_all(self):
        """Synchroniser toutes les données"""
        self.ensure_one()
        
        success = True
        
        # Synchroniser dans l'ordre
        if self.sync_concessionnaires:
            success = success and self.sync_concessionnaires()
        
        if self.sync_kits:
            success = success and self.sync_kits()
        
        if self.sync_transactions:
            success = success and self.sync_transactions()
        
        # Mettre à jour la date de dernière sync
        if success:
            self.write({
                'last_sync_date': fields.Datetime.now(),
                'sync_success_count': self.sync_success_count + 1,
            })
        
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Synchronisation terminée' if success else 'Synchronisation échouée',
                'message': 'Les données ont été synchronisées avec succès' if success else 'Des erreurs sont survenues',
                'type': 'success' if success else 'warning',
                'sticky': False,
            }
        }
    
    @api.model
    def cron_sync_wakati(self):
        """Méthode appelée par le cron pour la synchronisation automatique"""
        connectors = self.search([
            ('auto_sync', '=', True),
            ('state', '=', 'connected')
        ])
        
        for connector in connectors:
            try:
                # Vérifier l'intervalle
                if connector.last_sync_date:
                    hours_since_sync = (fields.Datetime.now() - connector.last_sync_date).total_seconds() / 3600
                    if hours_since_sync < connector.sync_interval:
                        continue
                
                connector.sync_all()
                
            except Exception as e:
                _logger.error(f"Erreur cron sync WAKATI {connector.name}: {str(e)}")
                connector._handle_error(f"Erreur synchronisation automatique: {str(e)}")
    
    def action_view_logs(self):
        """Voir les logs de synchronisation"""
        self.ensure_one()
        
        return {
            'name': 'Logs de synchronisation',
            'type': 'ir.actions.act_window',
            'res_model': 'wakati.sync.log',
            'view_mode': 'tree,form',
            'domain': [('connector_id', '=', self.id)],
            'context': {'default_connector_id': self.id},
        }
    
    def action_clear_logs(self):
        """Effacer les anciens logs"""
        self.ensure_one()
        
        # Garder seulement les logs des 30 derniers jours
        date_limit = fields.Datetime.now() - timedelta(days=30)
        old_logs = self.log_ids.filtered(lambda l: l.create_date < date_limit)
        old_logs.unlink()
        
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Logs nettoyés',
                'message': f'{len(old_logs)} anciens logs supprimés',
                'type': 'success',
            }
        }


class WakatiSyncLog(models.Model):
    _name = 'wakati.sync.log'
    _description = 'Log de synchronisation WAKATI'
    _order = 'create_date desc'
    
    connector_id = fields.Many2one('wakati.api.connector', string='Connecteur', required=True, ondelete='cascade')
    sync_type = fields.Selection([
        ('concessionnaires', 'Concessionnaires'),
        ('transactions', 'Transactions'),
        ('kits', 'Kits'),
        ('all', 'Tout'),
    ], string='Type de sync', required=True)
    
    start_date = fields.Datetime(string='Début', required=True)
    end_date = fields.Datetime(string='Fin')
    duration = fields.Float(string='Durée (sec)', compute='_compute_duration', store=True)
    
    state = fields.Selection([
        ('running', 'En cours'),
        ('done', 'Terminé'),
        ('error', 'Erreur'),
    ], string='État', default='running')
    
    records_created = fields.Integer(string='Créés')
    records_updated = fields.Integer(string='Mis à jour')
    records_failed = fields.Integer(string='Échecs')
    
    error_message = fields.Text(string='Message d\'erreur')
    
    @api.depends('start_date', 'end_date')
    def _compute_duration(self):
        for record in self:
            if record.start_date and record.end_date:
                delta = record.end_date - record.start_date
                record.duration = delta.total_seconds()
            else:
                record.duration = 0