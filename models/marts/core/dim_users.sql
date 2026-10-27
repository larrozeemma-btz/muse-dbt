{% set as_of = "timestamp '" ~ var('muse_as_of_date') ~ " 23:59:59'" %}

with users as (

    select * from {{ ref('stg_muse__users') }}

),

listening as (

    select
        user_id,
        sum(case when event_type = 'play' then 1 else 0 end)     as lifetime_plays,
        sum(case when event_type = 'skip' then 1 else 0 end)     as lifetime_skips,
        sum(case when event_type = 'like' then 1 else 0 end)     as lifetime_likes,
        count(distinct case when is_stream then track_id end) as lifetime_unique_tracks,
        count(distinct session_id)                      as lifetime_sessions,
        round(sum(case when is_stream then ms_played end) / 3600000.0, 1) as lifetime_hours,
        min(event_at)                                   as first_listened_at,
        max(event_at)                                   as last_listened_at
    from {{ ref('fct_listening_events') }}
    group by 1

),

current_subscription as (

    select user_id, plan as current_plan, monthly_price_eur as current_monthly_price_eur
    from {{ ref('stg_muse__subscriptions') }}
    where started_at is not null
    qualify row_number() over (partition by user_id order by started_at desc) = 1

),

ever_paid as (

    select user_id, max(case when plan <> 'free' then 1 else 0 end) = 1 as has_ever_paid
    from {{ ref('stg_muse__subscriptions') }}
    group by 1

),

onboarding as (

    select user_id, count(*) as n_declared_genres
    from {{ ref('stg_muse__user_genre_preferences') }}
    group by 1

),

top_genre as (

    select user_id, affinity_key as favourite_genre
    from {{ ref('int_user_history_affinity') }}
    where affinity_type = 'genre' and raw_points > 0
    qualify row_number() over (partition by user_id order by raw_points desc, affinity_key) = 1

)

select
    users.user_id,
    users.signed_up_at,
    {{ month_start('users.signed_up_at') }}  as signup_cohort_month,
    users.country_code,
    users.birth_year,
    case
        when extract(year from {{ as_of }}) - users.birth_year < 25 then '18-24'
        when extract(year from {{ as_of }}) - users.birth_year < 35 then '25-34'
        when extract(year from {{ as_of }}) - users.birth_year < 45 then '35-44'
        when extract(year from {{ as_of }}) - users.birth_year < 55 then '45-54'
        else '55+'
    end                                                     as age_band,
    users.acquisition_channel,
    users.primary_device,
    current_subscription.current_plan,
    current_subscription.current_monthly_price_eur,
    coalesce(ever_paid.has_ever_paid, false)                as has_ever_paid,
    coalesce(onboarding.n_declared_genres, 0) > 0           as completed_onboarding,
    top_genre.favourite_genre,
    coalesce(listening.lifetime_plays, 0)                   as lifetime_plays,
    coalesce(listening.lifetime_skips, 0)                   as lifetime_skips,
    coalesce(listening.lifetime_likes, 0)                   as lifetime_likes,
    coalesce(listening.lifetime_unique_tracks, 0)           as lifetime_unique_tracks,
    coalesce(listening.lifetime_sessions, 0)                as lifetime_sessions,
    coalesce(listening.lifetime_hours, 0)                   as lifetime_hours,
    listening.first_listened_at,
    listening.last_listened_at,
    -- "cold start": no listening history to learn from yet
    coalesce(listening.lifetime_plays, 0) = 0               as is_cold_start,
    case
        when listening.last_listened_at is null                                  then 'never_active'
        when listening.last_listened_at >= {{ timestamp_add_days(as_of, -7) }}         then 'active'
        when listening.last_listened_at >= {{ timestamp_add_days(as_of, -30) }}        then 'at_risk'
        else 'churned'
    end                                                     as lifecycle_status,
    users.deleted_at is not null                            as is_deleted
from users
left join listening            using (user_id)
left join current_subscription using (user_id)
left join ever_paid            using (user_id)
left join onboarding           using (user_id)
left join top_genre            using (user_id)
