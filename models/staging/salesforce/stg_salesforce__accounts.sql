select
    Id                              as account_id,
    Name                            as account_name,
    Industry                        as industry,
    NumberOfEmployees               as employees,
    BillingCountry                  as country_code,
    cast(CreatedDate as timestamp)  as created_at
from {{ source('salesforce', 'crm_accounts') }}
