{{ config(materialized='table') }}

{#
    RETRIEVAL stage. Scoring 20k listeners × 90k tracks (1.8 billion pairs)
    is wasteful, so — like production recommenders — a cheap retrieval step
    first narrows each listener's pool to a few hundred plausible tracks:

      1. genre    : most popular tracks of the listener's top genres
                    (declared at onboarding + actually listened)
      2. artist   : more tracks from the artists they engage with most
      3. trending : global top tracks — the cold-start safety net

    Already-heard tracks are then removed (discovery mode). The scoring stage
    (`fct_recommendation_scores`) ranks what is left.
#}

with users as (

    select user_id from {{ ref('stg_muse__users') }}

),

popularity as (

    select track_id, popularity_score from {{ ref('int_track_popularity') }}

),

-- 1. genre retrieval ---------------------------------------------------------
user_genre_scores as (

    select user_id, genre_name, max(score) as score
    from (
        select user_id, genre_name, genre_match_score as score
        from {{ ref('int_user_genre_match') }}
        union all
        select user_id, affinity_key, affinity_score
        from {{ ref('int_user_history_affinity') }}
        where affinity_type = 'genre'
    )
    group by 1, 2

),

user_genres as (

    select user_id, genre_name
    from user_genre_scores
    where score > 0
    qualify row_number() over (partition by user_id order by score desc, genre_name)
            <= {{ var('muse_candidate_genres_per_user') }}

),

genre_top_tracks as (

    select track_genres.genre_name, track_genres.track_id
    from {{ ref('stg_spotify__track_genres') }} as track_genres
    inner join popularity using (track_id)
    where popularity.popularity_score is not null
    qualify row_number() over (
        partition by track_genres.genre_name order by popularity.popularity_score desc, track_genres.track_id
    ) <= {{ var('muse_candidates_per_genre') }}

),

from_genres as (

    select user_genres.user_id, genre_top_tracks.track_id, 'genre' as candidate_source
    from user_genres
    inner join genre_top_tracks using (genre_name)

),

-- 2. artist retrieval --------------------------------------------------------
user_artists as (

    select user_id, affinity_key as artist_id
    from {{ ref('int_user_history_affinity') }}
    where affinity_type = 'artist' and raw_points > 0
    qualify row_number() over (partition by user_id order by raw_points desc, affinity_key)
            <= {{ var('muse_candidate_artists_per_user') }}

),

artist_top_tracks as (

    select track_artists.artist_id, track_artists.track_id
    from {{ ref('stg_spotify__track_artists') }} as track_artists
    inner join popularity using (track_id)
    where popularity.popularity_score is not null
    qualify row_number() over (
        partition by track_artists.artist_id order by popularity.popularity_score desc, track_artists.track_id
    ) <= {{ var('muse_candidates_per_artist') }}

),

from_artists as (

    select user_artists.user_id, artist_top_tracks.track_id, 'artist' as candidate_source
    from user_artists
    inner join artist_top_tracks using (artist_id)

),

-- 3. trending fallback -------------------------------------------------------
trending as (

    select track_id
    from popularity
    order by popularity_score desc, track_id
    limit {{ var('muse_trending_candidates') }}

),

from_trending as (

    select users.user_id, trending.track_id, 'trending' as candidate_source
    from users
    cross join trending

),

all_candidates as (

    select * from from_genres
    union all
    select * from from_artists
    union all
    select * from from_trending

)

select
    all_candidates.user_id,
    all_candidates.track_id,
    string_agg(distinct all_candidates.candidate_source, ',' order by all_candidates.candidate_source) as candidate_sources
from all_candidates
{% if var('muse_exclude_listened_tracks') %}
left join {{ ref('int_user_track_engagement') }} as heard
    on  heard.user_id  = all_candidates.user_id
    and heard.track_id = all_candidates.track_id
    and (heard.n_plays > 0 or heard.n_likes > 0)
where heard.track_id is null
{% endif %}
group by 1, 2
