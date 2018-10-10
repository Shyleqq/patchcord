/*
 Litecord schema file
 */

-- Thank you FrostLuma for giving snowflake_time and time_snowflake
-- convert Discord snowflake to timestamp
CREATE OR REPLACE FUNCTION snowflake_time (snowflake BIGINT)
    RETURNS TIMESTAMP AS $$
BEGIN
    RETURN to_timestamp(((snowflake >> 22) + 1420070400000) / 1000);
END; $$
LANGUAGE PLPGSQL;


-- convert timestamp to Discord snowflake
CREATE OR REPLACE FUNCTION time_snowflake (date TIMESTAMP WITH TIME ZONE)
    RETURNS BIGINT AS $$
BEGIN
    RETURN CAST(EXTRACT(epoch FROM date) * 1000 - 1420070400000 AS BIGINT) << 22;
END; $$
LANGUAGE PLPGSQL;


-- User connection applications
CREATE TABLE IF NOT EXISTS user_conn_apps (
    id serial PRIMARY KEY,
    name text NOT NULL
);

INSERT INTO user_conn_apps (id, name) VALUES (0, 'Twitch');
INSERT INTO user_conn_apps (id, name) VALUES (1, 'Youtube');
INSERT INTO user_conn_apps (id, name) VALUES (2, 'Steam');
INSERT INTO user_conn_apps (id, name) VALUES (3, 'Reddit');
INSERT INTO user_conn_apps (id, name) VALUES (4, 'Facebook');
INSERT INTO user_conn_apps (id, name) VALUES (5, 'Twitter');
INSERT INTO user_conn_apps (id, name) VALUES (6, 'Spotify');
INSERT INTO user_conn_apps (id, name) VALUES (7, 'XBOX');
INSERT INTO user_conn_apps (id, name) VALUES (8, 'Battle.net');
INSERT INTO user_conn_apps (id, name) VALUES (9, 'Skype');
INSERT INTO user_conn_apps (id, name) VALUES (10, 'League of Legends');


CREATE TABLE IF NOT EXISTS files (
    -- snowflake id of the file
    id bigint PRIMARY KEY NOT NULL,

    -- sha512(file)
    hash text NOT NULL,
    mimetype text NOT NULL,

    -- path to the file system
    fspath text NOT NULL
);


CREATE TABLE IF NOT EXISTS users (
    id bigint UNIQUE NOT NULL,
    username text NOT NULL,
    discriminator varchar(4) NOT NULL,
    email varchar(255) NOT NULL UNIQUE,

    -- user properties
    bot boolean DEFAULT FALSE,
    mfa_enabled boolean DEFAULT FALSE,
    verified boolean DEFAULT FALSE,
    avatar bigint REFERENCES files (id) DEFAULT NULL,

    -- user badges, discord dev, etc
    flags int DEFAULT 0,

    -- nitro status encoded in here
    premium_since timestamp without time zone default NULL,

    -- private info
    phone varchar(60) DEFAULT '',
    password_hash text NOT NULL,

    PRIMARY KEY (id, username, discriminator)
);


