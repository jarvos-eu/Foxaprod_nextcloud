Parfait, on repart propre et **on vise une stack Nextcloud Hub 29** robuste en Docker, derrière **Traefik v2** avec **PostgreSQL 16**, **Redis 7**, **cron** dédié et **Nginx** en frontal du **PHP-FPM** (image `nextcloud:fpm-*`). Cette topo corrige aussi ton souci de **MIME type `.mjs`** (servi en `text/plain` hier) via une conf Nginx explicite. Je te livre un plan technique complet (fichiers, labels, variables, réglages `config.php`, ordres `occ`) que ton agent peut transformer en fichiers.

---

# 1) Prérequis & versions

* **Nextcloud Hub 8 (v29)** requiert PHP 8.2+ (8.2 recommandé) et fonctionne très bien avec PostgreSQL et Redis; vérifie modules PHP requis/opcache (si hors image officielle). Ici on s’appuie sur les *images officielles* qui embarquent ce qu’il faut côté PHP/FPM/Apache; on utilisera la **variante FPM** + **Nginx** pour un contrôle fin des en-têtes/MIME. ([Nextcloud][1])
* **Reverse proxy** : Nextcloud derrière proxy nécessite `overwrite*` (protocole/host), `trusted_proxies`/`trusted_domains`. On les passe en **variables d’environnement** de l’image officielle (ou via `config.php`). ([Nextcloud][2])
* **Cron** : utiliser le **container `nextcloud:cron`** (ou l’image FPM avec `command: cron -f`), c’est la méthode documentée côté Docker. ([Nextcloud community][3])
* **Nginx + FPM** : c’est un schéma recommandé dans la doc des images officielles (exemples Docker Hub) et dans la doc Nginx (non « officiellement supportée » par Nextcloud, mais standard et éprouvé). ([hub.docker.com][4])

---

# 2) Réseau Traefik existant & contraintes (rappel)

Tu as **Traefik v2.10** exposé en `:80/:443`, résolveur ACME `myresolver`, réseau `traefik-public` externe, usage de labels pour router vers les services (cf. tes fichiers). On gardera **la même logique de labels** pour `foxaprod.jarvos.eu` et on branchera `nextcloud-nginx` + `nextcloud-fpm` sur `traefik-public`.   

---

# 3) Arborescence & volumes

Chemin racine demandé : **`/srv/foxaprod/nextcloud`**.

Proposition :

```
/srv/foxaprod/nextcloud/
  .env
  docker-compose.yml
  nginx/
    nextcloud.conf
    mime.types.d/nextcloud_mjs.types
  data/                 # volume Nextcloud
  db/                   # volume PostgreSQL (ou volume nommé)
  redis/                # (optionnel) si tu veux persister
  html/                 # (rarement utile avec FPM, on laisse vide)
```

* On mappe **`/srv/foxaprod/nextcloud/data`** vers `/var/www/html` du conteneur FPM (c’est là que Nextcloud écrit). Voir exemples officiels FPM+Nginx. ([hub.docker.com][4])

---

# 4) docker-compose (Nextcloud 29 + Postgres 16 + Redis 7 + Nginx + Cron)

> **NB sécurité/URL** : on utilise **`OVERWRITEPROTOCOL=https`**, **`OVERWRITEHOST=foxaprod.jarvos.eu`** et **`TRUSTED_PROXIES`** pointant sur le réseau proxy (ou le subnet) pour éliminer les warnings “insecure URLs/trusted proxies”. Ces réglages sont courants derrière reverse proxy. ([GitHub][5])

