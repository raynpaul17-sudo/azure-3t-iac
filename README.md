# azure-3t-iac

Déployer une application web dans le cloud aboutit souvent à des ressources trop exposées, des secrets éparpillés dans le code et les pipelines, des permissions trop larges, et une infrastructure que personne ne sait reconstruire.

Ce projet déploie une application trois tiers (web, applicatif, base de données) sur Azure en appliquant le principe du moindre privilège : réseaux segmentés où chaque tier n'atteint que ce dont il a besoin, identités sans secret limitées au strict nécessaire, et secrets gérés hors du code.

L'infrastructure est créée, testée et détruite via une pipeline CI/CD, avec des contrôles de sécurité intégrés dès la conception.

## État du projet

Projet en cours de construction.

**En place et vérifiable :**

- infrastructure Terraform complète : réseau segmenté en trois subnets, règles de filtrage par tier, load balancer public, machines virtuelles sans adresse publique
- configuration Ansible : durcissement SSH, pare-feu local sur chaque machine, PostgreSQL à accès restreint, application applicative confinée par systemd, reverse proxy nginx avec terminaison TLS
- reconstruction complète depuis zéro, sans intervention manuelle, et playbook idempotent

**En cours :**

- gestion des secrets par Key Vault et identités managées
- script de vérification automatisée de la segmentation réseau
- pipeline CI/CD avec contrôles de sécurité (analyse statique Terraform et Ansible, détection de secrets)

## Documentation

| Document                               | Contenu                                                           |
| -------------------------------------- | ----------------------------------------------------------------- |
| [Architecture](docs/architecture.md)   | Découpage réseau, matrice de flux, dimensionnement, load balancer |
| [Configuration](docs/configuration.md) | Rôles Ansible, durcissement, services déployés                    |
| [Sécurité](docs/security.md)           | Choix de conception, contrôles automatisés, vérifications         |
| [Coût](docs/cost.md)                   | Modèle éphémère et garde-fous budgétaires                         |

## Technologies

Azure, Terraform, Ansible, nginx, PostgreSQL, GitLab CI.
