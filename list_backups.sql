SELECT DISTINCT
        '  '||CAST(DBPARTITIONNUM AS CHAR(02)) as "Node",
        CASE
                when sqlcode is not null  then 'Failed'
                else 'Succeeded'
        END as " Status",
        CAST(timestampdiff(4,char(timestamp(end_time)-timestamp(start_time))) AS SMALLINT) as "Ela min",
        substr(firstlog,1,13)   as " Start Log",
        substr(lastlog,1,13)    as "  End Log",
        CASE(operationType)
                when 'F' then 'Offline Full'
                when 'N' then 'Online Full'
                when 'I' then 'Offline Incr'
                when 'O' then 'Online Incr'
                when 'D' then 'Offline Delta'
                when 'E' then 'Online Delta'
                else '?'
        END as "  Type",
        CASE(objecttype)
                when 'D' then 'Database'
                when 'P' then 'Tablespace'
                else Objecttype
        END as "Obj type",
        date(timestamp(end_time)) as " End Date",
        time(timestamp(end_time)) as "End Time",
        start_time as "Bkup Timestamp"
  FROM  table(admin_list_hist()) as list_history
  WHERE operation = 'B'
  ORDER BY start_time desc, "Node"
  FETCH first 32 rows only
        ;


