{#
    Product-led funnel by month of first visit and first-touch channel:
        visitor → signup → activated (≥ N plays in the first days) → paid within 90 days
    Each stage is a strict subset of the previous one (tested).
#}

with journeys as (

    select
        person_key,
        min(touched_at)                                                         as first_visit_at,
        max(case when is_identified then 1 else 0 end) = 1                      as is_identified
    from {{ ref('int_marketing_touchpoints') }}
    where motion = 'plg'
    group by 1

),

first_touch as (

    select person_key, channel as first_touch_channel
    from {{ ref('int_marketing_touchpoints') }}
    where motion = 'plg'
    qualify row_number() over (partition by person_key order by touched_at, touchpoint_id) = 1

),

users as (

    select user_id, signed_up_at from {{ ref('dim_users') }}

),

early_plays as (

    select events.user_id, count(*) as plays
    from {{ ref('fct_listening_events') }} as events
    inner join users using (user_id)
    where events.event_type = 'play'
      and events.event_at < {{ timestamp_add_days('users.signed_up_at', var('muse_activation_window_days')) }}
    group by 1

),

first_paid as (

    select user_id, min(started_at) as paid_at
    from {{ ref('fct_subscriptions') }}
    where is_paid
    group by 1

),

staged as (

    select
        {{ month_start('journeys.first_visit_at') }}                            as month_start,
        first_touch.first_touch_channel,
        journeys.person_key,
        users.user_id is not null                                               as signed_up,
        coalesce(early_plays.plays, 0) >= {{ var('muse_activation_plays') }}    as activated,
        first_paid.paid_at is not null
            and first_paid.paid_at <= {{ timestamp_add_days('users.signed_up_at', 90) }} as paid_90d
    from journeys
    inner join first_touch using (person_key)
    left join users        on users.user_id = journeys.person_key
    left join early_plays  on early_plays.user_id = journeys.person_key
    left join first_paid   on first_paid.user_id = journeys.person_key

)

select
    month_start,
    first_touch_channel,
    count(*)                                                                    as visitors,
    sum(case when signed_up then 1 else 0 end)                                  as signups,
    sum(case when signed_up and activated then 1 else 0 end)                    as activated_users,
    sum(case when signed_up and paid_90d then 1 else 0 end)                     as paid_within_90d,
    round(sum(case when signed_up then 1 else 0 end) / nullif(count(*), 0), 4)  as visit_to_signup_rate,
    round(sum(case when signed_up and activated then 1 else 0 end)
          / nullif(sum(case when signed_up then 1 else 0 end), 0), 4)           as activation_rate,
    round(sum(case when signed_up and paid_90d then 1 else 0 end)
          / nullif(sum(case when signed_up then 1 else 0 end), 0), 4)           as signup_to_paid_rate
from staged
group by 1, 2
