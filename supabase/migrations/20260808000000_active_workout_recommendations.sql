begin;

create or replace function public.nl_get_active_workout_recommendations(
  routine_id bigint
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with source_session as (
    select session.id, session.date
    from public.workout_session as session
    where session.routine_id = $1
      and session.end_time is not null
      and exists (
        select 1
        from (
          select workout_set.exercise_id
          from public.workout_set as workout_set
          where workout_set.workout_session_id = session.id
            and workout_set.routine_exercise_id is null

          union

          select cardio_log.exercise_id
          from public.cardio_log as cardio_log
          where cardio_log.workout_session_id = session.id
            and cardio_log.routine_exercise_id is null
        ) as previous_extra
        where not exists (
          select 1
          from public.routine_exercise as routine_exercise
          where routine_exercise.routine_id = $1
            and routine_exercise.exercise_id = previous_extra.exercise_id
        )
      )
    order by session.date desc, session.start_time desc nulls last, session.id desc
    limit 1
  ),
  previous_extra as (
    select
      workout_set.exercise_id,
      min(workout_set.id) as source_order
    from public.workout_set as workout_set
    join source_session on source_session.id = workout_set.workout_session_id
    where workout_set.routine_exercise_id is null
    group by workout_set.exercise_id

    union all

    select
      cardio_log.exercise_id,
      min(cardio_log.id) as source_order
    from public.cardio_log as cardio_log
    join source_session on source_session.id = cardio_log.workout_session_id
    where cardio_log.routine_exercise_id is null
    group by cardio_log.exercise_id
  ),
  eligible_extra as (
    select previous_extra.exercise_id, min(previous_extra.source_order) as source_order
    from previous_extra
    where not exists (
      select 1
      from public.routine_exercise as routine_exercise
      where routine_exercise.routine_id = $1
        and routine_exercise.exercise_id = previous_extra.exercise_id
    )
    group by previous_extra.exercise_id
  )
  select jsonb_build_object(
    'source_session_id', (select source_session.id from source_session),
    'source_date', (select source_session.date from source_session),
    'recommendations', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'exercise_id', exercise.id,
          'exercise_name', exercise.name,
          'exercise_type', exercise.type,
          'equipment_id', exercise.equipment_id,
          'equipment_name', coalesce(equipment.name, 'No equipment'),
          'muscles', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'muscle_id', muscle.id,
                'muscle_name', muscle.name,
                'is_primary', exercise_muscles.is_primary
              )
              order by exercise_muscles.is_primary desc, muscle.name, muscle.id
            )
            from public.exercise_muscles as exercise_muscles
            join public.muscle as muscle on muscle.id = exercise_muscles.muscle_id
            where exercise_muscles.exercise_id = exercise.id
          ), '[]'::jsonb),
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
            join source_session on source_session.id = workout_set.workout_session_id
            where workout_set.exercise_id = exercise.id
              and workout_set.routine_exercise_id is null
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
            join source_session on source_session.id = cardio_log.workout_session_id
            where cardio_log.exercise_id = exercise.id
              and cardio_log.routine_exercise_id is null
          ), '[]'::jsonb)
        )
        order by eligible_extra.source_order, exercise.name, exercise.id
      )
      from eligible_extra
      join public.exercise as exercise on exercise.id = eligible_extra.exercise_id
      left join public.equipment as equipment on equipment.id = exercise.equipment_id
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.nl_get_active_workout_recommendations(bigint) from public;
grant execute on function public.nl_get_active_workout_recommendations(bigint) to anon, authenticated;

commit;
