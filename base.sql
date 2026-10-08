SET client_min_messages = warning;

DROP TABLE IF EXISTS video_likes CASCADE;
DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS videos CASCADE;
DROP TABLE IF EXISTS channel_members CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS channel_settings CASCADE;
DROP TABLE IF EXISTS channels CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;

CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE channels (
    id SERIAL PRIMARY KEY,
    account_id INT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    avatar_url VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION check_account_has_channel()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM channels WHERE account_id = NEW.id) THEN
        RAISE EXCEPTION 'У акка с id=% должен быть создан 1+ канал', NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_account_has_channel
AFTER INSERT ON accounts
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_account_has_channel();

CREATE TABLE channel_settings (
    channel_id INT PRIMARY KEY REFERENCES channels(id) ON DELETE CASCADE,
    is_comments_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    show_subscribers_count BOOLEAN NOT NULL DEFAULT TRUE,
    default_language VARCHAR(10) NOT NULL DEFAULT 'ru',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscriptions (
    subscriber_channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    target_channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    subscribed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (subscriber_channel_id, target_channel_id),
    CHECK (subscriber_channel_id <> target_channel_id)
);

CREATE TABLE channel_members (
    channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    member_channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('creator', 'moderator', 'user')),
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (channel_id, member_channel_id),
    CHECK (channel_id <> member_channel_id)
);

CREATE UNIQUE INDEX idx_channel_single_creator
ON channel_members(channel_id)
WHERE role = 'creator';

CREATE TABLE videos (
    id SERIAL PRIMARY KEY,
    channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    video_url VARCHAR(500) NOT NULL,
    duration_seconds INT NOT NULL CHECK (duration_seconds > 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    video_id INT NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (length(trim(content)) > 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE video_likes (
    channel_id INT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    video_id INT NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (channel_id, video_id)
);

BEGIN;

INSERT INTO accounts (id, email, password_hash) VALUES
(1, 'tech.author@mail.ru', 'ytfyhjjkkhjclkjlazdgrdydytdtufufuyfugiugui'),
(2, 'lifestyle.creator@gmail.com', 'llal7t8tumfftyaguyfu'),
(3, 'culinary.expert@yandex.ru', 'drtfyuiihuh5e6g');

INSERT INTO channels (id, account_id, name, description, avatar_url) VALUES
(1, 1, 'IT Новости & Код', 'Канал про разработку и базы данных', 'https://storage.cdn/avatars/1.jpg'),
(2, 1, 'Личные заметки', 'Мысли и влоги о жизни в IT', 'https://storage.cdn/avatars/2.jpg'),
(3, 2, 'Студентка ИТМО', 'Учёба, быт и жизнь в Питере', 'https://storage.cdn/avatars/3.jpg'),
(4, 3, 'Шеф на кухне', 'Простые рецепты ресторанных блюд', 'https://storage.cdn/avatars/4.jpg');

COMMIT;

INSERT INTO channel_settings (channel_id, is_comments_enabled, show_subscribers_count, default_language) VALUES
(1, TRUE, TRUE, 'ru'),
(2, TRUE, FALSE, 'ru'),
(3, TRUE, TRUE, 'ru'),
(4, TRUE, TRUE, 'ru');

INSERT INTO channel_members (channel_id, member_channel_id, role) VALUES
(1, 2, 'creator'),
(1, 3, 'moderator'),
(3, 1, 'moderator'),
(4, 1, 'user');

INSERT INTO subscriptions (subscriber_channel_id, target_channel_id) VALUES
(1, 3),
(2, 1),
(2, 3),
(3, 1),
(4, 1);

INSERT INTO videos (id, channel_id, title, description, video_url, duration_seconds) VALUES
(1, 1, 'Реляционная алгебра: операции и примеры', 'Разбор основных операций', 'https://video.cdn/it/rel_algebra.mp4', 840),
(2, 1, 'Нормализация баз данных до 3НФ', 'Разбор 1НФ, 2НФ и 3НФ на примерах', 'https://video.cdn/it/normalization.mp4', 1120),
(3, 3, 'Один день из жизни студентки ИТМО', 'Пары, дорога до универа и вечерняя прогулка по Питеру', 'https://video.cdn/vlog/student_day.mp4', 590),
(4, 4, 'Идеальный стейк рибай дома', 'Инструкция правильной прожарки', 'https://video.cdn/food/steak.mp4', 420);

INSERT INTO comments (video_id, channel_id, content) VALUES
(1, 3, 'наконец-то норм объяснили деление, в конспекте вообще ничего не понятно'),
(1, 2, 'тайминг где про разность есть? пересматривать всё лень'),
(2, 3, 'третья нф наконец дошла, спасибо!!'),
(3, 2, 'а когда ты спишь вообще? у меня такая же беда перед сессией'),
(4, 1, 'сделал по вашему рецепту получилось огонь'),
(4, 3, 'нааааайс, у меня вышла подошва....');

INSERT INTO video_likes (channel_id, video_id) VALUES
(2, 1),
(3, 1),
(4, 1),
(1, 4);

SELECT title, video_url
FROM videos
WHERE channel_id = 1 AND duration_seconds > 600;

SELECT c.name, cm.content
FROM comments cm
JOIN channels c ON cm.channel_id = c.id
WHERE cm.video_id = 1;

SELECT id, name
FROM channels
EXCEPT
SELECT c.id, c.name
FROM channels c
JOIN videos v ON c.id = v.channel_id;

SELECT member_channel_id AS channel_id
FROM channel_members
WHERE channel_id = 1 AND role = 'moderator'
UNION
SELECT subscriber_channel_id AS channel_id
FROM subscriptions
WHERE target_channel_id = 1;

SELECT v.id AS video_id, v.title, COUNT(vl.channel_id) AS likes_count
FROM videos v
LEFT JOIN video_likes vl ON v.id = vl.video_id
GROUP BY v.id, v.title
ORDER BY likes_count DESC;
