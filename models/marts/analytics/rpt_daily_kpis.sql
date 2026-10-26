{#
    One row per day: audience, consumption, quality and paying base.
    Typical "north-star" dashboard feed.
#}

with days as (

    select date_day
    from {{ ref('dim_date') }}
    where date_day between date '2024-01-01' and date '{{ var("muse_as_of_date") }}'

),

listening as (

    select
        event_date                                                  as date_day,
        count(distinct case when is_stream then user_id end)            as daily_active_users,
        sum(case when is_stream then 1 else 0 end)                           as streams,
        sum(case when event_type = 'skip' then 1 else 0 end)                 as skips,
        sum(case when event_type = 'like' then 1 else 0 end)                 as likes,
        round(sum(case when is_stream then ms_played end) / 3600000.0, 1) as hours_listened
    from {{ ref('fct_listening_events') }}
    group by 1

),

signups as (

    select cast(signed_up_at as date) as date_day, count(*) as new_users
    from {{ ref('dim_users') }}
    group by 1

),

paying as (

    select
        days.date_day,
        count(distinct subscriptions.user_id)       as paying_subscribers,
        round(sum(subscriptions.monthly_price_eur), 2) as mrr_eur
    from days
    inner join {{ ref('fct_subscriptions') }} as subscriptions
        on  subscriptions.is_paid
        and cast(subscriptions.started_at as date) <= days.date_day
        and (subscriptions.ended_at is null or cast(subscriptions.ended_at as date) > days.date_day)
    group by 1

)

select
    days.date_day,
    coalesce(signups.new_users, 0)                                  as new_users,
    coalesce(listening.daily_active_users, 0)                       as daily_active_users,
    coalesce(listening.streams, 0)                                  as streams,
    coalesce(listening.hours_listened, 0)                           as hours_listened,
    round(listening.skips / nullif(listening.streams, 0), 3)        as skip_rate,
    round(listening.likes / nullif(listening.streams, 0), 4)        as like_rate,
    round(listening.streams / nullif(listening.daily_active_users, 0), 1) as streams_per_dau,
    coalesce(paying.paying_subscribers, 0)                          as paying_subscribers,
    coalesce(paying.mrr_eur, 0)                                     as mrr_eur
from days
left join listening using (date_day)
left join signups   using (date_day)
left join paying    using (date_day)
