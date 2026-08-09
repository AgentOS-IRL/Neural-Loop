alter table public."fleeting notes"
    add column if not exists watch_action_id uuid;

create unique index if not exists fleeting_notes_watch_action_id_unique
    on public."fleeting notes" (watch_action_id);
