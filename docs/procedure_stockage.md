# Procédure — Augmenter l'espace de stockage PostgreSQL (cas d'usage)

_Démarche : **surveiller → décider → agir → vérifier**. État actuel (2026-09-10) : base ≈ 8,8 Mo,
volume disque à 33 % (232 Go libres) — aucune tension, mais la procédure doit exister pour le jour où._

## 1. Surveiller (mesurer avant d'agir)

```sql
-- taille de la base
SELECT pg_size_pretty(pg_database_size('datawarehouse_e6'));
-- taille par table (les plus grosses d'abord)
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) AS taille
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```
```bash
# espace du volume disque qui héberge la base
df -h /
# où sont physiquement les données
sudo -u postgres psql -p 5433 -c "SHOW data_directory;"
```
À suivre dans le tableau de bord de maintenance (voir `organisation_maintenance.md`) : déclencher une
action quand le volume dépasse ~80 %.

## 2. Décider (choisir la bonne réponse)

| Situation | Réponse adaptée |
|---|---|
| Le disque se remplit, mais la base contient de la donnée obsolète | **Ménage** d'abord (§3.A) |
| La base grossit légitimement, disque bientôt plein | **Étendre le volume** (§3.B) |
| On veut répartir la charge sur un autre disque | **Tablespace** dédié (§3.C) |

## 3. Agir

### A. Ménage (souvent suffisant, à faire en premier)
```sql
VACUUM (ANALYZE);                 -- récupère l'espace des lignes mortes, met à jour les stats
```
- Appliquer la **rétention** : purge/anonymisation des vieilles données (voir `rgpd_registre_et_purge.md`),
  suppression des tables/vues orphelines.
- Vérifier qu'aucun dump de backup ne s'accumule sur le même disque (rétention gérée par
  `scripts/backup.sh`).

### B. Étendre le volume disque (le plus courant)
Le stockage réel est géré par l'OS, pas par PostgreSQL. Selon l'infrastructure :
- **VM / cloud** : agrandir le disque dans la console (AWS EBS, etc.), puis étendre la partition et le
  système de fichiers à chaud (`growpart` + `resize2fs`).
- **LVM** : `lvextend -r -L +50G /dev/mapper/...` (étend le volume logique et le FS).
PostgreSQL profite automatiquement de l'espace supplémentaire, sans changement de config.

### C. Ajouter un tablespace sur un autre disque
Pour placer certains objets sur un stockage distinct (ex. un disque plus rapide/plus gros) :
```sql
-- 1) créer le tablespace sur un dossier d'un autre volume (dossier possédé par l'utilisateur postgres)
CREATE TABLESPACE ts_gros LOCATION '/mnt/disque2/pgdata';
-- 2) y déplacer une grosse table
ALTER TABLE fact_commandes SET TABLESPACE ts_gros;
-- 3) ou y créer les futurs objets par défaut pour cette base
ALTER DATABASE datawarehouse_e6 SET default_tablespace = ts_gros;
```
(Actuellement seuls les tablespaces par défaut existent : `pg_default`, `pg_global`.)

## 4. Vérifier
- Re-mesurer (`df -h`, `pg_database_size`) : l'espace libre a bien augmenté.
- `dbt build` toujours vert (aucune régression liée au déplacement d'objets).
- Consigner l'opération (ticket + tableau de bord).

## 5. En entreprise
Stockage sur volume élastique (cloud) avec **alerte automatique** de saturation, croissance suivie dans
un dashboard, et politique de rétention/archivage formalisée. L'ajout d'espace devient une opération
routinière déclenchée par seuil, sans interruption de service.

## 6. Note — augmenter la capacité de calcul
Distincte du stockage (disque), la **capacité de calcul** (CPU/RAM) se règle autrement :
- **Verticalement** : plus de CPU/RAM sur le serveur, puis ajuster `postgresql.conf`
  (`shared_buffers`, `work_mem`, `max_parallel_workers`) — nécessite un redémarrage.
- **Optimisation** : ajouter des **index** sur les colonnes de jointure/filtre les plus sollicitées,
  utiliser un **pool de connexions** (PgBouncer) pour absorber les pics.
- **Horizontalement** : des **réplicas en lecture** pour délester les requêtes analytiques du serveur
  principal (lecture sur le réplica, écriture sur le primaire).
Comme pour le stockage : surveiller (temps de requête, charge CPU dans le tableau de bord) → décider →
agir → vérifier.
