#!/bin/bash

# Script pour corriger le déploiement sur le serveur AWS et tester le module

echo "🔧 Correction du déploiement sur le serveur AWS..."

SERVER_IP="13.51.48.109"
SSH_KEY="~/.ssh/hurimoney-key.pem"

# Connexion au serveur pour corriger le script de déploiement
echo "📋 Correction du script de déploiement sur le serveur..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << 'EOF'
    # Passer en root
    sudo su - << 'ROOT_EOF'

# Corriger le script de déploiement
echo "🔧 Correction du script /opt/deploy_module.sh..."
cat > /opt/deploy_module.sh << 'DEPLOY_EOF'
#!/bin/bash

# Script de déploiement du module hurimoney_concessionnaires
echo "🚀 Déploiement du module hurimoney_concessionnaires..."

# Aller dans le répertoire du module
cd /mnt/extra-addons/hurimoney_concessionnaires || exit 1

# Mettre à jour depuis GitHub
echo "📥 Mise à jour depuis GitHub..."
git pull origin main

# Redémarrer Odoo pour recharger le module
echo "🔄 Redémarrage d'Odoo..."
systemctl restart odoo

# Attendre le redémarrage
sleep 10

# Vérifier le statut
echo "📊 Vérification du statut..."
systemctl status odoo --no-pager -l

echo "✅ Déploiement terminé!"
echo "🌐 Accès: http://$(curl -s ifconfig.me):8069"
DEPLOY_EOF

# Rendre le script exécutable
chmod +x /opt/deploy_module.sh

echo "✅ Script de déploiement corrigé"

# Nettoyer et réinstaller le module
echo "🧹 Nettoyage et réinstallation du module..."

# Arrêter Odoo
systemctl stop odoo

# Nettoyer les modules dupliqués depuis PostgreSQL
echo "🗑️ Nettoyage des modules dupliqués..."
export PGPASSWORD="OdooPassword2024"
psql -h odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com -p 5432 -U odoo -d odoo -c "
DELETE FROM ir_module_module WHERE name LIKE '%hurimoney%';
DELETE FROM ir_model_data WHERE module LIKE '%hurimoney%';
"

# Mettre à jour le module depuis GitHub
echo "📥 Mise à jour du module depuis GitHub..."
cd /mnt/extra-addons/hurimoney_concessionnaires
git pull origin main

# Redémarrer Odoo
echo "🚀 Redémarrage d'Odoo..."
systemctl start odoo

# Attendre le démarrage complet
sleep 15

# Vérifier le statut
echo "📊 Statut du service:"
systemctl status odoo --no-pager -l

echo ""
echo "📋 Logs récents:"
tail -n 20 /var/log/odoo/odoo.log

echo ""
echo "🎉 Correction terminée!"
echo "🌐 Testez l'accès: http://$(curl -s ifconfig.me):8069"
echo "📋 Pour installer le module:"
echo "  1. Créer une nouvelle base de données"
echo "  2. Aller dans Apps → Update Apps List"
echo "  3. Rechercher 'hurimoney' et installer"

ROOT_EOF
EOF

echo ""
echo "✅ Correction du serveur terminée!"
echo ""
echo "🧪 Test du webhook..."
curl -X POST http://$SERVER_IP:9000/deploy -H "Content-Type: application/json" -d '{"ref": "refs/heads/main"}'
echo ""
echo ""
echo "🌐 URLs importantes:"
echo "  Odoo: http://$SERVER_IP:8069"
echo "  Webhook: http://$SERVER_IP:9000/deploy"
echo "  SSH: ssh -i $SSH_KEY ubuntu@$SERVER_IP"