-- Governance alert: traffic no channel rule covers should stay under 2 %.
-- Warns (does not block) so marketing ops adds a rule for the new source.
{{ config(severity='warn') }}

select unmapped_share
from (
    select avg(case when channel = 'unmapped' then 1.0 else 0.0 end) as unmapped_share
    from {{ ref('int_web_sessions_channeled') }}
) as shares
where unmapped_share > 0.02
