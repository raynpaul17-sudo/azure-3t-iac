# Configuration des machines

La configuration des trois VM est entièrement gérée par Ansible. Aucune action manuelle n'est nécessaire : un seul playbook transforme trois machines Ubuntu vierges en infrastructure fonctionnelle, et une seconde exécution ne modifie plus rien.

## Organisation

| Rôle     | Cible  | Contenu                                                                 |
| -------- | ------ | ----------------------------------------------------------------------- |
| `common` | toutes | mises à jour, synchronisation horaire, durcissement SSH, pare-feu local |
| `db`     | db     | PostgreSQL, accès restreint à l'application                             |
| `app`    | back   | application Python servie par Gunicorn, service systemd confiné         |
| `nginx`  | front  | reverse proxy, terminaison TLS, en-têtes de sécurité                    |

Le playbook `site.yml` applique les rôles dans l'ordre des dépendances : `common` sur toutes les machines, puis `db`, `app` et `nginx`. Chaque tier est configuré avant celui qui dépend de lui.

## Inventaire généré

L'inventaire n'est jamais écrit à la main. Un script le génère à partir des outputs Terraform : adresses des VM, IP publique du Load Balancer, port SSH public, nom d'utilisateur, plages des subnets et IP d'administration. Chaque redéploiement produit un inventaire à jour, sans duplication de valeur entre Terraform et Ansible. Le fichier généré n'est pas versionné, seul le script l'est.

## Connexion par rebond

Seule la VM front est joignable depuis l'extérieur, via la règle NAT du Load Balancer. Ansible atteint back et db en rebondissant par le front (`ProxyJump`), sans que la clé privée ne quitte le poste d'administration.

Toutes les connexions transitant par une seule machine, des connexions simultanées vers ce point unique sont rejetées par `sshd`. Ansible s'exécute donc en séquence (`forks = 1`), et la réutilisation de connexion SSH (`ControlMaster`) compense en partie le coût de cette sérialisation.

## Rôle `common`

### Durcissement SSH

Un fichier déposé dans `/etc/ssh/sshd_config.d/` impose l'authentification par clé uniquement et interdit la connexion en root. Il est validé par `sshd -t` avant d'être écrit : une erreur de syntaxe fait échouer la tâche et laisse l'ancienne configuration en place, ce qui évite de perdre l'accès aux machines.

Le fichier porte un préfixe qui le fait lire avant ceux déposés par Azure : dans ce dossier, la première directive rencontrée l'emporte. L'effet réel est vérifié avec `sshd -T`, qui affiche la configuration effective.

### Pare-feu local

UFW constitue une seconde couche de filtrage, indépendante des NSG. Il reproduit la même matrice de flux, en refus par défaut en entrée, y compris pour le SSH :

| Machine | Autorise                                                   |
| ------- | ---------------------------------------------------------- |
| front   | 22 depuis l'IP d'administration, 80 et 443 depuis internet |
| back    | 22 et 8080 depuis le subnet front                          |
| db      | 22 depuis le subnet front, 5432 depuis le subnet back      |

Les deux couches sont administrées séparément : une erreur sur un NSG ne suffit pas à ouvrir un flux. Le pare-feu n'est activé qu'après la pose des règles, pour ne jamais couper l'accès en cours de déploiement.

### Synchronisation horaire

`systemd-timesyncd` maintient l'horloge à l'heure. Une horloge décalée invalide la vérification des certificats TLS et des jetons d'authentification, et empêche de corréler les journaux entre machines.

## Rôle `db`

PostgreSQL n'écoute que sur la boucle locale et l'adresse privée de la VM, jamais sur toutes les interfaces. L'accès est filtré à trois niveaux indépendants :

1. **réseau** : NSG et pare-feu local n'autorisent le port 5432 que depuis le subnet back
2. **écoute** : `listen_addresses` limite les adresses sur lesquelles le serveur attend des connexions
3. **authentification** : `pg_hba.conf` n'autorise que l'utilisateur applicatif, sur sa seule base, depuis le seul subnet back, avec une authentification SCRAM-SHA-256

Une modification de `pg_hba.conf` déclenche un rechargement, qui ne coupe pas les connexions. Seul un changement d'adresse d'écoute impose un redémarrage.

## Rôle `app`

L'application est volontairement minimale : une route `/health` qui confirme que le service tourne, et une route `/db` qui interroge la base et prouve que la chaîne complète fonctionne.

### Identité et permissions

- l'application tourne sous un utilisateur système dédié, sans shell ni mot de passe
- son code appartient à root et n'est lisible que par le groupe de l'application : elle ne peut pas le modifier
- les paramètres de connexion à la base sont stockés dans un fichier réservé à root. Il est lu par systemd au démarrage, qui injecte les valeurs dans l'environnement du processus : l'application ne peut pas relire ce fichier

