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
