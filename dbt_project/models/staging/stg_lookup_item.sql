select * rename (item as item_name)
from {{ source('raw', 'lookup_item') }}