{#
    GENRE MATCH signal (50 % of the MUSE score).

    For every listener × genre in the taxonomy: how well does this genre fit
    the genres the listener declared at onboarding?
      - exact genre declared           → full affinity
      - same parent family (Pop, Rock) → half the affinity ("Dream Pop" ≈ "Synth Pop")
      - otherwise                      → 0
#}

with preferences as (

    select * from {{ ref('stg_muse__user_genre_preferences') }}

),

genres as (

    select * from {{ ref('stg_muse__genres') }}

),

users as (

    select user_id from {{ ref('stg_muse__users') }}

),

declared as (

    select
        preferences.user_id,
        preferences.genre_name,
        genres.parent_genre,
        preferences.affinity
    from preferences
    inner join genres using (genre_name)

),

scored as (

    select
        users.user_id,
        genres.genre_name,
        max(
            case
                when declared.genre_name = genres.genre_name     then declared.affinity
                when declared.parent_genre = genres.parent_genre then declared.affinity * 0.5
                else 0
            end
        ) as genre_match_score
    from users
    cross join genres
    left join declared
        on declared.user_id = users.user_id
    group by 1, 2

)

select
    user_id,
    genre_name,
    coalesce(genre_match_score, 0) as genre_match_score
from scored
