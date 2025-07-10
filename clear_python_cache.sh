#!/bin/bash

# Script pour nettoyer le cache Python et relancer Odoo

echo "🧹 Nettoyage du cache Python et relancement d'Odoo..."

SERVER_IP="13.51.48.109"
SSH_KEY="~/.ssh/hurimoney-key.pem"

# Connexion au serveur pour nettoyer le cache
echo "🗑️ Nettoyage du cache Python..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << 'EOF'
    # Passer en root
    sudo su - << 'ROOT_EOF'

# Arrêter Odoo complètement
echo "⏸️ Arrêt complet d'Odoo..."
systemctl stop odoo
sleep 5

# Nettoyer complètement le cache Python
echo "🧹 Nettoyage du cache Python..."
find /mnt/extra-addons/hurimoney_concessionnaires -name "*.pyc" -delete
find /mnt/extra-addons/hurimoney_concessionnaires -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Vérifier que les fichiers sont bien corrigés
echo "🔍 Vérification des fichiers corrigés:"
echo "--- models/__init__.py ---"
cat /mnt/extra-addons/hurimoney_concessionnaires/models/__init__.py
echo ""
echo "--- models/sms_integration.py ---"
cat /mnt/extra-addons/hurimoney_concessionnaires/models/sms_integration.py
echo ""

# Nettoyer les logs pour avoir un démarrage propre
echo "🗑️ Nettoyage des logs..."
> /var/log/odoo/odoo.log

# Redémarrer Odoo
echo "🚀 Redémarrage d'Odoo..."
systemctl start odoo

# Attendre le démarrage complet
echo "⏳ Attente du démarrage complet..."
sleep 30

# Vérifier le statut
echo "📊 Statut du service:"
systemctl status odoo --no-pager -l

echo ""
echo "📋 Logs récents (nouvelles entrées):"
tail -n 30 /var/log/odoo/odoo.log

echo ""
echo "🎉 Nettoyage et redémarrage terminés!"
echo "🌐 Testez l'accès: http://$(curl -s ifconfig.me):8069"

ROOT_EOF
EOF

echo ""
echo "✅ Nettoyage du cache terminé!"
echo "🌐 Accès Odoo: http://$SERVER_IP:8069"
echo ""
echo "📋 Prochaines étapes:"
echo "1. Accéder à http://$SERVER_IP:8069"
echo "2. Créer une nouvelle base de données"
echo "3. Aller dans Apps → Update Apps List"
echo "4. Rechercher 'hurimoney' et installer"