### Confinement systemd

L'unité systemd limite ce que le processus peut faire, même en cas de compromission :

- `NoNewPrivileges` : aucune élévation de privilèges possible
- `ProtectSystem=strict` : tout le système de fichiers est en lecture seule pour le service
- `ProtectHome` et `PrivateTmp` : répertoires personnels inaccessibles, `/tmp` privé

Aucune exception en écriture n'est accordée : l'application n'écrit rien, et un attaquant ne pourrait pas modifier son code pour s'y maintenir.

Le service démarre après `network-online.target`, car Gunicorn écoute sur une adresse précise qui doit exister au moment du démarrage.

## Rôle `nginx`

nginx est l'unique point d'entrée applicatif. Il termine le TLS et relaie les requêtes vers l'application en HTTP, sur le réseau privé.

### TLS

Un certificat auto-signé est généré sur la machine, avec l'IP publique du Load Balancer dans le champ SAN. Seuls TLS 1.2 et 1.3 sont acceptés. La clé privée n'est lisible que par root.

### En-têtes et exposition

- `server_tokens off` : la version de nginx n'est jamais annoncée
- `X-Content-Type-Options`, `X-Frame-Options` et `Strict-Transport-Security` sont ajoutés à toutes les réponses, erreurs comprises
- `X-Forwarded-For` est écrasé par l'adresse réelle du client plutôt que complété : nginx est le premier composant à comprendre le HTTP, et un en-tête fourni par le client ne peut pas être considéré comme fiable

### Sonde du Load Balancer

La route `/healthz` sur le port 80 répond directement, sans redirection et sans solliciter l'application. La sonde vérifie ainsi nginx et uniquement nginx : une panne de l'application ne retire pas de la rotation un proxy qui fonctionne.

### Validation avant rechargement

Toute modification de configuration déclenche `nginx -t` avant le rechargement. Une configuration invalide arrête le déploiement, et nginx continue de servir avec l'ancienne.

Au premier déploiement, le remplacement du site par défaut change les adresses d'écoute. Un rechargement ne peut pas l'appliquer, le port étant encore tenu par l'ancienne configuration : cette étape unique déclenche donc un redémarrage complet.

## Vérifications

Chaque rôle se termine par un test du comportement réel, et non par le simple constat qu'un service est démarré :

- le rôle `app` interroge sa route `/health`
- le rôle `nginx` interroge `/healthz` en HTTP et `/health` en HTTPS, à travers le proxy

Un service démarré mais défaillant fait ainsi échouer le déploiement. Ce choix a permis de détecter un rechargement nginx qui échouait sans erreur visible, et un service applicatif relancé en boucle par systemd.

## Idempotence

Relancé sur une infrastructure déjà configurée, le playbook ne modifie rien et ne redémarre aucun service. Les tâches qui ne font que lire l'état du système sont marquées comme telles, et les changements de format entre la valeur déclarée et la valeur restituée par un service ont été alignés pour éviter les faux changements.

## Limites connues

- **Secret transitoire** : le mot de passe de la base est encore fourni à l'exécution du playbook. Il est masqué dans les journaux (`no_log`) et sera remplacé par une lecture depuis Key Vault.
- **Vérification des empreintes SSH désactivée** : l'infrastructure étant éphémère, chaque VM est recréée avec une nouvelle empreinte. En production, la vérification serait maintenue et les empreintes provisionnées.
- **Exécution séquentielle** : imposée par le rebond unique, elle allonge la durée du déploiement.
- **Base de données sur VM** : en production, Azure Database for PostgreSQL avec accès privé serait préférable, pour ses sauvegardes, correctifs et haute disponibilité gérés.
- **Trafic interne en clair** : la liaison entre nginx et l'application n'est pas chiffrée. Elle circule sur un réseau privé segmenté ; un environnement exigeant chiffrerait aussi ce segment.
- **Certificat auto-signé** : en production, un domaine avec un certificat Let's Encrypt ou géré dans Key Vault.
- **Pas de WAF** : un WAF open source (ModSecurity avec l'OWASP Core Rule Set) pourrait être ajouté sur nginx, et un Application Gateway avec WAF serait la solution managée en production.
- **Rôles spécifiques au projet** : en production, des rôles communautaires éprouvés comme `devsec.hardening` seraient privilégiés, épinglés en version et audités.
- **IP d'administration** : un changement d'adresse publique de l'administrateur coupe l'accès SSH, y compris au niveau du pare-feu local. L'infrastructure étant éphémère, la solution est de la recréer avec la nouvelle adresse.
