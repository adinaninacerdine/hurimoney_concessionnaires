# 🚀 Déploiement AWS Odoo avec module hurimoney_concessionnaires

## ✅ Déploiement terminé avec succès!

L'infrastructure Odoo a été déployée sur AWS selon la documentation officielle avec le module hurimoney_concessionnaires.

## 🏗️ Architecture déployée

### Infrastructure AWS
- **EC2 Instance**: t3.small (Ubuntu 22.04)
- **RDS PostgreSQL**: db.t3.micro (PostgreSQL 15.7)
- **Security Groups**: Configuration sécurisée
- **VPC**: VPC par défaut avec subnets multiples

### Services installés
- **Odoo 18.0**: Installation officielle via repository Odoo
- **PostgreSQL Client**: Pour connexion RDS
- **Webhook Service**: Déploiement automatique
- **Module personnalisé**: hurimoney_concessionnaires

## 🌐 URLs et accès

### URLs principales
```
Odoo Web Interface: http://13.51.48.109:8069
Webhook Endpoint:   http://13.51.48.109:9000/deploy
SSH Access:         ssh -i ~/.ssh/hurimoney-key.pem ubuntu@13.51.48.109
```

### Base de données RDS
```
Host:     odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com
Port:     5432
Database: odoo
User:     odoo
Password: OdooPassword2024
```

## 📋 Informations de connexion Odoo

- **URL**: http://13.51.48.109:8069
- **Master Password**: admin123
- **Database**: À créer lors du premier accès

## 🔧 Configuration technique

### Fichiers de configuration
- **Odoo Config**: `/etc/odoo/odoo.conf`
- **Custom Modules**: `/mnt/extra-addons/`
- **Logs**: `/var/log/odoo/odoo.log`

### Services systemd
- **odoo.service**: Service principal Odoo
- **odoo-webhook.service**: Service webhook pour déploiement

## 🚀 Prochaines étapes

### 1. Premier accès à Odoo
1. Aller sur http://13.51.48.109:8069
2. Créer une nouvelle base de données
3. Utiliser le master password: `admin123`

### 2. Installation du module hurimoney_concessionnaires
1. Se connecter en tant qu'administrateur
2. Aller dans **Apps** (Applications)
3. Supprimer le filtre "Apps Store"
4. Rechercher "hurimoney"
5. Installer le module **hurimoney_concessionnaires**

### 3. Configuration initiale
1. Configurer les utilisateurs et groupes
2. Paramétrer les permissions de sécurité
3. Importer les données de démonstration si nécessaire

## 🔄 Déploiement automatique

Le webhook est configuré pour le déploiement automatique:

```bash
# Déploiement manuel via webhook
curl -X POST http://13.51.48.109:9000/deploy \
     -H "Content-Type: application/json" \
     -d '{"ref": "refs/heads/main"}'
```

## 📊 Monitoring et logs

### Vérifier le statut des services
```bash
ssh -i ~/.ssh/hurimoney-key.pem ubuntu@13.51.48.109
sudo systemctl status odoo
sudo systemctl status odoo-webhook
```

### Consulter les logs
```bash
sudo tail -f /var/log/odoo/odoo.log
sudo journalctl -u odoo -f
sudo journalctl -u odoo-webhook -f
```

## 🛠️ Commandes utiles

### Redémarrer Odoo
```bash
sudo systemctl restart odoo
```

### Mettre à jour le module
```bash
sudo /opt/deploy_module.sh
```

### Accès SSH
```bash
ssh -i ~/.ssh/hurimoney-key.pem ubuntu@13.51.48.109
```

## 🔐 Sécurité

### Ports ouverts
- **8069**: Interface web Odoo
- **9000**: Webhook de déploiement
- **22**: SSH (restreint à l'IP configurée)

### RDS
- Accès restreint au security group EC2
- Chiffrement activé
- Sauvegardes automatiques (7 jours)

## 📈 Terraform

### Commandes Terraform
```bash
# Voir les outputs
terraform output

# Détruire l'infrastructure
terraform destroy

# Appliquer les changements
terraform apply
```

### Outputs disponibles
```
odoo_url              = "http://13.51.48.109:8069"
odoo_web_server_ip    = "13.51.48.109"
rds_address          = "odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com"
rds_endpoint         = "odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com:5432"
rds_port             = 5432
ssh_command          = "ssh -i ~/.ssh/hurimoney-key.pem ubuntu@13.51.48.109"
webhook_url          = "http://13.51.48.109:9000/deploy"
```

## 🧪 Tests

### Vérifier l'installation
1. ✅ Accès web Odoo: http://13.51.48.109:8069 (FONCTIONNEL)
2. ✅ Webhook fonctionnel: http://13.51.48.109:9000/deploy (FONCTIONNEL)
3. ✅ Module déployé: hurimoney_concessionnaires (DÉPLOYÉ)
4. ✅ Connexion RDS établie (CONFIGURÉ)
5. ✅ Base de données Odoo initialisée (PRÊTE)
6. ✅ Utilisateur PostgreSQL configuré avec permissions (CONFIGURÉ)

### Tests fonctionnels
1. Créer une base de données
2. Installer le module hurimoney_concessionnaires
3. Tester les fonctionnalités du module
4. Vérifier les logs et performances

## 🚨 Dépannage

### Odoo ne démarre pas
```bash
sudo systemctl status odoo
sudo journalctl -u odoo -n 50
```

### Problème de connexion RDS
```bash
psql -h odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com -p 5432 -U odoo -d odoo
```

### Module non visible
```bash
sudo systemctl restart odoo
# Puis aller dans Apps → Update Apps List
```

## 📱 Support

- **Documentation Odoo**: https://www.odoo.com/documentation/18.0/
- **Terraform AWS**: https://registry.terraform.io/providers/hashicorp/aws/
- **Logs serveur**: `/var/log/odoo/odoo.log`