select * rename (date as effective_date)
from {{ source('raw', 'fuelprice') }}