# -*- coding: utf-8 -*-
from odoo import models, fields

class ResPartner(models.Model):
    _inherit = 'res.partner'

    x_b2c_segment = fields.Selection([
        ('HIGH_VALUE', 'Haute Valeur'),
        ('LOYAL', 'Fidèle'),
        ('NEW', 'Nouveau'),
        ('AT_RISK', 'À Risque'),
        ('OTHER', 'Autre')
    ], string='Segment B2C', help="Segment du client final calculé par le pipeline de données.", readonly=True, tracking=True)
