{#
    Reproduces the MUSE deck's demo (slides 5 & 8) from the three pre-computed
    input scores, using exactly the same scoring macro as the production
    pipeline. A singular test asserts the output matches the slides.
#}

with songs as (

    select * from {{ ref('presentation_song_scores') }}

),

scored as (

    select
        track_title,
        genre_name,
        genre_match_score,
        listening_history_score,
        popularity_score,
        {{ muse_score('genre_match_score', 'listening_history_score', 'popularity_score') }} as recommendation_score
    from songs

)

select
    row_number() over (order by recommendation_score desc, track_title) as recommendation_rank,
    *
from scored
where true
qualify row_number() over (order by recommendation_score desc, track_title) <= {{ var('muse_top_n') }}
order by recommendation_rank
