CREATE TABLE public.cp_account (
    id uuid PRIMARY KEY,
    username varchar(24) UNIQUE,
    password_hash varchar(100),
    recovery_hash varchar(64),
    google_sub varchar(255) UNIQUE,
    progress_id bigint NOT NULL UNIQUE REFERENCES public.prototype_prototypesession(id),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE public.cp_login_session (
    token_hash varchar(64) PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES public.cp_account(id),
    expires_at timestamptz NOT NULL
);
CREATE INDEX cp_login_session_expiry ON public.cp_login_session(expires_at);
