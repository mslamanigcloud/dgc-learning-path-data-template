SELECT id_customer,
       first_name,
       Upper(last_name)                      AS last_name,
       email,
       Parse_date("%d-%b-%y", creation_date) AS creation_date,
       update_time,
       CURRENT_TIMESTAMP()                   AS insertion_time
FROM   `{{ project_id }}.raw.customer`;