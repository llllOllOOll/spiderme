-- migrate:up
-- Who wrote the post: the account, not only the name shown. Empty for the
-- sample posts and for the ones the API creates: those belong to nobody.
ALTER TABLE posts ADD COLUMN user_id INTEGER REFERENCES users(id);

-- migrate:down
ALTER TABLE posts DROP COLUMN user_id;
