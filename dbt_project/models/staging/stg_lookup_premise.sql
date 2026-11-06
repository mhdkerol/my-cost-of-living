select * rename (premise as premise_name)
from {{ source('raw', 'lookup_premise') }}