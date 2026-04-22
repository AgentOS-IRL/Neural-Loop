erDiagram
    equipment {
        bigint id PK
        text name
    }
    muscle {
        bigint id PK
        text name
    }
    routine {
        bigint id PK
        text name
        text notes
    }
    exercise {
        bigint id PK
        text name
        text type
        bigint equipment_id FK
    }
    exercise_muscles {
        bigint id PK
        bigint exercise_id FK
        bigint muscle_id FK
        boolean is_primary
    }
    routine_exercise {
        bigint id PK
        bigint routine_id FK
        bigint exercise_id FK
        integer order_index
        integer target_sets
        integer target_reps
        integer rest_seconds
        integer superset_group_id
    }
    workout_session {
        bigint id PK
        date date
        time start_time
        time end_time
        text session_type
        text notes
    }
    workout_set {
        bigint id PK
        bigint workout_session_id FK
        bigint exercise_id FK
        integer set_number
        integer reps
        numeric weight
        integer superset_group_id
    }
    cardio_log {
        bigint id PK
        bigint workout_session_id FK
        bigint exercise_id FK
        numeric distance_meters
        numeric duration_minutes
    }

    %% Relationships
    equipment ||--o{ exercise : "used in"
    
    exercise ||--o{ exercise_muscles : "has"
    muscle ||--o{ exercise_muscles : "targeted by"
    
    routine ||--o{ routine_exercise : "contains"
    exercise ||--o{ routine_exercise : "is part of"
    
    workout_session ||--o{ workout_set : "records"
    exercise ||--o{ workout_set : "performed in"
    
    workout_session ||--o{ cardio_log : "records"
    exercise ||--o{ cardio_log : "performed in"