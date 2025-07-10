#!/bin/bash

# Script pour corriger le module cloné sur le serveur

echo "🔧 Correction du module cloné sur le serveur..."

SERVER_IP="13.51.48.109"
SSH_KEY="~/.ssh/hurimoney-key.pem"

# Connexion au serveur pour corriger le module cloné
echo "📝 Correction des fichiers du module cloné..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << 'EOF'
    # Passer en root
    sudo su - << 'ROOT_EOF'

# Arrêter Odoo
systemctl stop odoo

# Aller dans le répertoire du module cloné
cd /mnt/extra-addons/hurimoney_concessionnaires

# Corriger models/__init__.py pour supprimer l'import sms_integration
cat > models/__init__.py << 'INIT_EOF'
from . import concessionnaire
from . import kit
from . import transaction
from . import dashboard
from . import res_config_settings
from . import wakati_connector
INIT_EOF

# Vider complètement sms_integration.py
cat > models/sms_integration.py << 'SMS_EOF'
# -*- coding: utf-8 -*-
# Module SMS désactivé - dépendances externes non disponibles
# Pour activer, installer: pip install twilio
SMS_EOF

echo "✅ Fichiers corrigés"
echo "📋 Vérification des fichiers corrigés:"
echo "--- models/__init__.py ---"
cat models/__init__.py
echo ""
echo "--- models/sms_integration.py ---"
cat models/sms_integration.py
echo ""

# Redémarrer Odoo
echo "🚀 Redémarrage d'Odoo..."
systemctl start odoo
sleep 15

# Vérifier le statut
echo "📊 Statut du service:"
systemctl status odoo --no-pager -l

echo ""
echo "📋 Logs récents (dernières 10 lignes):"
tail -n 10 /var/log/odoo/odoo.log

echo ""
echo "🎉 Correction terminée!"
echo "🌐 Testez l'accès: http://$(curl -s ifconfig.me):8069"

ROOT_EOF
EOF

echo ""
echo "✅ Correction du module cloné terminée!"
echo "🌐 Accès Odoo: http://$SERVER_IP:8069"