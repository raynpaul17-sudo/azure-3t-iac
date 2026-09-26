# Sécurité

## Choix de conception

- **Segmentation** : trois subnets isolés par des NSG en refus par défaut. Seul le front est joignable depuis internet, la base uniquement depuis le back.
- **Exposition minimale** : un seul point d'entrée public, le Load Balancer. SSH restreint à une IP d'administration. Aucune IP publique sur les VM.
- **Aucun secret dans le code** : les secrets sont stockés dans Key Vault et lus par les VM via leur identité managée. L'authentification de la pipeline repose sur OIDC, sans identifiant stocké.
- **Moindre privilège** : les rôles sont limités au resource group du projet et au besoin réel de chaque identité.
- **Durcissement des VM** : authentification SSH par clé uniquement, connexion root interdite, pare-feu local en refus par défaut, mises à jour appliquées au déploiement. Les services tournent sous des utilisateurs dédiés, et l'application est confinée par systemd (système de fichiers en lecture seule, aucune élévation de privilèges).
- **Chiffrement en transit** : TLS terminé sur le front.
- **Défense en profondeur** : chaque flux est filtré par plusieurs couches indépendantes, administrées séparément : NSG au niveau du réseau Azure, pare-feu local sur chaque VM, écoute des services restreinte à leur adresse privée, et authentification applicative. Une erreur sur une couche ne suffit pas à ouvrir un flux.

## Contrôles automatiques dans la pipeline

Chaque contrôle s'exécute à chaque `push`, et un échec interrompt la pipeline.

| Contrôle             | Rôle                                                                  | État     |
| -------------------- | --------------------------------------------------------------------- | -------- |
| Secret Detection     | détecte un secret commité par erreur                                  | en place |
| `terraform fmt`      | format cohérent du code                                               | prévu    |
| `terraform validate` | configuration syntaxiquement et structurellement valide               | prévu    |
| `tflint`             | erreurs et mauvaises pratiques Terraform propres à Azure              | prévu    |
| `checkov`            | mauvaises configurations de sécurité (exposition, chiffrement, accès) | prévu    |
| `ansible-lint`       | mauvaises pratiques Ansible, dont les secrets exposés dans les logs   | prévu    |
| `terraform plan`     | relu avant tout `apply` : aucun déploiement à l'aveugle               | prévu    |

## Vérification après déploiement

Des tests exécutés sur l'infrastructure déployée prouvent que la segmentation est effective, et ne se contentent pas de vérifier que la configuration semble correcte :

- le front ne peut pas joindre la base directement
- une machine extérieure n'atteint que le Load Balancer
- les flux autorisés de la matrice fonctionnent

## Gestion des valeurs sensibles

La variable `admin_ip` est déclarée `sensitive` : elle est masquée dans les sorties de `plan` et dans les journaux de pipeline. Elle reste en revanche lisible dans le state Terraform, qui doit donc être protégé et n'est jamais versionné.

## Gestion des secrets

Le mot de passe de la base de données n'est jamais saisi, ni stocké hors du coffre.

Terraform le génère par une **ressource éphémère**, qui n'existe qu'en mémoire pendant l'exécution, et l'écrit dans Key Vault via un **argument en écriture seule**. Il n'apparaît donc ni dans le fichier de plan, ni dans le state Terraform. Les ressources éphémères étant réévaluées à chaque exécution, un numéro de version explicite détermine quand le secret doit être réécrit : tant qu'il n'est pas incrémenté, la valeur du coffre reste inchangée.

### Accès sans identifiant

Chaque machine porte une identité managée attribuée par Azure. Pour lire le secret, elle demande un jeton au service de métadonnées de l'instance, joignable uniquement depuis la machine elle-même, puis le présente au coffre. Aucun identifiant, aucune clé et aucun mot de passe ne sont stockés sur les machines.

### Moindre privilège

| Identité                          | Rôle                      | Portée    |
| --------------------------------- | ------------------------- | --------- |
| Compte exécutant Terraform        | Key Vault Secrets Officer | le coffre |
| Identité de la VM applicative     | Key Vault Secrets User    | le secret |
| Identité de la VM base de données | Key Vault Secrets User    | le secret |

La VM front ne reçoit aucun droit : elle n'a pas besoin du mot de passe. L'attribution porte sur l'identifiant **sans version** du secret ; l'identifiant versionné, accepté par Terraform, ne couvrirait qu'une version précise et serait invalidé par toute rotation.

### Accès réseau au coffre

Le coffre refuse tout accès par défaut. Seuls l'adresse d'administration et les subnets applicatif et base de données sont autorisés. Ces deux subnets disposent d'un point de terminaison de service vers Key Vault : sans lui, leurs requêtes sortiraient par l'adresse publique du load balancer et la règle par subnet serait inopérante.

### Limites connues

- **Accès public du coffre maintenu** : le coffre conserve une adresse publique, protégée par son pare-feu. Un point de terminaison privé le retirerait totalement d'internet, au prix d'une facturation horaire et d'une zone DNS privée.
- **Protection contre la purge désactivée** : l'infrastructure étant éphémère, le coffre doit pouvoir être purgé à la destruction pour que son nom soit réutilisable. En production, cette protection serait activée.
- **Propagation des attributions de rôle** : une attribution met quelques minutes à devenir effective, ce qui impose une dépendance explicite entre l'attribution et la première écriture du secret.

## Vérification après déploiement

Un script rejouable exécute la matrice de flux sur l'infrastructure déployée et compare chaque résultat à celui attendu. Un flux qui doit être bloqué est un test à part entière : il échoue s'il devient joignable.

_./tests/check-isolation.sh_

Le script couvre trois familles de contrôles :

- **isolation interne** : les flux autorisés entre tiers fonctionnent, et ceux qui ne le sont pas échouent, notamment l'accès direct du front à la base
- **exposition externe** : seuls les ports web et le port d'administration répondent sur l'adresse publique ; les ports applicatif et base de données ne sont pas joignables
- **points d'entrée HTTP** : la redirection vers HTTPS, la route de santé du reverse proxy, et la traversée complète jusqu'à la base

Les valeurs testées proviennent des outputs Terraform : aucune adresse n'est codée en dur. Le script sort en erreur dès qu'un contrôle échoue, ce qui le rend exploitable dans une chaîne d'intégration.
