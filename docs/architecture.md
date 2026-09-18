# Architecture

## Région

`swedencentral`, imposée par la policy de l'offre Azure for Students (régions autorisées : `swedencentral`, `polandcentral`, `norwayeast`, `switzerlandnorth`, `uaenorth`). Retenue pour son appartenance à l'UE et la largeur de son catalogue de services.

## Dimensionnement des VM

| Tier  | Rôle       | Taille              | vCPU | RAM  |
| ----- | ---------- | ------------------- | ---- | ---- |
| front | nginx      | `Standard_B2ats_v2` | 2    | 1 Go |
| back  | app        | `Standard_B2ats_v2` | 2    | 1 Go |
| db    | PostgreSQL | `Standard_B2ats_v2` | 2    | 1 Go |

La taille est une variable Terraform : la VM db peut passer en `Standard_B2als_v2` (4 Go) si la mémoire devient insuffisante.

### Contrainte de quota

Le quota total régional de l'abonnement est de 6 vCPU. Aucune taille à 1 vCPU n'est disponible dans les régions autorisées : la plus petite série B proposée (Bsv2) démarre à 2 vCPU. L'infrastructure est donc limitée à 3 VM, soit 6 vCPU sur 6.

### Compromis assumés

- **Front non redondant** : un seul nginx. Le Load Balancer reste l'unique point d'entrée public.
- **Pas de bastion dédié** : accès SSH via une règle NAT entrante du Load Balancer vers le front, filtrée sur une IP d'administration, puis rebond (`ProxyJump`) vers back et db.
- **Aucune marge de quota** : les VM sont supprimées avant d'être recréées lors d'un remplacement, et l'absence de VM orpheline est vérifiée avant chaque `apply`.

## Segmentation réseau

Un VNet `10.10.0.0/16` découpé en trois subnets, un par tier, chacun protégé par son propre NSG :

| Tier  | Subnet         | Rôle       |
| ----- | -------------- | ---------- |
| front | `10.10.1.0/24` | nginx      |
| back  | `10.10.2.0/24` | app        |
| db    | `10.10.3.0/24` | PostgreSQL |

### Matrice de flux

Toutes les règles sont en entrée. Une priorité basse est évaluée en premier.

| NSG   | Prio | Accès | Source              | Port | Raison                 |
| ----- | ---- | ----- | ------------------- | ---- | ---------------------- |
| front | 100  | Allow | Internet            | 443  | HTTPS public via le LB |
| front | 110  | Allow | Internet            | 80   | redirection vers HTTPS |
| front | 120  | Allow | IP d'administration | 22   | SSH d'administration   |
| front | 130  | Allow | AzureLoadBalancer   | tous | sondes de santé du LB  |
| front | 4000 | Deny  | VirtualNetwork      | tous | isolation              |
| back  | 100  | Allow | subnet front        | 8080 | nginx vers app         |
| back  | 110  | Allow | subnet front        | 22   | rebond SSH             |
| back  | 4000 | Deny  | VirtualNetwork      | tous | isolation              |
| db    | 100  | Allow | subnet back         | 5432 | app vers PostgreSQL    |
| db    | 110  | Allow | subnet front        | 22   | rebond SSH             |
| db    | 4000 | Deny  | VirtualNetwork      | tous | isolation              |

### Pourquoi un refus explicite du trafic VNet

Un NSG sans règle personnalisée n'isole pas : Azure y ajoute la règle par défaut `AllowVnetInBound` (priorité 65000), qui autorise tout le trafic interne au VNet. Sans les règles Deny à 4000, le front pourrait joindre la base sur n'importe quel port. Les règles Deny sont évaluées avant cette règle par défaut et ne laissent passer que les flux explicitement autorisés.

### Pourquoi le NSG front autorise `Internet`

Le Load Balancer Azure opère en couche 4 et conserve l'IP source du client. Le NSG front voit donc le trafic HTTPS comme provenant d'internet, et non du Load Balancer. Le tag `AzureLoadBalancer` ne couvre que les sondes de santé.

L'exposition reste maîtrisée par deux couches complémentaires :

- la VM front n'a pas d'IP publique : le Load Balancer est le seul point d'entrée, et il n'expose que les ports 80 et 443
- le NSG filtre qui peut atteindre la VM et bloque le reste du trafic interne

