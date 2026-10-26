{#
    The MUSE core algorithm (slide 6), in SQL:

        FOR each song IN songList
            score ← 0.5 × genre + 0.3 × history + 0.2 × popularity
        sortedSongs ← SORT_DESCENDING(songList, score)

    One row per listener × candidate track, with the three input signals,
    the final score and the listener-level rank. The deck sorts with Merge
    Sort (O(n log n)); here the warehouse's ORDER BY inside a window function
    does the same job.
#}

with candidates as (

    select * from {{ ref('int_user_track_candidates') }}

),

users as (

    select user_id, is_cold_start from {{ ref('dim_users') }}

),

genre_match as (

    select * from {{ ref('int_user_genre_match') }}

),

history as (

    select * from {{ ref('int_user_history_affinity') }}

),

popularity as (

    select track_id, popularity_score from {{ ref('int_track_popularity') }}

),

signals as (

    select
        candidates.user_id,
        candidates.track_id,
        users.is_cold_start,
        coalesce(genre_match.genre_match_score, 0)                         as genre_match_score,
        -- history: 60 % "do they like this artist", 40 % "do they listen to this genre"
        case
            when users.is_cold_start then null
            else round(
                  0.6 * coalesce(artist_history.affinity_score, 0)
                + 0.4 * coalesce(genre_history.affinity_score, 0)
            , 1)
        end                                                                 as listening_history_score,
        popularity.popularity_score
    from candidates
    inner join users using (user_id)
    left join genre_match
        on  genre_match.user_id    = candidates.user_id
        and genre_match.genre_name = candidates.genre_name
    left join history as artist_history
        on  artist_history.user_id       = candidates.user_id
        and artist_history.affinity_type = 'artist'
        and artist_history.affinity_key  = candidates.artist_id
    left join history as genre_history
        on  genre_history.user_id       = candidates.user_id
        and genre_history.affinity_type = 'genre'
        and genre_history.affinity_key  = candidates.genre_name
    left join popularity using (track_id)

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
    user_id,
    track_id,
    is_cold_start,
    genre_match_score,
    listening_history_score,
    popularity_score,
    recommendation_score,
    row_number() over (
        partition by user_id
        -- deterministic tie-breaks: more popular first, then track id
        order by recommendation_score desc, popularity_score desc, track_id
    ) as recommendation_rank
from scored
