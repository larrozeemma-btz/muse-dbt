-- How diverse are the playlists? (slide 10: "mix strong matches with a few new artists")
-- Compile with `dbt compile -s genre_diversity_of_recommendations` and run the SQL in DuckDB.
select
    user_id,
    count(distinct genre_name)  as n_genres,
    count(distinct artist_name) as n_artists,
    round(avg(recommendation_score), 1) as avg_score
from {{ ref('rpt_top_recommendations') }}
group by 1
order by n_genres, n_artists
