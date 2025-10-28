#!/bin/bash

# 🚀 Script d'installation automatique Nextcloud Hub 29
# Usage: ./install.sh

set -e  # Arrêter en cas d'erreur

echo "🚀 Installation automatique Nextcloud Hub 29"
echo "=============================================="

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages colorés
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    log_success "Prérequis OK"
}

# Configuration des variables d'environnement
setup_env() {
    log_info "Configuration des variables d'environnement..."
    
    if [ ! -f .env ]; then
        cp env.example .env
        log_success "Fichier .env créé depuis env.example"
        
        log_warning "⚠️  IMPORTANT: Éditez le fichier .env avec vos valeurs :"
        echo "   - POSTGRES_PASSWORD (mot de passe sécurisé)"
        echo "   - NEXTCLOUD_ADMIN_USER (nom d'utilisateur admin)"
        echo "   - NEXTCLOUD_ADMIN_PASSWORD (mot de passe admin)"
        echo "   - NEXTCLOUD_DOMAIN (votre domaine)"
        echo ""
        read -p "Appuyez sur Entrée quand vous avez configuré le .env..."
    else
        log_info "Fichier .env existe déjà"
    fi
}

# Démarrage des services Docker
start_services() {
    log_info "Démarrage des services Docker..."
    
    docker compose up -d
    
    log_info "Attente que les services soient prêts (60 secondes)..."
    sleep 60
    
    # Vérifier que tous les containers sont UP
    if docker ps | grep -q foxaprod_nc_db && \
       docker ps | grep -q foxaprod_nc_redis && \
       docker ps | grep -q foxaprod_nc_fpm && \
       docker ps | grep -q foxaprod_nc_nginx && \
       docker ps | grep -q foxaprod_nc_cron; then
        log_success "Tous les services sont démarrés"
    else
        log_error "Certains services ne sont pas démarrés"
        docker ps | grep foxaprod
        exit 1
    fi
}

# Installation Nextcloud
install_nextcloud() {
    log_info "Installation de Nextcloud..."
    
    # Charger les variables d'environnement
    source .env
    
    # Alias pour les commandes occ
    alias occ='docker exec -u www-data foxaprod_nc_fpm php occ'
    
    # Vérifier si Nextcloud est déjà installé
    if occ status | grep -q "installed: true"; then
        log_warning "Nextcloud est déjà installé"
        return 0
    fi
    
    # Installation Nextcloud
    log_info "Exécution de l'installation Nextcloud..."
    occ maintenance:install \
        --database "pgsql" \
        --database-host "db" \
        --database-name "nextclouddb" \
        --database-user "nextcloud" \
        --database-pass "$POSTGRES_PASSWORD" \
        --admin-user "$NEXTCLOUD_ADMIN_USER" \
        --admin-pass "$NEXTCLOUD_ADMIN_PASSWORD"
    
    log_success "Nextcloud installé avec succès"
}

# Configuration post-installation
post_install_config() {
    log_info "Configuration post-installation..."
    
    alias occ='docker exec -u www-data foxaprod_nc_fpm php occ'
    
    # Copier la configuration avancée si elle n'existe pas
    if [ ! -f config.php ]; then
        cp config.php.example config.php
        log_success "Configuration avancée copiée"
    fi
    
    # Activer le Dashboard
    log_info "Activation du Dashboard..."
    occ app:enable dashboard
    
    # Configurer l'app par défaut
    log_info "Configuration de l'application par défaut..."
    occ config:system:set defaultapp --value="dashboard"
    
    log_success "Configuration post-installation terminée"
}

# Optimisations de sécurité et performances
security_optimizations() {
    log_info "Application des optimisations de sécurité et performances..."
    
    alias occ='docker exec -u www-data foxaprod_nc_fpm php occ'
    
    # 1. Migrations des types MIME
    log_info "Exécution des migrations de types MIME..."
    occ maintenance:repair --include-expensive
    
    # 2. Ajout des indices manquants de la base de données
    log_info "Ajout des indices manquants de la base de données..."
    occ db:add-missing-indices
    
    # 3. Installation de Client Push pour les performances
    log_info "Installation de Client Push (notify_push)..."
    occ app:install notify_push
    
    # 4. Redémarrage pour activer toutes les optimisations
    log_info "Redémarrage des services pour activer les optimisations..."
    docker compose restart app
    
    # Attendre que le service redémarre
    sleep 10
    
    log_success "Optimisations de sécurité et performances appliquées"
}

# Vérification finale
final_check() {
    log_info "Vérification finale..."
    
    alias occ='docker exec -u www-data foxaprod_nc_fpm php occ'
    
    # Vérifier le statut
    log_info "Statut Nextcloud :"
    occ status
    
    # Vérifier les applications
    log_info "Applications installées :"
    occ app:list | grep -E "(dashboard|files|photos|activity)"
    
    log_success "Installation terminée avec succès !"
    echo ""
    echo "🌐 Accédez à Nextcloud : https://$NEXTCLOUD_DOMAIN"
    echo "👤 Utilisateur admin : $NEXTCLOUD_ADMIN_USER"
    echo "🔧 Admin panel : https://$NEXTCLOUD_DOMAIN/settings/admin/overview"
}

# Fonction principale
main() {
    echo ""
    log_info "Début de l'installation automatique..."
    echo ""
    
    check_prerequisites
    setup_env
    start_services
    install_nextcloud
    post_install_config
    security_optimizations
    final_check
    
    echo ""
    log_success "🎉 Installation Nextcloud Hub 29 terminée !"
    echo ""
    echo "📚 Consultez le README.md pour plus d'informations"
    echo "🔧 En cas de problème, vérifiez les logs : docker logs foxaprod_nc_nginx"
}

# Exécution du script
main "$@"
