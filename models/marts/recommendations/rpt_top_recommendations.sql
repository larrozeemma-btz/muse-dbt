{#
    topN ← FIRST MIN(N, LENGTH(sortedSongs)) songs   (slide 6, N = var muse_top_n)

    The playlist served to each listener, enriched for display.
#}

with scores as (

    select * from {{ ref('fct_recommendation_scores') }}
    where recommendation_rank <= {{ var('muse_top_n') }}

),

tracks as (

    select * from {{ ref('dim_tracks') }}

)

select
    scores.user_id,
    scores.recommendation_rank,
    scores.track_id,
    tracks.track_title,
    tracks.artist_name,
    tracks.genre_name,
    scores.recommendation_score,
    scores.genre_match_score,
    scores.listening_history_score,
    scores.popularity_score,
    scores.is_cold_start,
    -- explainability (slide 2 "hidden reasoning"): which signal contributed most?
    case
        when scores.is_cold_start then 'genre match (new listener)'
        when {{ var('muse_weight_genre') }} * scores.genre_match_score
             >= greatest({{ var('muse_weight_history') }} * scores.listening_history_score,
                         {{ var('muse_weight_popularity') }} * scores.popularity_score)
            then 'matches your favourite genres'
        when {{ var('muse_weight_history') }} * scores.listening_history_score
             >= {{ var('muse_weight_popularity') }} * scores.popularity_score
            then 'similar to what you listen to'
        else 'trending with other listeners'
    end as recommendation_reason
from scores
left join tracks using (track_id)
