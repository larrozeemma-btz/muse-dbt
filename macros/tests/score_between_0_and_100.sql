{#
    Generic test: every MUSE score (inputs and output) lives on a 0–100 scale.
    Usage in YAML:
        data_tests:
          - score_between_0_and_100
#}
{% test score_between_0_and_100(model, column_name) %}

select {{ column_name }} as invalid_score
from {{ model }}
where {{ column_name }} < 0
   or {{ column_name }} > 100

{% endtest %}
