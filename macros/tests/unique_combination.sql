{#
    Generic model-level test: the given columns form a unique key.
    (A dependency-free equivalent of dbt_utils.unique_combination_of_columns.)
#}
{% test unique_combination(model, columns) %}

select {{ columns | join(', ') }}, count(*) as n_rows
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1

{% endtest %}
