-- Add calories column to cardio_log table if it doesn't exist
do $$
begin
  if not exists (select 1 from information_schema.columns where table_name = 'cardio_log' and column_name = 'calories') then
    alter table cardio_log add column calories numeric;
  end if;
end $$;
