{#
    Where each layer lands:
      - production (dbt Cloud prod environment) and local DuckDB:
            the layer name as-is → raw, staging, core, recommendations, ...
      - BigQuery development (dbt Cloud Studio, local runs):
            prefixed with the developer's dataset → dbt_dev_core, dbt_dev_staging, ...
        so experimenting in dev never overwrites the production tables.
    dbt Cloud sets DBT_CLOUD_ENVIRONMENT_TYPE to 'prod' in production runs.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set is_prod = env_var('DBT_CLOUD_ENVIRONMENT_TYPE', '') == 'prod' -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.type == 'bigquery' and not is_prod -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
