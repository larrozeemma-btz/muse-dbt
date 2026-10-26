{#
    Cross-database helpers. The project runs on DuckDB (local, free) and on
    BigQuery (dbt Cloud). Anything dialect-specific lives here, dispatched on
    the active adapter: `default__` = DuckDB, `bigquery__` = BigQuery.
#}


{# Parse the two timestamp formats sent by the client SDKs; null if neither matches. #}
{% macro parse_event_timestamp(col) %}{{ return(adapter.dispatch('parse_event_timestamp')(col)) }}{% endmacro %}

{% macro default__parse_event_timestamp(col) -%}
    coalesce(
        try_strptime({{ col }}, '%Y-%m-%dT%H:%M:%SZ'),
        try_strptime({{ col }}, '%Y-%m-%d %H:%M:%S')
    )
{%- endmacro %}

{% macro bigquery__parse_event_timestamp(col) -%}
    coalesce(
        safe.parse_timestamp('%Y-%m-%dT%H:%M:%SZ', {{ col }}),
        safe.parse_timestamp('%Y-%m-%d %H:%M:%S', {{ col }})
    )
{%- endmacro %}


{# Explode a delimited string column into rows: (<key>, item, position starting at 1). #}
{% macro explode_delimited(relation, key_col, list_col, delimiter) %}{{ return(adapter.dispatch('explode_delimited')(relation, key_col, list_col, delimiter)) }}{% endmacro %}

{% macro default__explode_delimited(relation, key_col, list_col, delimiter) -%}
    select {{ key_col }}, trim(parts[pos]) as item, pos as position
    from (select {{ key_col }}, string_split({{ list_col }}, '{{ delimiter }}') as parts from {{ relation }}) as s,
         unnest(generate_series(1, len(parts))) as t(pos)
{%- endmacro %}

{% macro bigquery__explode_delimited(relation, key_col, list_col, delimiter) -%}
    select {{ key_col }}, trim(part) as item, offset_ + 1 as position
    from {{ relation }},
         unnest(split({{ list_col }}, '{{ delimiter }}')) as part with offset as offset_
{%- endmacro %}


{# One row per day between two date literals ('YYYY-MM-DD'), column `date_day`. #}
{% macro date_series(start_date, end_date) %}{{ return(adapter.dispatch('date_series')(start_date, end_date)) }}{% endmacro %}

{% macro default__date_series(start_date, end_date) -%}
    select cast(d as date) as date_day
    from generate_series(date '{{ start_date }}', date '{{ end_date }}', interval 1 day) as t(d)
{%- endmacro %}

{% macro bigquery__date_series(start_date, end_date) -%}
    select date_day
    from unnest(generate_date_array(date '{{ start_date }}', date '{{ end_date }}')) as date_day
{%- endmacro %}


{# Shift a TIMESTAMP by n days (n can be negative). #}
{% macro timestamp_add_days(ts, n) %}{{ return(adapter.dispatch('timestamp_add_days')(ts, n)) }}{% endmacro %}
{% macro default__timestamp_add_days(ts, n) -%} ({{ ts }} + interval ({{ n }}) day) {%- endmacro %}
{% macro bigquery__timestamp_add_days(ts, n) -%} timestamp_add({{ ts }}, interval ({{ n }}) day) {%- endmacro %}


{# Shift a DATE by n days, returning a DATE. #}
{% macro date_add_days(d, n) %}{{ return(adapter.dispatch('date_add_days')(d, n)) }}{% endmacro %}
{% macro default__date_add_days(d, n) -%} cast({{ d }} + interval ({{ n }}) day as date) {%- endmacro %}
{% macro bigquery__date_add_days(d, n) -%} date_add({{ d }}, interval ({{ n }}) day) {%- endmacro %}


{# First day of the month of a date/timestamp, as a DATE. #}
{% macro month_start(expr) %}{{ return(adapter.dispatch('month_start')(expr)) }}{% endmacro %}
{% macro default__month_start(expr) -%} cast(date_trunc('month', {{ expr }}) as date) {%- endmacro %}
{% macro bigquery__month_start(expr) -%} date_trunc(cast({{ expr }} as date), month) {%- endmacro %}


{# ISO day of week (1 = Monday … 7 = Sunday). #}
{% macro iso_day_of_week(d) %}{{ return(adapter.dispatch('iso_day_of_week')(d)) }}{% endmacro %}
{% macro default__iso_day_of_week(d) -%} isodow({{ d }}) {%- endmacro %}
{% macro bigquery__iso_day_of_week(d) -%} mod(extract(dayofweek from {{ d }}) + 5, 7) + 1 {%- endmacro %}


{# Day / month names, e.g. 'Monday', 'January'. #}
{% macro format_date_name(d, part) %}{{ return(adapter.dispatch('format_date_name')(d, part)) }}{% endmacro %}
{% macro default__format_date_name(d, part) -%} strftime({{ d }}, '{{ "%A" if part == "day" else "%B" }}') {%- endmacro %}
{% macro bigquery__format_date_name(d, part) -%} format_date('{{ "%A" if part == "day" else "%B" }}', {{ d }}) {%- endmacro %}
