-- every monthly raw table that has been loaded
{% if execute %}
  {% set result = run_query(
      "select table_name from information_schema.tables "
      "where table_schema = 'raw' "
      "and regexp_matches(table_name, '^pricecatcher_[0-9]{4}_[0-9]{2}$') "
      "order by table_name"
  ) %}
  {% set months = result.columns[0].values() %}
{% else %}
  {% set months = [] %}
{% endif %}

{% for month in months %}
select * rename (date as price_date)
from {{ source('raw', month) }}
{% if not loop.last %}union all{% endif %}
{% endfor %}