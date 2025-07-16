# -*- coding: utf-8 -*-
from odoo import models, fields, api
from datetime import datetime

class SaleOrder(models.Model):
    _inherit = 'sale.order'
    
    # Données agrégées depuis la segmentation B2C (pas de lien direct)
    # Les transactions individuelles restent dans le core banking
    
    x_b2c_segment = fields.Selection(
        related='partner_id.x_b2c_segment',
        string='Segment Client B2C',
        readonly=True,
        store=True
    )
    
    x_customer_score = fields.Float(
        related='partner_id.x_customer_score',
        string='Score Client',
        readonly=True,
        store=True
    )
    
    x_is_high_potential = fields.Boolean(
        related='partner_id.x_is_high_potential',
        string='Client à Fort Potentiel',
        readonly=True,
        store=True
    )
    
    x_hurimoney_volume = fields.Monetary(
        string='Volume HuriMoney Client',
        related='partner_id.x_total_amount',
        readonly=True,
        help='Volume total des transactions du client (depuis segmentation B2C)'
    )
    
    x_hurimoney_transaction_count = fields.Integer(
        string='Nombre Transactions',
        related='partner_id.x_total_transactions',
        readonly=True,
        help='Nombre total de transactions du client'
    )
    
    def action_confirm(self):
        """Surcharger la confirmation pour créer les écritures comptables"""
        result = super().action_confirm()
        
        # Créer automatiquement une écriture comptable pour les clients B2C à fort potentiel
        for order in self:
            if order.x_is_high_potential and order.x_hurimoney_volume > 500000:
                order._create_b2c_accounting_entries()
        
        return result
    
    def _create_b2c_accounting_entries(self):
        """Créer les écritures comptables pour les clients B2C à fort potentiel"""
        self.ensure_one()
        
        # Estimation de la commission potentielle basée sur la segmentation
        estimated_commission = float(self.x_hurimoney_volume) * 0.015  # 1.5% estimation
        
        if estimated_commission > 1000:  # Seuil minimum
            account_move = self.env['account.move'].create({
                'move_type': 'entry',
                'date': fields.Date.today(),
                'ref': f'Commission estimée B2C - {self.name}',
                'line_ids': [
                    (0, 0, {
                        'name': f'Commission estimée B2C - {self.partner_id.name} (Segment: {self.x_b2c_segment})',
                        'account_id': self.env.ref('account.data_account_type_revenue').id,
                        'credit': estimated_commission,
                    }),
                    (0, 0, {
                        'name': f'Créance commission B2C - {self.partner_id.name}',
                        'account_id': self.env.ref('account.data_account_type_receivable').id,
                        'debit': estimated_commission,
                        'partner_id': self.partner_id.id,
                    }),
                ],
            })
            
            # Valider automatiquement l'écriture
            account_move.action_post()
            
            # Lier l'écriture à la commande
            self.message_post(
                body=f"""
                Écriture comptable B2C créée:
                - Référence: {account_move.name}
                - Montant: {estimated_commission:,.2f}
                - Segment: {self.x_b2c_segment}
                - Volume client: {self.x_hurimoney_volume:,.2f}
                - Transactions: {self.x_hurimoney_transaction_count}
                """,
                subject="Commission B2C"
            )