### Pourquoi une règle explicite pour les sondes

Le tag `VirtualNetwork` peut englober l'adresse d'origine des sondes du Load Balancer. La règle Deny à 4000 risquerait alors de les bloquer et de faire considérer le front comme hors service. La règle `front-allow-probe-from-lb` les autorise avant le refus.

### Rebond SSH

Le SSH n'est ouvert depuis l'extérieur que vers le front, et uniquement depuis l'IP d'administration. Back et db n'acceptent le SSH que depuis le subnet front (rebond via `ProxyJump`). La base n'accepte aucun SSH depuis le back : une application compromise ne peut pas rebondir vers la base.

### Règles déclarées dans le module racine

Les règles sont définies dans un bloc `locals` du module racine, et non dans le fichier de variables :

- elles référencent les plages des subnets et l'IP d'administration, sans dupliquer de valeur
- elles constituent la conception de sécurité du projet : elles sont versionnées, relues et analysées par les outils de la CI
- le module réseau reste générique et ne connaît pas l'architecture applicative

## Aucun accès sortant implicite

Les trois subnets sont créés avec `default_outbound_access_enabled = false`.

Azure fournissait historiquement un accès internet sortant implicite aux VM sans IP publique, via une adresse partagée non maîtrisée. Ce comportement est désactivé explicitement :

- aucune VM ne peut joindre internet sans un chemin déclaré dans le code
- une VM compromise ne dispose pas d'une voie de sortie non contrôlée
- l'adresse de sortie est connue et stable

L'accès sortant nécessaire aux mises à jour des paquets est fourni par une règle sortante du Load Balancer.

## Load Balancer

Un Load Balancer public Standard avec une IP publique statique constitue l'unique point d'entrée de l'infrastructure. Il remplit trois rôles :

- **Entrée web** : les ports 80 et 443 sont transmis à un pool contenant uniquement la VM front, avec une sonde HTTP sur `/` qui retire une VM défaillante de la rotation.
- **Entrée SSH** : une règle NAT redirige un port public non standard vers le port 22 de la VM front, point de départ du rebond vers les autres tiers.
- **Sortie internet** : une règle sortante donne aux trois VM un accès sortant via l'adresse du Load Balancer.

### Deux pools distincts

Le pool d'entrée ne contient que le front, pour que le Load Balancer ne transmette jamais de trafic web vers le back ou la base. Le pool de sortie contient les trois VM. Une même carte réseau peut appartenir aux deux.

### Port SSH non standard

Le port public du SSH n'est pas 22. Ce n'est pas une mesure de sécurité — le filtrage repose sur le NSG, qui n'autorise que l'IP d'administration — mais cela réduit le bruit des scanners automatisés dans les journaux.

### SNAT désactivé sur les règles d'entrée

Lorsqu'une règle sortante et des règles d'entrée partagent la même adresse publique, Azure impose que les règles d'entrée n'assurent pas elles-mêmes la traduction sortante.

### Accès aux VM

Aucune VM ne dispose d'adresse publique. L'accès administratif passe par la règle NAT du Load Balancer vers le front, puis par rebond SSH vers les autres tiers. L'authentification par mot de passe est désactivée : seule une clé publique fournie en variable autorise la connexion.

Chaque VM porte une identité managée de type système, utilisée en phase 3 pour lire les secrets du Key Vault sans qu'aucun identifiant ne soit stocké sur la machine.

Le Load Balancer ne traduit que le trafic TCP et UDP en sortie : les tests de connectivité sortante se font en TCP, un `ping` vers internet échouant même lorsque l'accès sortant fonctionne.

## Limites connues

- **Pas de WAF** : en production, un Application Gateway avec WAF ou Azure Front Door filtrerait les attaques applicatives et terminerait le TLS. Écarté pour des raisons de coût et de périmètre.
- **IP d'administration statique** : si l'adresse publique de l'administrateur change, l'accès SSH est refusé jusqu'à la mise à jour de la variable `admin_ip` et un nouvel `apply`.
- **Région imposée** : le choix de la région est contraint par la policy de l'abonnement, et non par une exigence d'architecture.
