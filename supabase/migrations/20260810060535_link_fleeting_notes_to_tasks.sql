alter table public."fleeting notes"
    add column if not exists task_id bigint;

create index if not exists fleeting_notes_task_id_idx
    on public."fleeting notes" (task_id);

alter table public."fleeting notes"
    drop constraint if exists fleeting_notes_task_id_fkey;

alter table public."fleeting notes"
    add constraint fleeting_notes_task_id_fkey
    foreign key (task_id)
    references public.tasks (id)
    on delete set null;

create or replace function public.nl_get_task_note_counts()
returns table (
    task_id bigint,
    note_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        notes.task_id,
        count(*)::bigint as note_count
    from public."fleeting notes" as notes
    where notes.task_id is not null
    group by notes.task_id;
$$;

revoke execute on function public.nl_get_task_note_counts() from public;
grant execute on function public.nl_get_task_note_counts() to anon, authenticated;