```yaml
version: "3.9"

networks:
  traefik-public:
    external: true
  foxaprod_net:
    driver: bridge

volumes:
  nc_data:
  pg_data:
  redis_data:

services:
  db:
    image: postgres:16-alpine
    container_name: foxaprod_nc_db
    environment:
      POSTGRES_DB: nextclouddb
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL","pg_isready -U nextcloud -d nextclouddb"]
      interval: 30s
      timeout: 5s
      retries: 10
    networks: [foxaprod_net]
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: foxaprod_nc_redis
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD","redis-cli","ping"]
      interval: 30s
      timeout: 5s
      retries: 10
    networks: [foxaprod_net]
    restart: unless-stopped

  app:  # PHP-FPM
    image: nextcloud:fpm-alpine
    container_name: foxaprod_nc_fpm
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }
    environment:
      # DB
      POSTGRES_HOST: db
      POSTGRES_DB: nextclouddb
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      # Reverse proxy / URL
      OVERWRITEPROTOCOL: https
      OVERWRITEHOST: foxaprod.jarvos.eu
      TRUSTED_PROXIES: 172.18.0.0/16   # adapte au subnet traefik-public ou "traefik" s'il résout
      OVERWRITECLIURL: https://foxaprod.jarvos.eu
      # Cache / locking
      REDIS_HOST: redis
      REDIS_HOST_PORT: 6379
    volumes:
      - nc_data:/var/www/html
    networks: [foxaprod_net, traefik-public]
    restart: unless-stopped

  web:  # Nginx devant FPM
    image: nginx:1.27-alpine
    container_name: foxaprod_nc_nginx
    depends_on:
      - app
    volumes:
      - nc_data:/var/www/html:ro
      - ./nginx/nextcloud.conf:/etc/nginx/conf.d/default.conf:ro
      - ./nginx/mime.types.d/nextcloud_mjs.types:/etc/nginx/mime.types.d/nextcloud_mjs.types:ro
    networks: [foxaprod_net, traefik-public]
    labels:
      - traefik.enable=true
      - traefik.docker.network=traefik-public
      - traefik.http.routers.nextcloud.rule=Host(`foxaprod.jarvos.eu`)
      - traefik.http.routers.nextcloud.entrypoints=websecure
      - traefik.http.routers.nextcloud.tls.certresolver=myresolver
      - traefik.http.services.nextcloud.loadbalancer.server.port=80
    restart: unless-stopped

  cron:
    image: nextcloud:fpm-alpine
    container_name: foxaprod_nc_cron
    depends_on:
      - app
    entrypoint: ["/cron.sh"]   # script fourni par l'image Nextcloud
    environment:
      # même contexte que 'app' si tu utilises Redis/DB
      POSTGRES_HOST: db
      POSTGRES_DB: nextclouddb
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      REDIS_HOST: redis
      REDIS_HOST_PORT: 6379
      OVERWRITEPROTOCOL: https
      OVERWRITEHOST: foxaprod.jarvos.eu
      TRUSTED_PROXIES: 172.18.0.0/16
      OVERWRITECLIURL: https://foxaprod.jarvos.eu
    volumes:
      - nc_data:/var/www/html
    networks: [foxaprod_net]
    restart: unless-stopped
```

* L’usage des variables `OVERWRITE*` et `TRUSTED_PROXIES` vient des retours d’expérience et issues officielles Docker/Nextcloud pour éliminer les warnings derrière proxy. ([GitHub][5])
* Le **container `web`** est le seul exposé à Traefik (port 80 interne). Le **container `app`** (FPM) n’est pas exposé. Cette topologie est **celle des exemples officiels FPM+Nginx sur Docker Hub**. ([hub.docker.com][4])

---

# 5) Nginx : conf robuste + correctif `.mjs`

**`nginx/nextcloud.conf`** (inspiré de la doc Nextcloud Nginx, adapté FPM + fix `.mjs`) : ([Nextcloud][6])

```nginx
server {
  listen 80 default_server;
  server_name foxaprod.jarvos.eu;

  # Racine pointant vers nc_data monté en RO
  root /var/www/html;

  # --- Sécurité & headers de base (sans dupliquer ceux que Traefik gère) ---
  add_header X-Content-Type-Options nosniff always;
  add_header X-Frame-Options SAMEORIGIN always;
  add_header Referrer-Policy no-referrer always;

  # --- Types MIME, y compris .mjs => application/javascript ---
  include /etc/nginx/mime.types;
  types {
    application/javascript  js mjs;
  }
  include /etc/nginx/mime.types.d/*.types;

  # Fichiers statiques
  location = /robots.txt { allow all; log_not_found off; access_log off; }
  location = /.well-known/carddav { return 301 /remote.php/dav; }
  location = /.well-known/caldav  { return 301 /remote.php/dav; }

  # Empêche l'accès à ces chemins
  location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ { deny all; }
  location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) { deny all; }

  # PHP via FPM
  location ~ \.php(?:$|/) {
    fastcgi_split_path_info ^(.+?\.php)(/.*)$;
    fastcgi_pass app:9000;   # service FPM
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param PATH_INFO $fastcgi_path_info;
    include fastcgi_params;

    # Variables Nextcloud recommandées
    fastcgi_param modHeadersAvailable true;
    fastcgi_param front_controller_active true;
    fastcgi_read_timeout 300s;
  }

  # Ressources statiques (cache)
  location ~ \.(?:css|js|mjs|woff2?|svg|gif|map)$ {
    try_files $uri /index.php$request_uri;
    expires 6M;
    access_log off;
  }

  location / {
    try_files $uri $uri/ /index.php$request_uri;
  }
}
```

