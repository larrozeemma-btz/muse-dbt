{#
    Channel grouping: every session gets exactly one channel from the ordered
    rules in the `channel_grouping_rules` seed (first match wins). Sessions with
    no UTM source are "direct"; sessions no rule covers are "unmapped" — a data
    quality signal surfaced by a test, not silently lumped into "other".
#}

with sessions as (

    select
        *,
        coalesce(utm_source, '(direct)') as source_key,
        coalesce(utm_medium, '(none)')   as medium_key
    from {{ ref('stg_web__sessions') }}

),

rules as (

    select * from {{ ref('channel_grouping_rules') }}

),

matched as (

    select
        sessions.session_id,
        rules.channel,
        rules.rule_order
    from sessions
    inner join rules
        on  (rules.utm_source = '*' or rules.utm_source = sessions.source_key)
        and (rules.utm_medium = '*' or rules.utm_medium = sessions.medium_key)
    where true
    qualify row_number() over (partition by sessions.session_id order by rules.rule_order) = 1

)

select
    sessions.session_id,
    sessions.anonymous_id,
    sessions.user_id,
    sessions.session_started_at,
    sessions.utm_source,
    sessions.utm_medium,
    sessions.utm_campaign,
    sessions.landing_page,
    sessions.device_type,
    coalesce(matched.channel, 'unmapped')   as channel,
    matched.rule_order                      as matched_rule
from sessions
left join matched on matched.session_id = sessions.session_id
