{# Deterministic hash key from one or more columns (dependency-free dbt_utils.generate_surrogate_key). #}
{% macro surrogate_key(columns) -%}
    {%- set parts = [] -%}
    {%- for c in columns -%}
        {%- do parts.append("coalesce(cast(" ~ c ~ " as " ~ dbt.type_string() ~ "), '_null_')") -%}
    {%- endfor -%}
    {{ dbt.hash("concat(" ~ parts | join(", '|', ") ~ ")") }}
{%- endmacro %}
