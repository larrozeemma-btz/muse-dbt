{#
    How does each way of reaching a song perform? Lets the team measure the
    MUSE recommendation surface (launched June 2025) against playlists,
    search, radio, etc. — lower skip rate / higher like rate = better match.
#}

select
    {{ month_start('event_date') }}                                 as month_start,
    play_context,
    sum(case when is_stream then 1 else 0 end)                               as streams,
    count(distinct case when is_stream then user_id end)                as listeners,
    round(sum(case when event_type = 'skip' then 1 else 0 end)
          / nullif(sum(case when is_stream then 1 else 0 end), 0), 3)        as skip_rate,
    round(sum(case when event_type in ('like', 'add_to_playlist') then 1 else 0 end)
          / nullif(sum(case when is_stream then 1 else 0 end), 0), 4)        as save_rate,
    round(avg(case when event_type = 'play' then completion_rate end), 3) as avg_completion_rate
from {{ ref('fct_listening_events') }}
group by 1, 2
