begin;

alter table public.workout_session
  add column routine_id bigint references public.routine (id) on delete set null;

alter table public.routine_exercise
  add column target_reps_min integer,
  add column target_reps_max integer,
  add column warmup_sets integer not null default 0,
  add column load_increment_kg numeric not null default 2.5;

update public.routine_exercise
set target_reps_min = target_reps,
    target_reps_max = target_reps
where target_reps is not null;

alter table public.routine_exercise
  drop column target_reps,
  add constraint routine_exercise_target_sets_nonnegative check (target_sets is null or target_sets >= 0),
  add constraint routine_exercise_warmup_sets_nonnegative check (warmup_sets >= 0),
  add constraint routine_exercise_rep_range_valid check (
    (target_reps_min is null and target_reps_max is null)
    or (
      target_reps_min > 0
      and target_reps_max >= target_reps_min
    )
  ),
  add constraint routine_exercise_load_increment_positive check (load_increment_kg > 0);

alter table public.workout_set
  add column routine_exercise_id bigint references public.routine_exercise (id) on delete set null,
  add column set_type text not null default 'working',
  add constraint workout_set_set_type_valid check (set_type in ('warmup', 'working')),
  add constraint workout_set_number_positive check (set_number > 0),
  add constraint workout_set_reps_nonnegative check (reps >= 0),
  add constraint workout_set_weight_nonnegative check (weight is null or weight >= 0);

alter table public.cardio_log
  add column routine_exercise_id bigint references public.routine_exercise (id) on delete set null,
  add column set_number integer not null default 1,
  add constraint cardio_log_set_number_positive check (set_number > 0),
  add constraint cardio_log_distance_nonnegative check (distance_meters is null or distance_meters >= 0),
  add constraint cardio_log_duration_nonnegative check (duration_minutes is null or duration_minutes >= 0),
  add constraint cardio_log_calories_nonnegative check (calories is null or calories >= 0);

create index idx_workout_session_routine_history
  on public.workout_session (routine_id, date desc, start_time desc, id desc);
create index idx_workout_set_routine_exercise_history
  on public.workout_set (routine_exercise_id, set_type, set_number, workout_session_id);
create index idx_workout_set_exercise_history
  on public.workout_set (exercise_id, workout_session_id);
create index idx_cardio_log_routine_exercise_history
  on public.cardio_log (routine_exercise_id, set_number, workout_session_id);
create index idx_cardio_log_exercise_history
  on public.cardio_log (exercise_id, workout_session_id);

drop function if exists public.get_latest_exercise_history(bigint[]);

create or replace function public.nl_get_workout_launch_history(
  routine_id bigint,
  lookup_items jsonb
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with lookups as (
    select
      item.ordinality as ordinal,
      (item.value ->> 'routine_exercise_id')::bigint as routine_exercise_id,
      (item.value ->> 'exercise_id')::bigint as exercise_id,
      item.value ->> 'exercise_type' as exercise_type
    from jsonb_array_elements(coalesce($2, '[]'::jsonb)) with ordinality as item(value, ordinality)
  ),
  sources as (
    select
      lookup.*,
      coalesce(same_routine.session_id, global_use.session_id) as session_id,
      global_use.history_routine_exercise_id,
      case
        when same_routine.session_id is not null then 'same_routine'
        when global_use.session_id is not null then 'global'
        else null
      end as source_scope
    from lookups as lookup
    left join lateral (
      select session.id as session_id
      from public.workout_session as session
      where session.routine_id = $1
        and (
          exists (
            select 1
            from public.workout_set as workout_set
            where workout_set.workout_session_id = session.id
              and workout_set.routine_exercise_id = lookup.routine_exercise_id
          )
          or exists (
            select 1
            from public.cardio_log as cardio_log
            where cardio_log.workout_session_id = session.id
              and cardio_log.routine_exercise_id = lookup.routine_exercise_id
          )
        )
      order by session.date desc, session.start_time desc nulls last, session.id desc
      limit 1
    ) as same_routine on true
    left join lateral (
      select
        session.id as session_id,
        coalesce(
          (
            select workout_set.routine_exercise_id
            from public.workout_set as workout_set
            where workout_set.workout_session_id = session.id
              and workout_set.exercise_id = lookup.exercise_id
            order by workout_set.routine_exercise_id nulls last, workout_set.id
            limit 1
          ),
          (
            select cardio_log.routine_exercise_id
            from public.cardio_log as cardio_log
            where cardio_log.workout_session_id = session.id
              and cardio_log.exercise_id = lookup.exercise_id
            order by cardio_log.routine_exercise_id nulls last, cardio_log.id
            limit 1
          )
        ) as history_routine_exercise_id
      from public.workout_session as session
      where same_routine.session_id is null
        and (
          exists (
            select 1
            from public.workout_set as workout_set
            where workout_set.workout_session_id = session.id
              and workout_set.exercise_id = lookup.exercise_id
          )
          or exists (
            select 1
            from public.cardio_log as cardio_log
            where cardio_log.workout_session_id = session.id
              and cardio_log.exercise_id = lookup.exercise_id
          )
        )
      order by session.date desc, session.start_time desc nulls last, session.id desc
      limit 1
    ) as global_use on true
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'routine_exercise_id', source.routine_exercise_id,
        'exercise_id', source.exercise_id,
        'source_scope', source.source_scope,
        'source_date', session.date,
        'source_session_id', source.session_id,
        'strength_sets', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'routine_exercise_id', workout_set.routine_exercise_id,
              'set_type', workout_set.set_type,
              'set_number', workout_set.set_number,
              'reps', workout_set.reps,
              'weight', workout_set.weight
            )
            order by case workout_set.set_type when 'warmup' then 0 else 1 end,
                     workout_set.set_number,
                     workout_set.id
          )
          from public.workout_set as workout_set
          where workout_set.workout_session_id = source.session_id
            and (
              (source.source_scope = 'same_routine' and workout_set.routine_exercise_id = source.routine_exercise_id)
              or (
                source.source_scope = 'global'
                and workout_set.exercise_id = source.exercise_id
                and (
                  source.history_routine_exercise_id is null
                  or workout_set.routine_exercise_id = source.history_routine_exercise_id
                )
              )
            )
        ), '[]'::jsonb),
        'cardio_logs', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'routine_exercise_id', cardio_log.routine_exercise_id,
              'set_number', cardio_log.set_number,
              'duration_minutes', cardio_log.duration_minutes,
              'distance_meters', cardio_log.distance_meters,
              'calories', cardio_log.calories
            )
            order by cardio_log.set_number, cardio_log.id
          )
          from public.cardio_log as cardio_log
          where cardio_log.workout_session_id = source.session_id
            and (
              (source.source_scope = 'same_routine' and cardio_log.routine_exercise_id = source.routine_exercise_id)
              or (
                source.source_scope = 'global'
                and cardio_log.exercise_id = source.exercise_id
                and (
                  source.history_routine_exercise_id is null
                  or cardio_log.routine_exercise_id = source.history_routine_exercise_id
                )
              )
            )
        ), '[]'::jsonb)
      )
      order by source.ordinal
    ),
    '[]'::jsonb
  )
  from sources as source
  left join public.workout_session as session on session.id = source.session_id;
