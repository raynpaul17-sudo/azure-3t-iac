# azure-3t-iac

Déployer une application web dans le cloud aboutit souvent à des ressources trop exposées, des secrets éparpillés dans le code et les pipelines, des permissions trop larges, et une infrastructure que personne ne sait reconstruire.

Ce projet déploie une application trois tiers (web, applicatif, base de données) sur Azure en appliquant le principe du moindre privilège : réseaux segmentés où chaque tier n'atteint que ce dont il a besoin, identités sans secret limitées au strict nécessaire, et secrets gérés hors du code.

L'infrastructure est créée, testée et détruite via une pipeline CI/CD, avec des contrôles de sécurité intégrés dès la conception.