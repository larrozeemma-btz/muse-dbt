{{ config(materialized='table') }}

{#
    SCORING stage: the MUSE core algorithm, in SQL:

        FOR each song IN songList
            score ← 0.5 × genre + 0.3 × history + 0.2 × popularity
        sortedSongs ← SORT_DESCENDING(songList, score)

    One row per listener × retrieved candidate. Tracks can belong to several
    genres and several artists, so each signal takes the best match across
    them. The original pseudocode sorts with Merge Sort (O(n log n)); here the warehouse's
    sort inside a window function does it for every listener at once.
#}

with candidates as (

    select * from {{ ref('int_user_track_candidates') }}

),

users as (

    select user_id, is_cold_start from {{ ref('dim_users') }}

),

attributes as (

    select * from {{ ref('int_user_track_candidate_attributes') }}

),

-- the three per-pair signals are gathered with one union + one aggregation
-- (cheaper than three wide joins back onto the candidate table)
signal_rows as (

    select attributes.user_id, attributes.track_id,
           genre_match.genre_match_score,
           cast(null as {{ dbt.type_float() }}) as artist_affinity,
           cast(null as {{ dbt.type_float() }}) as genre_affinity
    from attributes
    inner join {{ ref('int_user_genre_match') }} as genre_match
        on  genre_match.user_id    = attributes.user_id
        and genre_match.genre_name = attributes.attribute_key
    where attributes.attribute_type = 'genre'

    union all

    select attributes.user_id, attributes.track_id,
           null,
           case when attributes.attribute_type = 'artist' then history.affinity_score end,
           case when attributes.attribute_type = 'genre'  then history.affinity_score end
    from attributes
    inner join {{ ref('int_user_history_affinity') }} as history
        on  history.user_id       = attributes.user_id
        and history.affinity_type = attributes.attribute_type
        and history.affinity_key  = attributes.attribute_key

),

pair_signals as (

    select
        user_id,
        track_id,
        max(genre_match_score)  as genre_match_score,
        max(artist_affinity)    as artist_affinity,
        max(genre_affinity)     as genre_affinity
    from signal_rows
    group by 1, 2

),

signals as (

    select
        candidates.user_id,
        candidates.track_id,
        candidates.candidate_sources,
        users.is_cold_start,
        coalesce(pair_signals.genre_match_score, 0)                     as genre_match_score,
        case
            when users.is_cold_start then null
            -- 60 % "do they love this artist", 40 % "do they listen to this genre"
            else round(0.6 * coalesce(pair_signals.artist_affinity, 0)
                     + 0.4 * coalesce(pair_signals.genre_affinity, 0), 1)
        end                                                             as listening_history_score,
        popularity.popularity_score
    from candidates
    inner join users on users.user_id = candidates.user_id
    inner join {{ ref('int_track_popularity') }} as popularity on popularity.track_id = candidates.track_id
    left join pair_signals
        on  pair_signals.user_id  = candidates.user_id
        and pair_signals.track_id = candidates.track_id

),

scored as (

    select
        *,
        case
            when is_cold_start
                then {{ muse_score_cold_start('genre_match_score', 'popularity_score') }}
            else {{ muse_score('genre_match_score', 'listening_history_score', 'popularity_score') }}
        end as recommendation_score
    from signals

)

select
    *,
    row_number() over (
        partition by user_id
        order by recommendation_score desc, popularity_score desc, track_id
    ) as recommendation_rank
from scored
