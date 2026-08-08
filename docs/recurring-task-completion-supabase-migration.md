# Recurring task completion: future Supabase migration

## Current decision

Neural Loop is currently a single-device app, so recurring-task completions remain in SwiftData. The local model uses the scheduled occurrence start as its identity and the tap time as completion metadata:

```text
(taskId, occurrenceStart) -> completedAt
```

Local writes are idempotent in application code: completing an already-completed occurrence is a no-op, and uncompleting deletes only that occurrence. Legacy records that contain only `completedAt` are recognized by calendar day and upgraded lazily when touched.

The implementation lives in:

- `Neural Loop/local_data/CompletedRecursiveTask.swift`
- `Neural Loop/unified_data/TasksUDM.swift`
- `Neural Loop/todo_screen/TodoView.swift`
- `Neural Loop/unified_data/CalendarUDM.swift`

## When to reconsider Supabase

Move recurring completions to Supabase when at least one of these becomes a product requirement:

- Multiple iPhones, iPads, or independently operating Watch clients
- Cloud restoration after uninstall or device loss
- Server-side completion reporting
- A web client
- Shared accounts or collaboration
- Server-driven notification decisions based on completion state

## Proposed database contract

Do not apply this SQL without first reconciling the repository migration history with the live database and deciding the user-ownership/RLS model.

```sql
create table public.task_completions (
    task_id bigint not null
        references public.tasks(id) on delete cascade,
    occurrence_start timestamptz not null,
    completed_at timestamptz not null default now(),

    primary key (task_id, occurrence_start)
);
```

The composite primary key is the database-level idempotency guarantee. `occurrence_start` identifies the scheduled instance; `completed_at` records when the user actually completed it.

The write API should be one atomic PostgreSQL function:

```sql
create or replace function public.nl_set_recurring_task_completed(
    p_task_id bigint,
    p_occurrence_start timestamptz,
    p_completed boolean default true
)
returns table (
    task_id bigint,
    occurrence_start timestamptz,
    is_completed boolean,
    completed_at timestamptz
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_completed_at timestamptz;
begin
    if p_completed then
        insert into public.task_completions as existing (
            task_id,
            occurrence_start
        )
        values (
            p_task_id,
            p_occurrence_start
        )
        on conflict (task_id, occurrence_start)
        do update set completed_at = existing.completed_at
        returning existing.completed_at into v_completed_at;
    else
        delete from public.task_completions as existing
        where existing.task_id = p_task_id
          and existing.occurrence_start = p_occurrence_start;

        v_completed_at := null;
    end if;

    return query
    select
        p_task_id,
        p_occurrence_start,
        p_completed,
        v_completed_at;
end;
$$;
```

Before deploying the function, validate that the referenced task exists and is recurring, define appropriate execute privileges, and implement ownership-aware RLS policies. Prefer `SECURITY INVOKER`; do not use `SECURITY DEFINER` merely to bypass permission errors.

## Expected Swift interface

Supabase Swift supports sending Encodable RPC parameters and decoding the returned value from `execute().value`. The future database layer can follow the existing RPC style in `Neural Loop/database/Tasks.swift`:

```swift
struct SetRecurringTaskCompletedParams: Encodable, Sendable {
    let p_task_id: Int64
    let p_occurrence_start: Date
    let p_completed: Bool
}

let savedState: RecurringTaskCompletionState = try await customsupabase
    .rpc(
        "nl_set_recurring_task_completed",
        params: SetRecurringTaskCompletedParams(
            p_task_id: taskId,
            p_occurrence_start: occurrenceStart,
            p_completed: completed
        )
    )
    .single()
    .execute()
    .value
```

## Migration sequence

1. Reconcile live and repository migration history.
2. Decide task ownership and RLS policies.
3. Create `task_completions` and the atomic RPC in a reviewed migration.
4. Backfill each local SwiftData record, preserving both `occurrenceStart` and `completedAt`.
5. Read Supabase and local records during a short compatibility period.
6. Switch Todo, Calendar, history, and notification decisions to Supabase.
7. Remove the SwiftData completion model only after successful backfill verification.

## Verification checklist

- Completing the same occurrence twice leaves one row and preserves its original `completed_at`.
- Uncompleting twice succeeds and leaves no row.
- Different occurrences of the same task remain independent.
- Todo and Calendar display the same state.
- Time-zone and daylight-saving boundaries preserve the intended scheduled occurrence.
- Deleting a task cascades to its completion rows.
- A second client observes the same completion state.