-- main user settings
CREATE TABLE IF NOT EXISTS user_settings (
    id bigint REFERENCES users (id),
    afk_timeout int DEFAULT 300,

    -- connection detection (none by default)
    detect_platform_accounts bool DEFAULT false,

    -- privacy and safety
    -- options like data usage are over
    -- the get_consent function on users blueprint
    default_guilds_restricted bool DEFAULT false,
    explicit_content_filter int DEFAULT 2,
    friend_source jsonb DEFAULT '{"all": true}',

    -- guild positions on the client.
    guild_positions jsonb DEFAULT '[]',

    -- guilds that can't dm you
    restricted_guilds jsonb DEFAULT '[]',

    render_reactions bool DEFAULT true,

    -- show the current palying game
    -- as an activity
    show_current_game bool DEFAULT true,

    -- text and images

    -- show MEDIA embeds for urls
    inline_embed_media bool DEFAULT true,

    -- show thumbnails for attachments
    inline_attachment_media bool DEFAULT true,

    -- autoplay gifs on the client
    gif_auto_play bool DEFAULT true,

    -- render OpenGraph embeds for urls posted in chat
    render_embeds bool DEFAULT true,

    -- play animated emojis
    animate_emoji bool DEFAULT true,

    -- convert :-) to the smile emoji and others
    convert_emoticons bool DEFAULT false,

    -- enable /tts
    enable_tts_command bool DEFAULT false,

    -- appearance
    message_display_compact bool DEFAULT false,
    status text DEFAULT 'online' NOT NULL,
    theme text DEFAULT 'dark' NOT NULL,
    developer_mode bool DEFAULT true,
    disable_games_tab bool DEFAULT true,
    locale text DEFAULT 'en-US',

    -- set by the client
    -- the server uses this to make emails
    -- about "look at what youve missed"
    timezone_offset int DEFAULT 0
);


-- main user relationships
CREATE TABLE IF NOT EXISTS relationships (
    -- the id of who made the relationship
    user_id bigint REFERENCES users (id),

    -- the id of the peer who got a friendship
    -- request or a block.
    peer_id bigint REFERENCES users (id),

    rel_type SMALLINT,

    PRIMARY KEY (user_id, peer_id)
);


CREATE TABLE IF NOT EXISTS notes (
    user_id bigint REFERENCES users (id),
    target_id bigint REFERENCES users (id),
    note text DEFAULT '',
    PRIMARY KEY (user_id, target_id)
);


CREATE TABLE IF NOT EXISTS connections (
    user_id bigint REFERENCES users (id),
    conn_type bigint REFERENCES user_conn_apps (id),
    name text NOT NULL,
    revoked bool DEFAULT false,
    PRIMARY KEY (user_id, conn_type)
);


CREATE TABLE IF NOT EXISTS channels (
    id bigint PRIMARY KEY,
    channel_type int NOT NULL
);

CREATE TABLE IF NOT EXISTS user_read_state (
    user_id bigint REFERENCES users (id),
    channel_id bigint REFERENCES channels (id),

    -- we don't really need to link
    -- this column to the messages table
    last_message_id bigint,

    -- counts are always positive
    mention_count bigint CHECK (mention_count > -1),

    PRIMARY KEY (user_id, channel_id)
);

CREATE TABLE IF NOT EXISTS guilds (
    id bigint PRIMARY KEY NOT NULL,

    name text NOT NULL,
    icon text DEFAULT NULL,
    splash text DEFAULT NULL,
    owner_id bigint NOT NULL REFERENCES users (id),

    region text NOT NULL,

    /* default no afk channel 
        afk channel is voice-only.
     */
    afk_channel_id bigint REFERENCES channels (id) DEFAULT NULL,

    /* default 5 minutes */
    afk_timeout int DEFAULT 300,
    
    -- from 0 to 4
    verification_level int DEFAULT 0,

    -- from 0 to 1
    default_message_notifications int DEFAULT 0,

    -- from 0 to 2
    explicit_content_filter int DEFAULT 0,

    -- ????
    mfa_level int DEFAULT 0,

    embed_enabled boolean DEFAULT false,
    embed_channel_id bigint REFERENCES channels (id) DEFAULT NULL,

    widget_enabled boolean DEFAULT false,
    widget_channel_id bigint REFERENCES channels (id) DEFAULT NULL,

    system_channel_id bigint REFERENCES channels (id) DEFAULT NULL
);


CREATE TABLE IF NOT EXISTS guild_channels (
    id bigint REFERENCES channels (id) PRIMARY KEY,
    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,

    -- an id to guild_channels
    parent_id bigint DEFAULT NULL,

    name text NOT NULL,
    position int,
    nsfw bool default false
);