$$;

create or replace function public.nl_finalize_workout(payload jsonb)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  created_session_id bigint;
  strength_set jsonb;
  cardio_entry jsonb;
begin
  insert into public.workout_session (
    routine_id,
    date,
    start_time,
    end_time,
    session_type,
    notes
  ) values (
    nullif(payload ->> 'routine_id', '')::bigint,
    coalesce(nullif(payload #>> '{session,date}', '')::date, current_date),
    nullif(payload #>> '{session,start_time}', '')::time,
    nullif(payload #>> '{session,end_time}', '')::time,
    payload #>> '{session,session_type}',
    nullif(payload #>> '{session,notes}', '')
  )
  returning id into created_session_id;

  for strength_set in
    select value from jsonb_array_elements(coalesce(payload -> 'sets', '[]'::jsonb))
  loop
    insert into public.workout_set (
      workout_session_id,
      exercise_id,
      routine_exercise_id,
      set_type,
      set_number,
      reps,
      weight,
      superset_group_id
    ) values (
      created_session_id,
      (strength_set ->> 'exercise_id')::bigint,
      nullif(strength_set ->> 'routine_exercise_id', '')::bigint,
      coalesce(strength_set ->> 'set_type', 'working'),
      (strength_set ->> 'set_number')::integer,
      (strength_set ->> 'reps')::integer,
      nullif(strength_set ->> 'weight', '')::numeric,
      nullif(strength_set ->> 'superset_group_id', '')::integer
    );
  end loop;

  for cardio_entry in
    select value from jsonb_array_elements(coalesce(payload -> 'cardio_logs', '[]'::jsonb))
  loop
    insert into public.cardio_log (
      workout_session_id,
      exercise_id,
      routine_exercise_id,
      set_number,
      distance_meters,
      duration_minutes,
      calories
    ) values (
      created_session_id,
      (cardio_entry ->> 'exercise_id')::bigint,
      nullif(cardio_entry ->> 'routine_exercise_id', '')::bigint,
      (cardio_entry ->> 'set_number')::integer,
      nullif(cardio_entry ->> 'distance_meters', '')::numeric,
      nullif(cardio_entry ->> 'duration_minutes', '')::numeric,
      nullif(cardio_entry ->> 'calories', '')::numeric
    );
  end loop;

  return jsonb_build_object('session_id', created_session_id);
end;
$$;

revoke all on function public.nl_get_workout_launch_history(bigint, jsonb) from public;
revoke all on function public.nl_finalize_workout(jsonb) from public;
grant execute on function public.nl_get_workout_launch_history(bigint, jsonb) to anon, authenticated;
grant execute on function public.nl_finalize_workout(jsonb) to anon, authenticated;

commit;
