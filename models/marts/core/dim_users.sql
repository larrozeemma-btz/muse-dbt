with users as (

    select * from {{ ref('stg_muse__users') }}

),

engagement as (

    select
        user_id,
        count(distinct track_id) filter (where n_plays > 0)   as n_tracks_played,
        sum(n_plays)                                           as n_plays,
        sum(n_skips)                                           as n_skips,
        sum(n_likes)                                           as n_likes,
        min(first_listened_at)                                 as first_listened_at,
        max(last_listened_at)                                  as last_listened_at
    from {{ ref('int_user_track_engagement') }}
    group by 1

),

top_declared_genre as (

    select user_id, genre_name as declared_favourite_genre
    from {{ ref('stg_muse__user_genre_preferences') }}
    qualify row_number() over (partition by user_id order by affinity desc, genre_name) = 1

),

top_listened_genre as (

    select user_id, affinity_key as most_listened_genre
    from {{ ref('int_user_history_affinity') }}
    where affinity_type = 'genre' and raw_points > 0
    qualify row_number() over (partition by user_id order by raw_points desc, affinity_key) = 1

)

select
    users.user_id,
    users.username,
    users.country_code,
    users.subscription_plan,
    users.signed_up_at,
    users.birth_year,
    top_declared_genre.declared_favourite_genre,
    top_listened_genre.most_listened_genre,
    coalesce(engagement.n_tracks_played, 0)     as n_tracks_played,
    coalesce(engagement.n_plays, 0)             as n_plays,
    coalesce(engagement.n_skips, 0)             as n_skips,
    coalesce(engagement.n_likes, 0)             as n_likes,
    engagement.first_listened_at,
    engagement.last_listened_at,
    -- slide 9 "cold start": new users with no listening history yet
    coalesce(engagement.n_plays, 0) = 0         as is_cold_start
from users
left join engagement         using (user_id)
left join top_declared_genre using (user_id)
left join top_listened_genre using (user_id)
