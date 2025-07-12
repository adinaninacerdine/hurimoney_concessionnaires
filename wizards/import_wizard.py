# -*- coding: utf-8 -*-
import base64
import csv
import io
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
    
    file = fields.Binary(string='Fichier CSV', required=True)
    filename = fields.Char(string='Nom du fichier')
    delimiter = fields.Selection([
        (',', 'Virgule (,)'),
        (';', 'Point-virgule (;)'),
        ('\t', 'Tabulation'),
        ('|', 'Pipe (|)'),
    ], string='Séparateur', default=',', required=True)
    
    # Résultats
    imported_count = fields.Integer(string='Importés', readonly=True)
    error_count = fields.Integer(string='Erreurs', readonly=True)
    error_log = fields.Text(string='Journal des erreurs', readonly=True)
    
    def action_import(self):
        """Lancer l'import selon le type sélectionné"""
        self.ensure_one()
        
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
                    if not row.get('name') or not row.get('phone'):
                        errors.append("Ligne %d: Nom et téléphone requis" % row_num)
                        continue
                    
                    # Créer ou mettre à jour le contact
                    partner_vals = {
                        'name': row['name'],
                        'phone': row['phone'],
                        'email': row.get('email', ''),
                        'street': row.get('street', ''),
                        'city': row.get('city', ''),
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
                        'email': row.get('email', ''),
                        'zone': row.get('zone', 'moroni'),
                        'street': row.get('street', ''),
                        'city': row.get('city', ''),
                    }
                    
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
                    errors.append("Ligne %d: %s" % (row_num, str(e)))
            
            # Enregistrer les résultats
            self.imported_count = imported
            self.error_count = len(errors)
            self.error_log = '\n'.join(errors) if errors else 'Aucune erreur'
            
            return {'type': 'ir.actions.do_nothing'}
            
        except Exception as e:
            raise UserError("Erreur lors de l'import: %s" % str(e))
    
    def _import_transactions(self):
        """Importer des transactions depuis un fichier CSV"""
        # Code similaire adapté pour les transactions
        raise UserError("Import des transactions en cours de développement")
    
    def _import_kits(self):
        """Importer des kits depuis un fichier CSV"""
        # Code similaire adapté pour les kits
        raise UserError("Import des kits en cours de développement")