* La ligne **`types { application/javascript js mjs; }`** force le bon **MIME pour `.mjs`** (sinon Nginx les sert parfois en `application/octet-stream` / `text/plain`, ce qui casse Nextcloud 28/29 avec le warning que tu as vu). ([GitHub][7])

---

# 6) `config.php` : paramètres essentiels (si tu préfères fixer côté fichier)

Même si on passe tout par variables d’env, ton agent peut **écrire** ceci dans `/var/www/html/config/config.php` (ou via `occ config:system:set`). Référence officielle des paramètres : `overwrite*`, `trusted_proxies`, `memcache.locking`, etc. ([Nextcloud][8])

```php
<?php
$CONFIG = [
  'trusted_domains' => ['foxaprod.jarvos.eu'],
  'overwriteprotocol' => 'https',
  'overwritehost' => 'foxaprod.jarvos.eu',
  'overwrite.cli.url' => 'https://foxaprod.jarvos.eu',
  'trusted_proxies' => ['172.18.0.0/16'], // adapte au subnet/réseau proxy
  'forwarded_for_headers' => ['HTTP_X_FORWARDED_FOR'],
  'default_phone_region' => 'FR',

  // Redis (locking + local)
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'memcache.local'   => '\\OC\\Memcache\\Redis',
  'redis' => [
    'host' => 'redis',
    'port' => 6379,
  ],
];
```

* `overwrite.cli.url` évite des URLs HTTP en background jobs/cron. ([Reddit][9])
* Paramètres reverse proxy documentés ici (et dans la page Reverse proxy). ([Nextcloud][2])

---

# 7) Post-install : commandes `occ` & tâches

Après le `docker compose up -d`, fais (une seule fois) :

```bash
# confort: alias
alias occ='docker exec -u www-data foxaprod_nc_fpm php occ'

# maintenance initiale
occ maintenance:repair
occ db:add-missing-indices
occ db:add-missing-columns
occ db:add-missing-primary-keys

# job background: s'assurer qu'on est bien en cron
occ background:cron

# caches/opcache (si tu customises php.ini en dehors de l'image)
# cf. doc PHP modules/opcache
```

* Les modules PHP requis/recommandés et opcache sont listés par Nextcloud (utile surtout si tu sors de l’image officielle). ([Nextcloud][10])
* Cron : avec le service `cron` ci-dessus, le **panneau d’admin doit passer au vert** (“dernière exécution…”). En cas de container séparé, **propager aussi les variables Redis/DB** (sinon certains jobs échouent) – point déjà remonté dans les issues récentes. ([GitHub][11])

---

# 8) Sécurité & durcissement

* **TLS** est géré par Traefik (déjà configuré chez toi). On garde les **headers de base** côté Nginx, sans doublons avec Traefik. 
* **Taille d’upload** : si besoin, ajoute un `client_max_body_size 10G;` dans `server {}` de Nginx (et éventuellement `php.ini` via `PHP_UPLOAD_LIMIT`/custom ini si tu sors de l’image). Réglages PHP dans la doc. ([Nextcloud][12])
* **Préchargement d’assets/`cache`** : les localisations statiques `.css/.js/.mjs/.woff2` sont en cache 6 mois (cf. bloc Nginx plus haut), conforme aux pratiques. ([Nextcloud][6])

---

# 9) Points d’attention spécifiques à Traefik

