DROP TABLE IF EXISTS votes CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS forums CASCADE;
DROP TABLE IF EXISTS posts CASCADE;
DROP TABLE IF EXISTS threads CASCADE;
-- --
CREATE EXTENSION IF NOT EXISTS citext;
-- --
SET LOCAL synchronous_commit TO OFF;
-- --
CREATE TABLE IF NOT EXISTS users (
	about CITEXT,
	email CITEXT NOT NULL UNIQUE,
	fullname CITEXT NOT NULL,
	nickname CITEXT COLLATE "ucs_basic" NOT NULL UNIQUE
);
-- --
CREATE TABLE IF NOT EXISTS forums (
	posts BIGINT DEFAULT 0,
	slug CITEXT NOT NULL UNIQUE,
	threads INTEGER DEFAULT 0,
	title CITEXT NOT NULL,
	author CITEXT COLLATE "ucs_basic" NOT NULL REFERENCES users (nickname)
);
-- --
CREATE TABLE IF NOT EXISTS threads (
	id SERIAL PRIMARY KEY,
	author CITEXT COLLATE "ucs_basic" NOT NULL REFERENCES users (nickname),
	created TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
	forum CITEXT NOT NULL REFERENCES forums (slug),
	message CITEXT NOT NULL,
	slug CITEXT UNIQUE,
	title CITEXT NOT NULL,
	votes INTEGER DEFAULT 0
);
-- --
CREATE TABLE IF NOT EXISTS posts (
	author CITEXT COLLATE "ucs_basic" NOT NULL REFERENCES users (nickname),
	created TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
	forum CITEXT REFERENCES forums (slug),
	id BIGSERIAL PRIMARY KEY,
	isedited BOOLEAN DEFAULT FALSE,
	message text NOT NULL,
	parent BIGINT DEFAULT 0,
	thread INTEGER NOT NULL REFERENCES threads (id)
);
-- --
CREATE TABLE IF NOT EXISTS votes (
	nickname CITEXT COLLATE "ucs_basic" NOT NULL REFERENCES users (nickname),
	voice INTEGER NOT NULL,
	thread INTEGER NOT NULL REFERENCES threads (id),
	UNIQUE (nickname, thread)
);
-- --
CREATE TABLE IF NOT EXISTS forum_users (
  forum CITEXT REFERENCES forums(slug),
  author CITEXT REFERENCES users(nickname),
  UNIQUE (forum,author)
);

CREATE INDEX IF NOT EXISTS f_users ON forum_users (forum,author);




GRANT ALL PRIVILEGES ON ALL TABLEs IN schema public to tpforumsapi;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO tpforumsapi;




CREATE OR REPLACE FUNCTION check_message() RETURNS TRIGGER AS '
BEGIN
  NEW.isedited:=false;
  RETURN NEW;
END;
'
LANGUAGE plpgsql;
-- --
CREATE TRIGGER change_message
BEFORE UPDATE ON posts FOR EACH ROW WHEN (new.message=old.message)
EXECUTE PROCEDURE check_message();
-- --
-- --
CREATE OR REPLACE FUNCTION post_create() RETURNS TRIGGER AS '
BEGIN
  IF NEW.parent<>0 AND NOT EXISTS (SELECT id FROM posts WHERE id=NEW.parent AND thread=NEW.thread) THEN
    RAISE ''Parent post exc'';
  END IF;
  UPDATE forums SET posts=posts+1 WHERE slug=NEW.forum;
  RETURN NEW;
END;
'
LANGUAGE plpgsql;
-- --
CREATE TRIGGER post_create
BEFORE INSERT ON posts FOR EACH ROW
EXECUTE PROCEDURE post_create();
-- --
-- --
CREATE OR REPLACE FUNCTION thread_create() RETURNS TRIGGER AS '
BEGIN
  UPDATE forums SET threads=threads+1 WHERE slug=NEW.forum;
  RETURN NEW;
END;
'
LANGUAGE plpgsql;
-- --
CREATE TRIGGER thread_create
BEFORE INSERT ON threads FOR EACH ROW
EXECUTE PROCEDURE thread_create();
-- --
-- --
-- --
-- --
-- --
-- --
CREATE OR REPLACE FUNCTION vote_update() RETURNS TRIGGER AS'
BEGIN
  IF (OLD.voice<>NEW.voice) THEN
    IF (NEW.voice=-1) THEN
      UPDATE threads SET votes=votes-2 WHERE id=NEW.thread;
    ELSE
      UPDATE threads SET votes=votes+2 WHERE id=NEW.thread;
    END IF;
  END IF;
  RETURN OLD;
END;
'
LANGUAGE plpgsql;
-- --
-- --
CREATE OR REPLACE FUNCTION vote_create() RETURNS TRIGGER AS'
BEGIN
  UPDATE threads SET votes=votes+NEW.voice WHERE id=NEW.thread;
  RETURN NEW;
END;
'
LANGUAGE plpgsql;
-- --
--
-- CREATE OR REPLACE FUNCTION forum_create() RETURNS TRIGGER AS'
-- BEGIN
--   NEW.author=(SELECT nickname FROM users WHERE nickname=NEW.author);
--   RETURN NEW;
-- END;
-- '
-- LANGUAGE plpgsql;
--
--
--
-- CREATE TRIGGER forum_create
-- BEFORE INSERT ON forums FOR EACH ROW
-- EXECUTE PROCEDURE forum_create();
--
-- --
CREATE TRIGGER vote_create
AFTER INSERT ON votes FOR EACH ROW
EXECUTE PROCEDURE vote_create();
-- --
CREATE TRIGGER vote_update
AFTER UPDATE ON votes FOR EACH ROW
EXECUTE PROCEDURE vote_update();
-- --
--
-- Сделать индекс по полям, по которым идет выборка
-- Если есть подзапросы поменять их на JOIN.
-- Делать меньше запросов впринципе. Покрываюий индекс?
-- Денормализовать данные?
--
CREATE INDEX IF NOT EXISTS forum_i ON forums (slug); --+

CREATE INDEX IF NOT EXISTS user_i ON users (nickname); --+

CREATE INDEX IF NOT EXISTS thtead_i ON threads (id); --+
CREATE INDEX IF NOT EXISTS thread_slug ON threads (slug);
CREATE INDEX IF NOT EXISTS thread_ii ON threads (forum,created);
CREATE INDEX IF NOT EXISTS thread_iii ON threads (forum,author);

CREATE INDEX IF NOT EXISTS post_i ON posts (id, created); --+
CREATE INDEX IF NOT EXISTS post_ii ON posts (thread, id, created);
CREATE INDEX IF NOT EXISTS post_iii ON posts (forum, author, created);
-- CREATE INDEX IF NOT EXISTS post_iiii ON posts (parent, thread);

CREATE INDEX IF NOT EXISTS vote_i ON votes (nickname, thread); --+


