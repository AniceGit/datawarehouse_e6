# Supervision de l'entrepot (Prometheus + Grafana)

Ajoute une supervision automatique de l'entrepot, en complement de la journalisation et de l'alerte
par courriel. Prometheus collecte les mesures en continu, Grafana les affiche dans des tableaux de bord.

## Composants

- **node-exporter** : mesures de la machine (processeur, memoire, disque).
- **postgres-exporter** : mesures de PostgreSQL (taille de la base, connexions, transactions).
- **prometheus** : collecte et stocke les mesures toutes les 15 secondes.
- **grafana** : affiche les tableaux de bord, branche sur Prometheus.

Tout tourne en reseau hote, car PostgreSQL n'ecoute que sur 127.0.0.1.

## Demarrer

```bash
cp .env.example .env     # puis renseigner le mot de passe de la base et de Grafana
docker compose up -d
```

## Acceder

- Grafana : http://localhost:3000 (compte admin, mot de passe defini dans .env)
- Prometheus : http://localhost:9090

## Arreter

```bash
docker compose down        # arrete (conserve les donnees)
docker compose down -v     # arrete et supprime aussi les donnees stockees
```

Le fichier `.env` (mots de passe) n'est pas versionne.