* **Règle de routage** : `Host(\`foxaprod.jarvos.eu`)` sur le **service Nginx** (`web`). **Ne publie pas FPM**. 
* **Réseaux** : `web` et `app` se connectent à **`traefik-public`** (pour que Traefik voie l’endpoint) **et** à un **réseau applicatif dédié** (`foxaprod_net`). C’est déjà ta pratique sur d’autres stacks. 
* **`X-Forwarded-*`** : Traefik ajoute ces en-têtes; Nextcloud doit les **faire confiance** via `trusted_proxies` et les `overwrite*`. C’est précisément ce que recommande la doc “Reverse proxy/Overwrite parameters”. ([Nextcloud][2])

---

# 10) Checklist migration / reset propre (si tu « repars de zéro »)

1. `docker compose down -v` (si tu veux vraiment purger), **sauvegarde** auparavant `/srv/foxaprod/nextcloud/data` si tu as des tests dedans.
2. Nettoie les anciens containers **Apache** si tu avais lancé `nextcloud:apache` (on passe en **FPM**). ([hub.docker.com][4])
3. Recrée les volumes, `up -d`, attends `db` healthy, puis Nginx répond en 200 sur `/status.php`.
4. Fais l’install web ou **installe en ligne** :

```bash
docker exec -u www-data foxaprod_nc_fpm php occ maintenance:install \
  --database "pgsql" --database-host "db" \
  --database-name "nextclouddb" --database-user "nextcloud" \
  --database-pass "${POSTGRES_PASSWORD}" \
  --admin-user "admin" --admin-pass "TON_MDP_ADMIN"
```

5. Active Redis en locking/local (si pas passé via `config.php` env). ([Nextcloud][8])

---

## Pourquoi ce design corrige tes erreurs d’hier

* Le **warning `.mjs`** venait d’un **MIME incorrect (`text/plain`)**. Le bloc `types { application/javascript js mjs; }` + include mime résout **définitivement** cet avertissement (confirmé par de multiples retours Nginx/Storybook/Nextcloud). ([GitHub][7])
* Les **URLs mixtes/insecure** derrière proxy sont gérées par **`OVERWRITEPROTOCOL=https` + `OVERWRITEHOST` + `trusted_proxies`**, réglages **officiellement documentés** (page Reverse proxy/Overwrite). ([Nextcloud][2])
* **Cron** tourne via un **container dédié** avec **les mêmes variables DB/Redis** que l’app – pattern recommandé/observé dans les exemples et threads de support. ([Nextcloud community][3])

---

Si tu veux, je peux te générer **tous les fichiers prêts à déposer** dans `/srv/foxaprod/nextcloud/` (compose, conf Nginx, `.env` modèle) au format exact que tu utilises avec Traefik/Hostinger.

[1]: https://docs.nextcloud.com/server/29/Nextcloud_Server_Administration_Manual.pdf?utm_source=chatgpt.com "Nextcloud Server Administration Manual"
[2]: https://docs.nextcloud.com/server/stable/admin_manual/configuration_server/reverse_proxy_configuration.html?utm_source=chatgpt.com "Reverse proxy — Nextcloud latest Administration Manual ..."
[3]: https://help.nextcloud.com/t/nextcloud-docker-container-best-way-to-run-cron-job/157734?utm_source=chatgpt.com "Nextcloud Docker Container - best way to run cron job"
[4]: https://hub.docker.com/_/nextcloud/?utm_source=chatgpt.com "nextcloud - Official Image"
[5]: https://github.com/nextcloud/docker/issues/1672?utm_source=chatgpt.com "behind a reverse proxy and the overwrite config variables ..."
[6]: https://docs.nextcloud.com/server/stable/admin_manual/installation/nginx.html?utm_source=chatgpt.com "NGINX configuration"
[7]: https://github.com/storybookjs/storybook/issues/20157?utm_source=chatgpt.com "mjs file extension for browser code is not working in nginx · ..."
[8]: https://docs.nextcloud.com/server/29/admin_manual/configuration_server/config_sample_php_parameters.html?utm_source=chatgpt.com "Configuration Parameters"
[9]: https://www.reddit.com/r/NextCloud/comments/1g852o8/persistent_warning_set_the_overwritecliurl_option/?utm_source=chatgpt.com "persistent warning, set the \"overwrite.cli.url\" option in your ..."
[10]: https://docs.nextcloud.com/server/29/admin_manual/installation/php_configuration.html?utm_source=chatgpt.com "PHP Modules & Configuration"
[11]: https://github.com/nextcloud/docker/issues/2469?utm_source=chatgpt.com "cron via docker-compose needs Redis-environment as ..."
[12]: https://docs.nextcloud.com/server/stable/admin_manual/installation/php_configuration.html?utm_source=chatgpt.com "Preparing PHP — Nextcloud latest Administration Manual ..."
