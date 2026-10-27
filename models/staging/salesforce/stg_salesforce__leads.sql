{# The CRM sync sometimes delivers the same Lead twice: keep one row per Id. #}

with source as (

    select * from {{ source('salesforce', 'crm_leads') }}

)

select
    Id                                  as lead_id,
    Company                             as account_id,
    {{ dbt.split_part('Email', "'@'", 2) }} as email_domain,
    case upper(trim(LeadSource))
        {%- for s in ['Website Demo Request', 'Webinar', 'Trade Show', 'Content Download', 'Paid Search', 'LinkedIn Ads', 'Partner Referral', 'Outbound'] %}
        when '{{ s | upper }}' then '{{ s }}'
        {%- endfor %}
        else 'Other'
    end                                 as lead_source,
    Status                              as lead_status,
    cast(CreatedDate as timestamp)      as created_at,
    cast(MQL_Date__c as timestamp)      as mql_at,
    cast(SQL_Date__c as timestamp)      as sql_at,
    IsConverted                         as is_converted,
    ConvertedOpportunityId              as converted_opportunity_id
from source
where Id is not null
qualify row_number() over (partition by Id order by CreatedDate) = 1
