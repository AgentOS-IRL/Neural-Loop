begin;

alter table public.map_places
    add column pinned boolean not null default false;

alter table public.map_routes
    add column pinned boolean not null default false;

commit;