CREATE TABLE IF NOT EXISTS guild_text_channels (
    id bigint REFERENCES guild_channels (id) ON DELETE CASCADE,
    topic text DEFAULT '',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS guild_voice_channels (
    id bigint REFERENCES guild_channels (id) ON DELETE CASCADE,

    -- default bitrate for discord is 64kbps
    bitrate int DEFAULT 64,

    -- 0 means infinite
    user_limit int DEFAULT 0,
    PRIMARY KEY (id)
);


CREATE TABLE IF NOT EXISTS dm_channels (
    id bigint REFERENCES channels (id) ON DELETE CASCADE UNIQUE,

    party1_id bigint REFERENCES users (id) ON DELETE CASCADE,
    party2_id bigint REFERENCES users (id) ON DELETE CASCADE,

    PRIMARY KEY (id, party1_id, party2_id)
);


CREATE TABLE IF NOT EXISTS dm_channel_state (
    user_id bigint REFERENCES users (id) ON DELETE CASCADE,
    dm_id bigint REFERENCES dm_channels (id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, dm_id)
);


CREATE TABLE IF NOT EXISTS group_dm_channels (
    id bigint REFERENCES channels (id) ON DELETE CASCADE,
    owner_id bigint REFERENCES users (id),
    name text,
    icon bigint REFERENCES files (id),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS group_dm_members (
    id bigint REFERENCES group_dm_channels (id) ON DELETE CASCADE,
    member_id bigint REFERENCES users (id),
    PRIMARY KEY (id, member_id)
);


CREATE TABLE IF NOT EXISTS channel_overwrites (
    channel_id bigint REFERENCES channels (id) ON DELETE CASCADE,

    -- target_type = 0 -> use target_user
    -- target_type = 1 -> user target_role
    -- discord already has overwrite.type = 'role' | 'member'
    -- so this allows us to be more compliant with the API
    target_type integer default null,

    -- keeping both columns separated and as foreign keys
    -- instead of a single "target_id bigint" column
    -- makes us able to remove the channel overwrites of
    -- a role when its deleted (same for users, etc).
    target_role bigint REFERENCES roles (id) ON DELETE CASCADE,
    target_user bigint REFERENCES users (id) ON DELETE CASCADE,

    -- since those are permission bit sets
    -- they're bigints (64bits), discord,
    -- for now, only needs 53.
    allow bigint DEFAULT 0,
    deny bigint DEFAULT 0,

    PRIMARY KEY (channel_id, target_role, target_user)
);


CREATE TABLE IF NOT EXISTS features (
    id serial PRIMARY KEY,
    feature text NOT NULL
);

CREATE TABLE IF NOT EXISTS guild_features (
    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,
    feature integer REFERENCES features (id),
    PRIMARY KEY (guild_id, feature)
);


CREATE TABLE IF NOT EXISTS guild_integrations (
    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,
    user_id bigint REFERENCES users (id) ON DELETE CASCADE,
    integration bigint REFERENCES user_conn_apps (id),
    PRIMARY KEY (guild_id, user_id)
);


CREATE TABLE IF NOT EXISTS guild_emoji (
    id bigint PRIMARY KEY,
    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,
    uploader_id bigint REFERENCES users (id),

    name text NOT NULL,
    image bigint REFERENCES files (id),
    animated bool DEFAULT false,
    managed bool DEFAULT false,
    require_colons bool DEFAULT false
);

/* Someday I might actually write this.
CREATE TABLE IF NOT EXISTS guild_audit_log (
    guild_id bigint REFERENCES guilds (id),

);
*/

CREATE TABLE IF NOT EXISTS invites (
    code text PRIMARY KEY,
    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,
    channel_id bigint REFERENCES channels (id) ON DELETE CASCADE,
    inviter bigint REFERENCES users (id),

    created_at timestamp without time zone default (now() at time zone 'utc'),
    uses bigint DEFAULT 0,

    -- -1 means infinite here
    max_uses bigint DEFAULT -1,
    max_age bigint DEFAULT -1,

    temporary bool DEFAULT false,
    revoked bool DEFAULT false
);


CREATE TABLE IF NOT EXISTS webhooks (
    id bigint PRIMARY KEY,

    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,
    channel_id bigint REFERENCES channels (id) ON DELETE CASCADE,
    creator_id bigint REFERENCES users (id),

    name text NOT NULL,
    avatar text NOT NULL,

    -- Yes, we store the webhook's token
    -- since they aren't users and there's no /api/login for them.
    token text NOT NULL
);


CREATE TABLE IF NOT EXISTS members (
    user_id bigint REFERENCES users (id) ON DELETE CASCADE,
    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,
    nickname text DEFAULT NULL,
    joined_at timestamp without time zone default (now() at time zone 'utc'),
    deafened boolean DEFAULT false,
    muted boolean DEFAULT false,
    PRIMARY KEY (user_id, guild_id)
);


CREATE TABLE IF NOT EXISTS roles (
    id bigint UNIQUE NOT NULL,
    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,

    name text NOT NULL,
    color int DEFAULT 1,
    hoist bool DEFAULT false,
    position int NOT NULL,
    permissions int NOT NULL,
    managed bool DEFAULT false,
    mentionable bool DEFAULT false,

    PRIMARY KEY (id, guild_id)
);


CREATE TABLE IF NOT EXISTS guild_whitelists (
    emoji_id bigint REFERENCES guild_emoji (id) ON DELETE CASCADE,
    role_id bigint REFERENCES roles (id),
    PRIMARY KEY (emoji_id, role_id)
);

/* Represents a role a member has. */
CREATE TABLE IF NOT EXISTS member_roles (
    user_id bigint REFERENCES users (id) ON DELETE CASCADE,
    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,
    role_id bigint REFERENCES roles (id) ON DELETE CASCADE,

    PRIMARY KEY (user_id, guild_id, role_id)
);


CREATE TABLE IF NOT EXISTS bans (
    guild_id bigint REFERENCES guilds (id) ON DELETE CASCADE,

    -- users can be removed but their IDs would still show
    -- on a guild's ban list.
    user_id bigint NOT NULL REFERENCES users (id),

    reason text NOT NULL,

    PRIMARY KEY (user_id, guild_id)
);


CREATE TABLE IF NOT EXISTS embeds (
    -- TODO: this table
    id bigint PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS messages (
    id bigint PRIMARY KEY,
    channel_id bigint REFERENCES channels (id) ON DELETE CASCADE,

    -- those are mutually exclusive, only one of them
    -- can NOT be NULL at a time.

    -- if author is NULL -> message from webhook
    -- if webhook is NULL -> message from author
    author_id bigint REFERENCES users (id),
    webhook_id bigint REFERENCES webhooks (id),

    content text,

    created_at timestamp without time zone default (now() at time zone 'utc'),
    edited_at timestamp without time zone default NULL,

    tts bool default false,
    mention_everyone bool default false,

    nonce bigint default 0,

    message_type int NOT NULL
);

CREATE TABLE IF NOT EXISTS message_attachments (
    message_id bigint REFERENCES messages (id),
    attachment bigint REFERENCES files (id),
    PRIMARY KEY (message_id, attachment)
);

CREATE TABLE IF NOT EXISTS message_embeds (
    message_id bigint REFERENCES messages (id) UNIQUE,
    embed_id bigint REFERENCES embeds (id),
    PRIMARY KEY (message_id, embed_id)
);

CREATE TABLE IF NOT EXISTS message_reactions (
    message_id bigint REFERENCES messages (id),
    user_id bigint REFERENCES users (id),

    -- since it can be a custom emote, or unicode emoji
    emoji_id bigint REFERENCES guild_emoji (id),
    emoji_text text NOT NULL,
    PRIMARY KEY (message_id, user_id, emoji_id, emoji_text)
);

CREATE TABLE IF NOT EXISTS channel_pins (
    channel_id bigint REFERENCES channels (id) ON DELETE CASCADE,
    message_id bigint REFERENCES messages (id) ON DELETE CASCADE,
    PRIMARY KEY (channel_id, message_id)
);
