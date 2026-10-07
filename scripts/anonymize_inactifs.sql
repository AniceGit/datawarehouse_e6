-- Anonymisation des clients inactifs (tâche 3.5 — conformité RGPD, minimisation).
-- Objectif : rendre non identifiables les clients sans commande depuis > N mois,
-- tout en conservant leur ligne (client_id) pour ne pas casser les analyses agrégées.
--
-- IMPORTANT : la donnée personnelle "source de vérité" est en amont (système
-- opérationnel / seed raw_clients). L'entrepôt étant reconstruit depuis la source à
-- chaque `dbt build`, la purge DURABLE doit s'appliquer à la SOURCE. Ce script cible
-- donc raw_clients (qui représente la source dans notre TP).
--
-- Fréquence prévue : mensuelle, automatisée via cron (voir docs/rgpd_registre_et_purge.md).
-- L'anonymisation est IRRÉVERSIBLE (contrairement à la pseudonymisation).

\set seuil_mois 36

-- 1) DRY-RUN : lister les clients qui SERAIENT anonymisés (à exécuter avant la purge)
--    (aucune modification)
-- select client_id, nom, email
-- from raw_clients
-- where client_id not in (
--     select distinct client_id from raw_commandes
--     where date_commande::date >= (now() - (:'seuil_mois' || ' months')::interval)::date
-- );

-- 2) PURGE réelle (anonymisation)
update raw_clients
set nom   = 'ANONYMISE',
    prenom = 'ANONYMISE',
    email  = 'anonymise_' || client_id || '@example.invalid',
    ville  = 'ANONYMISE',
    code_postal = NULL
where client_id not in (
    select distinct client_id from raw_commandes
    where date_commande::date >= (now() - (:'seuil_mois' || ' months')::interval)::date
);
