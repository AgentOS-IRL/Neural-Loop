begin;

alter table public.map_places
    add column kind text not null default 'saved',
    add column client_event_id uuid,
    add column parked_at timestamptz,
    add column expires_at timestamptz,
    add column expired_at timestamptz,
    add column expiry_reason text;

alter table public.map_places
    add constraint map_places_kind_check
        check (kind in ('saved', 'parked')),
    add constraint map_places_parked_lifecycle_check
        check (
            kind = 'saved'
            or (
                client_event_id is not null
                and parked_at is not null
                and expires_at is not null
            )
        ),
    add constraint map_places_expiry_reason_check
        check (
            expiry_reason is null
            or expiry_reason in ('end_of_day', 'new_vehicle_trip')
        ),
    add constraint map_places_expiry_materialization_check
        check (
            (expired_at is null and expiry_reason is null)
            or (expired_at is not null and expiry_reason is not null)
        ),
    add constraint map_places_expiry_order_check
        check (
            parked_at is null
            or expires_at is null
            or expires_at >= parked_at
        );

create unique index map_places_client_event_id_idx
    on public.map_places (client_event_id)
    where client_event_id is not null;

create index map_places_kind_expiry_idx
    on public.map_places (kind, expires_at, expired_at, parked_at desc);

create or replace function public.nl_upsert_parked_place(
    p_client_event_id uuid,
    p_latitude double precision,
    p_longitude double precision,
    p_parked_at timestamptz,
    p_expires_at timestamptz,
    p_expired_at timestamptz default null,
    p_expiry_reason text default null,
    p_address text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_unfiled_id bigint;
    v_place public.map_places;
begin
    select folder.id
    into v_unfiled_id
    from public.map_folders as folder
    where folder.is_default = true
    order by folder.id
    limit 1;

    if v_unfiled_id is null then
        raise exception 'The Unfiled folder is missing';
    end if;

    insert into public.map_places (
        folder_id,
        name,
        latitude,
        longitude,
        address,
        kind,
        client_event_id,
        parked_at,
        expires_at,
        expired_at,
        expiry_reason
    )
    values (
        v_unfiled_id,
        'Parked Car',
        p_latitude,
        p_longitude,
        nullif(btrim(p_address), ''),
        'parked',
        p_client_event_id,
        p_parked_at,
        p_expires_at,
        p_expired_at,
        p_expiry_reason
    )
    on conflict (client_event_id) where client_event_id is not null
    do update set
        folder_id = excluded.folder_id,
        name = excluded.name,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        address = excluded.address,
        kind = excluded.kind,
        parked_at = excluded.parked_at,
        expires_at = excluded.expires_at,
        expired_at = excluded.expired_at,
        expiry_reason = excluded.expiry_reason
    returning * into v_place;

    return to_jsonb(v_place);
end;
$$;

create or replace function public.nl_expire_active_parked_places(
    p_expired_at timestamptz,
    p_expiry_reason text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_places jsonb;
begin
    if p_expiry_reason not in ('end_of_day', 'new_vehicle_trip') then
        raise exception 'Unsupported parking expiry reason: %', p_expiry_reason;
    end if;

    with updated as (
        update public.map_places
        set expires_at = least(expires_at, p_expired_at),
            expired_at = p_expired_at,
            expiry_reason = p_expiry_reason
        where kind = 'parked'
          and expired_at is null
          and expires_at > p_expired_at
        returning *
    )
    select coalesce(jsonb_agg(to_jsonb(updated) order by updated.id), '[]'::jsonb)
    into v_places
    from updated;

    return v_places;
end;
$$;

create or replace function public.nl_materialize_expired_parked_places(
    p_now timestamptz
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_places jsonb;
begin
    with updated as (
        update public.map_places
        set expired_at = expires_at,
            expiry_reason = 'end_of_day'
        where kind = 'parked'
          and expired_at is null
          and expires_at <= p_now
        returning *
    )
    select coalesce(jsonb_agg(to_jsonb(updated) order by updated.id), '[]'::jsonb)
    into v_places
    from updated;

    return v_places;
end;
$$;

create or replace function public.nl_convert_parked_place(
    p_client_event_id uuid,
    p_folder_id bigint,
    p_name text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_place public.map_places;
begin
    update public.map_places
    set folder_id = p_folder_id,
        name = btrim(p_name),
        kind = 'saved',
        parked_at = null,
        expires_at = null,
        expired_at = null,
        expiry_reason = null
    where client_event_id = p_client_event_id
      and kind = 'parked'
    returning * into v_place;

    if v_place.id is null then
        raise exception 'Parking place % does not exist', p_client_event_id;
    end if;

    return to_jsonb(v_place);
end;
$$;

create or replace function public.nl_delete_parked_place(
    p_client_event_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_place public.map_places;
begin
    delete from public.map_places
    where client_event_id = p_client_event_id
    returning * into v_place;

    if v_place.id is null then
        return null;
    end if;

    return to_jsonb(v_place);
end;
$$;

revoke all on function public.nl_upsert_parked_place(
    uuid,
    double precision,
    double precision,
    timestamptz,
    timestamptz,
    timestamptz,
    text,
    text
) from public, anon, authenticated;

revoke all on function public.nl_expire_active_parked_places(timestamptz, text)
from public, anon, authenticated;

revoke all on function public.nl_materialize_expired_parked_places(timestamptz)
from public, anon, authenticated;

revoke all on function public.nl_convert_parked_place(uuid, bigint, text)
from public, anon, authenticated;

revoke all on function public.nl_delete_parked_place(uuid)
from public, anon, authenticated;

grant execute on function public.nl_upsert_parked_place(
    uuid,
    double precision,
    double precision,
    timestamptz,
    timestamptz,
    timestamptz,
    text,
    text
) to anon;

grant execute on function public.nl_expire_active_parked_places(timestamptz, text) to anon;
grant execute on function public.nl_materialize_expired_parked_places(timestamptz) to anon;
grant execute on function public.nl_convert_parked_place(uuid, bigint, text) to anon;
grant execute on function public.nl_delete_parked_place(uuid) to anon;

commit;
