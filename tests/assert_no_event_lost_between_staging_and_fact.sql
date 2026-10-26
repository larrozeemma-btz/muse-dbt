-- Reconciliation: the incremental fact table holds exactly the deduplicated staging events.
select staging_events, fact_events
from (
    select
        (select count(*) from {{ ref('stg_muse__listening_events') }}) as staging_events,
        (select count(*) from {{ ref('fct_listening_events') }})       as fact_events
) as counts
where staging_events <> fact_events
