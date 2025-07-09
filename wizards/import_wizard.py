# -*- coding: utf-8 -*-
import base64
import csv
import io
import json
import logging
from odoo import models, fields, api
from odoo.exceptions import UserError

_logger = logging.getLogger(__name__)

class HuriMoneyImportWizard(models.TransientModel):
    _name = 'hurimoney.import.wizard'
    _description = 'Assistant d\'import HuriMoney'
    
    import_type = fields.Selection([
        ('concessionnaires', 'Concessionnaires'),
        ('transactions', 'Transactions'),
        ('kits', 'Kits'),
    ], string='Type d\'import', required=True, default='concessionnaires')
    
    file = fields.Binary(string='Fichier', required=True)
    filename = fields.Char(string='Nom du fichier')
    delimiter = fields.Selection([
        (',', 'Virgule (,)'),
        (';', 'Point-virgule (;)'),
        ('\t', 'Tabulation'),
        ('|', 'Pipe (|)'),
    ], string='Séparateur', default=',')
    
    # Résultats
    imported_count = fields.Integer(string='Importés', readonly=True)
    error_count = fields.Integer(string='Erreurs', readonly=True)
    error_log = fields.Text(string='Journal des erreurs', readonly=True)
    
    def action_import(self):
        """Lancer l'import selon le type sélectionné"""
        if self.import_type == 'concessionnaires':
            return self._import_concessionnaires()
        elif self.import_type == 'transactions':
            return self._import_transactions()
        elif self.import_type == 'kits':
            return self._import_kits()
    
    def _import_concessionnaires(self):
        """Importer des concessionnaires depuis un fichier CSV"""
        try:
            # Décoder le fichier
            csv_data = base64.b64decode(self.file)
            data_file = io.StringIO(csv_data.decode("utf-8"))
            csv_reader = csv.DictReader(data_file, delimiter=self.delimiter)
            
            imported = 0
            errors = []
            
            for row_num, row in enumerate(csv_reader, 1):
                try:
                    # Vérifier les champs requis
                    required_fields = ['name', 'phone']
                    missing_fields = [f for f in required_fields if not row.get(f)]
                    if missing_fields:
                        errors.append(f"Ligne {row_num}: Champs manquants {missing_fields}")
                        continue
                    
                    # Créer ou mettre à jour le contact
                    partner_vals = {
                        'name': row['name'],
                        'phone': row['phone'],
                        'email': row.get('email'),
                        'street': row.get('street'),
                        'city': row.get('city'),
                    }
                    
                    partner = self.env['res.partner'].search([
                        ('phone', '=', row['phone'])
                    ], limit=1)
                    
                    if partner:
                        partner.write(partner_vals)
                    else:
                        partner = self.env['res.partner'].create(partner_vals)
                    
                    # Créer ou mettre à jour le concessionnaire
                    conc_vals = {
                        'partner_id': partner.id,
                        'name': row['name'],
                        'phone': row['phone'],
                        'email': row.get('email'),
                        'zone': row.get('zone', 'moroni'),
                        'street': row.get('street'),
                        'city': row.get('city'),
                    }
                    
                    # Gérer l'agent commercial
                    if row.get('agent_email'):
                        agent = self.env['res.users'].search([
                            ('email', '=', row['agent_email'])
                        ], limit=1)
                        if agent:
                            conc_vals['agent_id'] = agent.id
                    
                    concessionnaire = self.env['hurimoney.concessionnaire'].search([
                        ('phone', '=', row['phone'])
                    ], limit=1)
                    
                    if concessionnaire:
                        concessionnaire.write(conc_vals)
                    else:
                        conc_vals['state'] = 'draft'
                        self.env['hurimoney.concessionnaire'].create(conc_vals)
                    
                    imported += 1
                    
                except Exception as e:
                    errors.append(f"Ligne {row_num}: {str(e)}")
            
            # Enregistrer les résultats
            self.imported_count = imported
            self.error_count = len(errors)
            self.error_log = '\n'.join(errors) if errors else 'Aucune erreur'
            
            # Message de succès
            message = f"{imported} concessionnaire(s) importé(s) avec succès."
            if errors:
                message += f" {len(errors)} erreur(s) rencontrée(s)."
            
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'Import terminé',
                    'message': message,
                    'type': 'success' if not errors else 'warning',
                    'sticky': False,
                }
            }
            
        except Exception as e:
            raise UserError(f"Erreur lors de l'import: {str(e)}")
    
    def _import_transactions(self):
        """Importer des transactions depuis un fichier CSV"""
        try:
            # Décoder le fichier
            csv_data = base64.b64decode(self.file)
            data_file = io.StringIO(csv_data.decode("utf-8"))
            csv_reader = csv.DictReader(data_file, delimiter=self.delimiter)
            
            imported = 0
            errors = []
            
            for row_num, row in enumerate(csv_reader, 1):
                try:
                    # Vérifier les champs requis
                    required_fields = ['concessionnaire_code', 'amount', 'transaction_type']
                    missing_fields = [f for f in required_fields if not row.get(f)]
                    if missing_fields:
                        errors.append(f"Ligne {row_num}: Champs manquants {missing_fields}")
                        continue
                    
                    # Trouver le concessionnaire
                    concessionnaire = self.env['hurimoney.concessionnaire'].search([
                        ('code', '=', row['concessionnaire_code'])
                    ], limit=1)
                    
                    if not concessionnaire:
                        errors.append(f"Ligne {row_num}: Concessionnaire {row['concessionnaire_code']} introuvable")
                        continue
                    
                    # Créer la transaction
                    trans_vals = {
                        'concessionnaire_id': concessionnaire.id,
                        'amount': float(row['amount']),
                        'transaction_type': row['transaction_type'],
                        'transaction_date': row.get('date', fields.Datetime.now()),
                        'customer_name': row.get('customer_name'),
                        'customer_phone': row.get('customer_phone'),
                        'external_id': row.get('external_id'),
                        'state': 'done',
                    }
                    
                    # Vérifier si la transaction existe déjà
                    if row.get('external_id'):
                        existing = self.env['hurimoney.transaction'].search([
                            ('external_id', '=', row['external_id'])
                        ], limit=1)
                        if existing:
                            existing.write(trans_vals)
                        else:
                            self.env['hurimoney.transaction'].create(trans_vals)
                    else:
                        self.env['hurimoney.transaction'].create(trans_vals)
                    
                    imported += 1
                    
                except Exception as e:
                    errors.append(f"Ligne {row_num}: {str(e)}")
            
            # Enregistrer les résultats
            self.imported_count = imported
            self.error_count = len(errors)
            self.error_log = '\n'.join(errors) if errors else 'Aucune erreur'
            
            # Message de succès
            message = f"{imported} transaction(s) importée(s) avec succès."
            if errors:
                message += f" {len(errors)} erreur(s) rencontrée(s)."
            
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'Import terminé',
                    'message': message,
                    'type': 'success' if not errors else 'warning',
                    'sticky': False,
                }
            }
            
        except Exception as e:
            raise UserError(f"Erreur lors de l'import: {str(e)}")
    
    def _import_kits(self):
        """Importer des kits depuis un fichier CSV"""
        try:
            # Décoder le fichier
            csv_data = base64.b64decode(self.file)
            data_file = io.StringIO(csv_data.decode("utf-8"))
            csv_reader = csv.DictReader(data_file, delimiter=self.delimiter)
            
            imported = 0
            errors = []
            
            for row_num, row in enumerate(csv_reader, 1):
                try:
                    # Vérifier les champs requis
                    required_fields = ['serial_number', 'concessionnaire_code']
                    missing_fields = [f for f in required_fields if not row.get(f)]
                    if missing_fields:
                        errors.append(f"Ligne {row_num}: Champs manquants {missing_fields}")
                        continue
                    
                    # Trouver le concessionnaire
                    concessionnaire = self.env['hurimoney.concessionnaire'].search([
                        ('code', '=', row['concessionnaire_code'])
                    ], limit=1)
                    
                    if not concessionnaire:
                        errors.append(f"Ligne {row_num}: Concessionnaire {row['concessionnaire_code']} introuvable")
                        continue
                    
                    # Créer ou mettre à jour le kit
                    kit_vals = {
                        'serial_number': row['serial_number'],
                        'concessionnaire_id': concessionnaire.id,
                        'kit_type': row.get('kit_type', 'standard'),
                        'phone_model': row.get('phone_model'),
                        'phone_imei': row.get('phone_imei'),
                        'phone_cost': float(row.get('phone_cost', 0)),
                        'kit_cost': float(row.get('kit_cost', 0)),
                        'delivery_date': row.get('delivery_date', fields.Date.today()),
                        'state': row.get('state', 'draft'),
                    }
                    
                    # Vérifier si le kit existe déjà
                    existing = self.env['hurimoney.kit'].search([
                        ('serial_number', '=', row['serial_number'])
                    ], limit=1)
                    
                    if existing:
                        existing.write(kit_vals)
                    else:
                        self.env['hurimoney.kit'].create(kit_vals)
                    
                    imported += 1
                    
                except Exception as e:
                    errors.append(f"Ligne {row_num}: {str(e)}")
            
            # Enregistrer les résultats
            self.imported_count = imported
            self.error_count = len(errors)
            self.error_log = '\n'.join(errors) if errors else 'Aucune erreur'
            
            # Message de succès
            message = f"{imported} kit(s) importé(s) avec succès."
            if errors:
                message += f" {len(errors)} erreur(s) rencontrée(s)."
            
            return {
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'title': 'Import terminé',
                    'message': message,
                    'type': 'success' if not errors else 'warning',
                    'sticky': False,
                }
            }
            
        except Exception as e:
            raise UserError(f"Erreur lors de l'import: {str(e)}")