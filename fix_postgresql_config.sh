#!/bin/bash

# Script pour corriger la configuration PostgreSQL RDS et Odoo
echo "🔧 Configuration PostgreSQL RDS pour Odoo..."

RDS_ENDPOINT="odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com"
RDS_PASSWORD="OdooPassword2024"

# Se connecter à RDS et configurer l'utilisateur odoo
echo "👤 Configuration de l'utilisateur PostgreSQL odoo..."

# Créer le fichier pgpass pour éviter la saisie du mot de passe
cat > ~/.pgpass << EOF
$RDS_ENDPOINT:5432:*:odoo:$RDS_PASSWORD
$RDS_ENDPOINT:5432:postgres:odoo:$RDS_PASSWORD
EOF
chmod 600 ~/.pgpass

echo "📊 Connexion à RDS et configuration des permissions..."

# Se connecter à la base postgres pour créer l'utilisateur et la base
PGPASSWORD="$RDS_PASSWORD" psql -h $RDS_ENDPOINT -p 5432 -U odoo -d postgres << 'SQL_EOF'

-- Vérifier si l'utilisateur existe et ses permissions
\du odoo

-- Accorder les permissions nécessaires pour Odoo
ALTER USER odoo CREATEDB;
ALTER USER odoo CREATEROLE;

-- Créer la base de données odoo si elle n'existe pas
SELECT 'CREATE DATABASE odoo OWNER odoo' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'odoo')\gexec

-- Accorder toutes les permissions sur la base odoo
GRANT ALL PRIVILEGES ON DATABASE odoo TO odoo;

-- Se connecter à la base odoo et configurer les extensions
\c odoo

-- Créer les extensions nécessaires pour Odoo
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Accorder les permissions sur le schéma public
GRANT ALL ON SCHEMA public TO odoo;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO odoo;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO odoo;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO odoo;

-- Définir les permissions par défaut
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO odoo;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO odoo;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO odoo;

\q
SQL_EOF

if [ $? -eq 0 ]; then
    echo "✅ Configuration PostgreSQL réussie"
else
    echo "❌ Erreur lors de la configuration PostgreSQL"
    exit 1
fi

# Nettoyer le fichier pgpass
rm -f ~/.pgpass

echo "🎉 Configuration PostgreSQL terminée!"