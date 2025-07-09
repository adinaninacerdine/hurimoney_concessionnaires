# -*- coding: utf-8 -*-
import logging
from twilio.rest import Client
from odoo import models, fields, api

_logger = logging.getLogger(__name__)

class SMSIntegration(models.Model):
    _name = 'hurimoney.sms.integration'
    _description = 'Intégration SMS HuriMoney'
    
    name = fields.Char(string='Nom', default='Configuration SMS')
    provider = fields.Selection([
        ('twilio', 'Twilio'),
        ('africastalking', 'Africa\'s Talking'),
        ('orange', 'Orange SMS API'),
    ], string='Fournisseur', default='twilio')
    
    # Configuration Twilio
    twilio_account_sid = fields.Char(string='Account SID')
    twilio_auth_token = fields.Char(string='Auth Token')
    twilio_from_number = fields.Char(string='Numéro expéditeur')
    
    # Statistiques
    sms_sent_count = fields.Integer(string='SMS envoyés', readonly=True)
    last_sms_date = fields.Datetime(string='Dernier SMS', readonly=True)
    
    @api.model
    def send_sms(self, to_number, message, concessionnaire_id=None):
        """Envoyer un SMS"""
        config = self.search([], limit=1)
        if not config:
            _logger.error("Aucune configuration SMS trouvée")
            return False
        
        if config.provider == 'twilio':
            return config._send_twilio_sms(to_number, message, concessionnaire_id)
        # Ajouter d'autres providers ici
        
        return False
    
    def _send_twilio_sms(self, to_number, message, concessionnaire_id=None):
        """Envoyer via Twilio"""
        try:
            client = Client(self.twilio_account_sid, self.twilio_auth_token)
            
            # Envoyer le message
            sms = client.messages.create(
                body=message,
                from_=self.twilio_from_number,
                to=to_number
            )
            
            # Enregistrer l'envoi
            self.env['hurimoney.sms.log'].create({
                'phone_number': to_number,
                'message': message,
                'concessionnaire_id': concessionnaire_id,
                'status': 'sent',
                'provider_id': sms.sid,
            })
            
            # Mettre à jour les stats
            self.write({
                'sms_sent_count': self.sms_sent_count + 1,
                'last_sms_date': fields.Datetime.now(),
            })
            
            return True
            
        except Exception as e:
            _logger.error(f"Erreur envoi SMS: {str(e)}")
            
            # Enregistrer l'échec
            self.env['hurimoney.sms.log'].create({
                'phone_number': to_number,
                'message': message,
                'concessionnaire_id': concessionnaire_id,
                'status': 'failed',
                'error_message': str(e),
            })
            
            return False

class SMSLog(models.Model):
    _name = 'hurimoney.sms.log'
    _description = 'Journal SMS'
    _order = 'create_date desc'
    
    phone_number = fields.Char(string='Numéro', required=True)
    message = fields.Text(string='Message', required=True)
    concessionnaire_id = fields.Many2one('hurimoney.concessionnaire', string='Concessionnaire')
    status = fields.Selection([
        ('sent', 'Envoyé'),
        ('failed', 'Échoué'),
    ], string='Statut')
    provider_id = fields.Char(string='ID Provider')
    error_message = fields.Text(string='Message d\'erreur')