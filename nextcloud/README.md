# 🚀 Nextcloud Hub 29 - Installation Docker + Traefik

## 📋 Vue d'ensemble

Cette installation Nextcloud Hub 29 utilise :
- **Docker Compose** pour l'orchestration
- **Traefik v2** comme reverse proxy
- **PostgreSQL 16** comme base de données
- **Redis 7** pour le cache et locking
- **Nginx** comme frontend pour PHP-FPM
- **OnlyOffice Document Server** pour l'édition collaborative de documents
- **Configuration officielle Nextcloud** (résout les problèmes OCS/OCM-provider)

## 🚀 Installation automatique (Recommandée)

### Installation en une commande

```bash
# Cloner le repository
git clone <votre-repo>
cd nextcloud

# Lancer l'installation automatique
./install.sh
```

Le script `install.sh` fait tout automatiquement :
- ✅ Vérifie les prérequis
- ✅ Configure les variables d'environnement
- ✅ Démarre les services Docker
- ✅ Installe Nextcloud
- ✅ Configure les applications
- ✅ Active le Dashboard
- ✅ **Applique les optimisations de sécurité** (migrations MIME, indices DB, Client Push)
- ✅ **Configure les en-têtes de sécurité** (HSTS, CSP, etc.)
- ✅ **Installe et configure OnlyOffice** automatiquement

**⚠️ Important :** Le script vous demandera d'éditer le fichier `.env` avec vos valeurs avant de continuer.

---

## 🛠️ Installation manuelle (Alternative)

### 1. Prérequis
- Docker et Docker Compose installés
- Traefik v2 configuré avec le réseau `traefik-public`
- Domaine configuré dans Traefik

### 2. Configuration initiale

```bash
# Cloner le repository
git clone <votre-repo>
cd nextcloud

# Copier et configurer les variables d'environnement
cp env.example .env
# Éditer .env avec vos valeurs :
# - POSTGRES_PASSWORD (mot de passe sécurisé)
# - NEXTCLOUD_ADMIN_USER (nom d'utilisateur admin)
# - NEXTCLOUD_ADMIN_PASSWORD (mot de passe admin)
# - NEXTCLOUD_DOMAIN (votre domaine)
# - ONLYOFFICE_JWT_SECRET (clé secrète OnlyOffice)
# - ONLYOFFICE_DB_PASSWORD (mot de passe DB OnlyOffice)
```

### 3. Démarrage des services

```bash
# Démarrer tous les services
docker compose up -d

# Vérifier que tous les containers sont UP
docker ps | grep foxaprod
```

### 4. Installation Nextcloud

```bash
# Attendre que les services soient prêts (30-60 secondes)
# Puis installer Nextcloud
alias occ='docker exec -u www-data foxaprod_nc_fpm php occ'

# Installation avec les variables du .env
occ maintenance:install \
  --database "pgsql" \
  --database-host "db" \
  --database-name "nextclouddb" \
  --database-user "nextcloud" \
  --database-pass "$(grep POSTGRES_PASSWORD .env | cut -d'=' -f2)" \
  --admin-user "$(grep NEXTCLOUD_ADMIN_USER .env | cut -d'=' -f2)" \
  --admin-pass "$(grep NEXTCLOUD_ADMIN_PASSWORD .env | cut -d'=' -f2)"
```

### 5. Configuration post-installation

```bash
# Optionnel : Copier la configuration avancée
cp config.php.example config.php
# Éditer config.php si nécessaire

# Activer le Dashboard (optionnel)
occ app:enable dashboard

# Configurer l'app par défaut
occ config:system:set defaultapp --value="dashboard"

# Optimisations de sécurité et performances (automatiques avec install.sh)
occ maintenance:repair --include-expensive
occ db:add-missing-indices
occ app:install notify_push
docker compose restart app
```

### 6. Vérification finale

```bash
# Vérifier le statut
occ status

# Vérifier les applications installées
occ app:list

# Accéder à Nextcloud
# https://votre-domaine.com
```

