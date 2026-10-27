-- Every attribution model must hand out exactly 100 % of each conversion's credit.
select conversion_id, attribution_model, sum(credit) as total_credit
from {{ ref('fct_marketing_attribution') }}
group by 1, 2
having abs(sum(credit) - 1) > 0.0001
