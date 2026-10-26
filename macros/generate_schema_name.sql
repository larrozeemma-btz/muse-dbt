{#
    Use the custom schema name as-is (raw, staging, core, ...) instead of
    dbt's default "<target_schema>_<custom_schema>" concatenation, so the
    warehouse layout mirrors the project layers.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