## 🔧 Configuration technique

### Architecture Docker
- **`foxaprod_nc_db`** : PostgreSQL 16
- **`foxaprod_nc_redis`** : Redis 7
- **`foxaprod_nc_fpm`** : Nextcloud PHP-FPM
- **`foxaprod_nc_nginx`** : Nginx frontend
- **`foxaprod_nc_cron`** : Cron pour les tâches
- **`foxaprod_onlyoffice`** : OnlyOffice Document Server

### Configuration Nginx
- Configuration officielle Nextcloud 32
- Résout automatiquement les problèmes OCS/OCM-provider
- Gestion correcte des URLs "pretty" (`/apps/photos/`)
- **Headers de sécurité complets** (HSTS, CSP, X-Frame-Options, etc.)

### Optimisations de sécurité automatiques
- **Migrations des types MIME** : Améliore la gestion des fichiers
- **Indices de base de données** : Optimise les performances des requêtes
- **Client Push (notify_push)** : Améliore les performances de synchronisation
- **En-têtes de sécurité** : Protection contre les attaques XSS, CSRF, etc.
- **Fenêtre de maintenance** : Configurée à 2h du matin
- **Politique de mots de passe** : Mots de passe sécurisés requis
- **Protection contre les attaques par force brute** : Activée

### Réseaux Docker
- **`foxaprod_net`** : Réseau interne
- **`traefik-public`** : Réseau Traefik (externe)

## 🚨 Dépannage

### Problèmes courants

1. **Erreur 403 sur `/apps/dashboard/`**
   ```bash
   # Solution : Activer le dashboard
   occ app:enable dashboard
   docker compose restart
   ```

2. **Avertissements OCS/OCM-provider**
   - ✅ Résolu avec la configuration Nginx officielle

3. **Erreurs de base de données**
   ```bash
   # Vérifier la connexion
   docker exec foxaprod_nc_db pg_isready -U nextcloud -d nextclouddb
   ```

4. **Problèmes de permissions**
   ```bash
   # Réparer les permissions
   occ maintenance:repair
   ```

## 📁 Structure des fichiers

```
nextcloud/
├── install.sh                  # Script d'installation automatique
├── docker-compose.yml          # Configuration Docker
├── env.example                 # Variables d'environnement
├── config.php.example          # Configuration Nextcloud avancée
├── nginx/
│   ├── nextcloud.conf          # Configuration Nginx officielle
│   └── mime.types.d/
│       └── nextcloud_mjs.types # Correction MIME types
└── README.md                   # Ce fichier
```

## 📄 OnlyOffice Document Server

### Fonctionnalités
- **Édition collaborative** en temps réel
- **Support complet** des formats Microsoft Office (DOCX, XLSX, PPTX)
- **Support LibreOffice** (ODT, ODS, ODP)
- **Commentaires et chat** intégrés
- **Permissions granulaires** (lecture seule, commentaires, édition)

### Configuration automatique
OnlyOffice est **automatiquement configuré** lors de l'installation :
- Service Docker intégré au `docker-compose.yml`
- Configuration via variables d'environnement
- Activation automatique dans Nextcloud
- Communication interne sécurisée

### Accès
- **Interface Nextcloud** : Créer/éditer des documents directement
- **Administration** : `https://votre-domaine.com/settings/admin/onlyoffice`

## 🔄 Mise à jour

```bash
# Arrêter les services
docker compose down

# Mettre à jour les images
docker compose pull

# Redémarrer
docker compose up -d

# Mettre à jour Nextcloud
occ upgrade
```

## 📞 Support

En cas de problème :
1. Vérifier les logs : `docker logs foxaprod_nc_nginx`
2. Vérifier OnlyOffice : `docker logs foxaprod_onlyoffice`
3. Consulter l'Admin Overview : `https://votre-domaine.com/settings/admin/overview`
4. Vérifier la configuration : `occ config:list system`

---

**✅ Installation testée et fonctionnelle avec Nextcloud Hub 29 + OnlyOffice**
