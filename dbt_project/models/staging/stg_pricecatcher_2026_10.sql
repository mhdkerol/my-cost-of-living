-- One entry per loaded month; add new months to this list and to sources.yml
{% set months = ['pricecatcher_2026_10'] %}

{% for month in months %}
select * rename (date as price_date)
from {{ source('raw', month) }}
{% if not loop.last %}union all{% endif %}
{% endfor %}