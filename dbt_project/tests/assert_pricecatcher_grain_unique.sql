{{ config(severity='warn') }}

select price_date, premise_code, item_code, count(*) as n
from {{ ref('stg_pricecatcher') }}
group by 1, 2, 3
having count(*) > 1