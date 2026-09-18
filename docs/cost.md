# Coût et cycle de vie

## Modèle éphémère

L'infrastructure n'est pas maintenue en fonctionnement continu. Le cycle nominal est `apply`, utilisation ou démonstration, puis `destroy`. Le coût réel se limite donc aux heures d'utilisation effective.

Les ressources facturées à l'heure dès leur création, même sans trafic, sont le Load Balancer Standard, l'adresse IP publique statique et les VM. Un `destroy` complet est effectué à la fin de chaque session, et l'absence de ressource résiduelle est vérifiée avec `az resource list`.

## Ordre de grandeur

Une VM `Standard_B2ats_v2` en région `swedencentral` coûte environ 7 dollars par mois en fonctionnement continu, soit environ un centime par heure. Une session de travail de quelques heures sur l'ensemble de l'infrastructure reste de l'ordre de l'euro.

## Garde-fou budgétaire

Un budget mensuel de 20 euros est configuré sur l'abonnement, avec des alertes par courriel à 50 % et 100 % du coût réel, ainsi qu'à 100 % du coût prévisionnel. Les alertes sont envoyées à une adresse personnelle, indépendante du compte de l'établissement qui porte l'abonnement.
