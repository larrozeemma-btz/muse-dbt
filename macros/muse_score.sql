{#
    MUSE recommendation score:
        score = 0.5 × genre + 0.3 × history + 0.2 × popularity

    Weights come from project vars so they can be tuned without touching SQL:
        dbt build --vars '{muse_weight_genre: 0.6, muse_weight_history: 0.2}'
#}
{% macro muse_score(genre_col, history_col, popularity_col) -%}
    round(
          {{ var('muse_weight_genre') }}      * {{ genre_col }}
        + {{ var('muse_weight_history') }}    * {{ history_col }}
        + {{ var('muse_weight_popularity') }} * {{ popularity_col }}
    , 1)
{%- endmacro %}


{#
    Cold-start variant: the listener has no history yet,
    so the history weight is redistributed proportionally across the two
    remaining signals instead of silently scoring history as 0.
#}
{% macro muse_score_cold_start(genre_col, popularity_col) -%}
    {%- set wg = var('muse_weight_genre') -%}
    {%- set wp = var('muse_weight_popularity') -%}
    round(
          ({{ wg }} / ({{ wg }} + {{ wp }})) * {{ genre_col }}
        + ({{ wp }} / ({{ wg }} + {{ wp }})) * {{ popularity_col }}
    , 1)
{%- endmacro %}


{# Engagement points for an event type, driven by the `muse_event_points` var. #}
{% macro event_points(event_type_col) -%}
    case {{ event_type_col }}
    {%- for event_type, points in var('muse_event_points').items() %}
        when '{{ event_type }}' then {{ points }}
    {%- endfor %}
        else 0
    end
{%- endmacro %}
