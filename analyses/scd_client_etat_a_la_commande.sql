-- Analyse (tâche 3.6 / C17) : retrouver l'état d'un client AU MOMENT de sa commande
-- via le SCD type 2 scd_client, et non son état courant.
--
-- Principe : on sélectionne, pour chaque commande, la version du client dont
-- l'intervalle [dbt_valid_from, dbt_valid_to) contient la date de la commande.
--
-- Remarque importante : dbt renseigne dbt_valid_from avec la date de CHARGEMENT
-- du snapshot, pas la date métier du changement. La toute première version d'un
-- client représente donc "tout le passé jusqu'au premier changement observé" :
-- on ramène sa borne basse à -infini (1900-01-01) pour que les commandes
-- antérieures au premier snapshot y soient bien rattachées.

with scd as (
    select
        *,
        case
            when dbt_valid_from = min(dbt_valid_from) over (partition by client_id)
            then '1900-01-01'::timestamp
            else dbt_valid_from
        end as valid_from_eff
    from {{ ref('scd_client') }}
),

courant as (
    select client_id, ville as ville_actuelle, segment as segment_actuel
    from {{ ref('scd_client') }}
    where dbt_valid_to is null
)

select
    f.commande_id,
    d.date_jour                         as date_commande,
    f.client_id,
    s.ville                             as ville_au_moment_commande,
    s.segment                           as segment_au_moment_commande,
    c.ville_actuelle,
    c.segment_actuel
from {{ ref('fact_commandes') }} f
join {{ ref('dim_date') }} d
    on f.date_commande_id = d.date_id
join scd s
    on s.client_id = f.client_id
   and d.date_jour >= s.valid_from_eff::date
   and (s.dbt_valid_to is null or d.date_jour < s.dbt_valid_to::date)
join courant c
    on c.client_id = f.client_id
order by f.client_id, d.date_jour
