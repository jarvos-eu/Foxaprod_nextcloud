<?php
$CONFIG = array (
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => 
  array (
    0 => 
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 => 
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' => 
  array (
    'host' => 'redis',
    'password' => '',
    'port' => 6379,
  ),
  'overwritehost' => 'foxaprod.jarvos.eu',
  'overwriteprotocol' => 'https',
  'overwrite.cli.url' => 'https://foxaprod.jarvos.eu',
  'trusted_proxies' => 
  array (
    0 => '172.18.0.0/16',
  ),
  'upgrade.disable-web' => true,
  'instanceid' => 'oct5lr47ckfj',
  'passwordsalt' => 'wLpbPeZ92R/DF3A8++gs5ETUBUs0g0',
  'secret' => '6km+euNgPG4IFIJuGhjiLIRHRReN8kkLkeEyhy/lFvR9gSj9',
  'trusted_domains' => 
  array (
    0 => 'foxaprod.jarvos.eu',
  ),
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'pgsql',
  'version' => '32.0.1.2',
  'dbname' => 'nextclouddb',
  'dbhost' => 'db',
  'dbtableprefix' => 'oc_',
  'dbuser' => 'oc_admin',
  'dbpassword' => 'HTismXaxGqcgh3SbTs8IewR2lnhnXl',
  'installed' => true,
  'maintenance' => false,
  'defaultapp' => 'dashboard',
  
  // === PARAMÈTRES DE SÉCURITÉ AJOUTÉS ===
  
  // Configuration de la fenêtre de maintenance (recommandé par Nextcloud)
  'maintenance_window_start' => 2, // 2h du matin
  
  // Configuration des logs et sécurité
  'log_type' => 'file',
  'logfile' => '/var/www/html/data/nextcloud.log',
  'loglevel' => 2, // 0=Debug, 1=Info, 2=Warning, 3=Error, 4=Fatal
  'log_rotate_size' => 104857600, // 100MB
  
  // Sécurité des fichiers
  'filelocking.enabled' => true,
  'filelocking.ttl' => 60 * 60, // 1 heure
  
  // Protection contre les attaques par force brute
  'auth.bruteforce.protection.enabled' => true,
  'auth.bruteforce.protection.delay' => 2,
  'auth.bruteforce.protection.time' => 900, // 15 minutes
  
  // Configuration des sessions
  'session_lifetime' => 60 * 60 * 24, // 24 heures
  'remember_login_cookie_lifetime' => 60 * 60 * 24 * 15, // 15 jours
  
  // Sécurité des mots de passe
  'password_policy.minLength' => 8,
  'password_policy.enforceNonCommonPassword' => true,
  'password_policy.enforceUpperLowerCase' => true,
  'password_policy.enforceNumericCharacters' => true,
  'password_policy.enforceSpecialCharacters' => true,
  
  // Configuration des téléchargements
  'max_chunk_size' => 10485760, // 10MB
  'upload_chunk_size' => 10485760, // 10MB
  
  // Configuration des préfixes téléphoniques (recommandé par Nextcloud)
  'default_phone_region' => 'FR',
  
  // Désactiver les fonctionnalités non sécurisées
  'allow_local_remote_servers' => false,
  'allow_user_to_change_display_name' => false,
  'allow_user_to_change_mail_address' => false,
  
  // Configuration des prévisualisations
  'preview_max_x' => 2048,
  'preview_max_y' => 2048,
  'preview_max_scale_factor' => 1,
  
  // Configuration des fichiers temporaires
  'tempdirectory' => '/tmp',
  'temp_hash' => 'temp_hash_value',
  
  // Configuration des quotas par défaut
  'default_quota' => '1GB',
  
  // Configuration de la synchronisation
  'filesystem_check_changes' => 1,
  
  // Configuration des notifications
  'notify_push' => [
    'nextcloud' => 'https://foxaprod.jarvos.eu/push',
  ],
);
