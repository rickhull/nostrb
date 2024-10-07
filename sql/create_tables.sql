-- events table
CREATE TABLE events (content    TEXT NOT NULL,
                     kind       INT NOT NULL,
                     tags       TEXT NOT NULL,
                     pubkey     TEXT NOT NULL,
                     created_at INT NOT NULL,
                     id         TEXT PRIMARY KEY NOT NULL,
                     sig        TEXT NOT NULL) STRICT;
-- events indices
CREATE INDEX idx_events_created_at ON events (created_at);

-- tags table, references events
CREATE TABLE tags (event_id    TEXT NOT NULL REFERENCES events (id)
                               ON DELETE CASCADE ON UPDATE CASCADE,
                   created_at  INT NOT NULL,
                   tag         TEXT NOT NULL,
                   value       TEXT NOT NULL,
                   json        TEXT NOT NULL) STRICT;
-- tags indices
CREATE INDEX idx_tags_created_at ON tags (created_at);

-- r_events table, replaceable events
CREATE TABLE r_events (content    TEXT NOT NULL,
                       kind       INT NOT NULL,
                       tags       TEXT NOT NULL,
                       d_tag      TEXT NOT NULL,
                       pubkey     TEXT NOT NULL,
                       created_at INT NOT NULL,
                       id         TEXT PRIMARY KEY NOT NULL,
                       sig        TEXT NOT NULL) STRICT;
-- r_events indices
CREATE INDEX idx_r_events_created_at ON r_events (created_at);
CREATE UNIQUE INDEX unq_r_events_kind_pubkey_d_tag
                 ON r_events (kind, pubkey, d_tag);

-- r_tags table, references r_events
CREATE TABLE r_tags (r_event_id TEXT NOT NULL REFERENCES r_events (id)
                                ON DELETE CASCADE ON UPDATE CASCADE,
                     created_at INT NOT NULL,
                     tag        TEXT NOT NULL,
                     value      TEXT NOT NULL,
                     json       TEXT NOT NULL) STRICT;
-- r_tags indices
CREATE INDEX idx_r_tags_created_at ON r_tags (created_at);
