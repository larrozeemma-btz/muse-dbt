{#
    GENRE MATCH signal (50 % of the MUSE score), from onboarding answers.

    For every listener × genre that is relevant to them:
      - genre declared                       → full affinity
      - same family (e.g. deep-house ↔ techno, both "Electronic") → half
    Genres absent from this table score 0 (kept sparse on purpose:
    20k listeners × 114 genres would be mostly zeros).
#}

with preferences as (

    select * from {{ ref('stg_muse__user_genre_preferences') }}

),

families as (

    select * from {{ ref('genre_families') }}

),

declared as (

    select preferences.user_id, preferences.genre_name, families.genre_family, preferences.affinity
    from preferences
    inner join families using (genre_name)

)

select
    declared.user_id,
    families.genre_name,
    max(
        case
            when families.genre_name = declared.genre_name then declared.affinity
            else declared.affinity * 0.5
        end
    ) as genre_match_score
from declared
inner join families
    on families.genre_family = declared.genre_family
group by 1, 2
