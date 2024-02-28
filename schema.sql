CREATE USER admin;
GRANT ALL PRIVILEGES ON DATABASE library to admin;
SET role admin;

CREATE TYPE status AS ENUM('available', 'reserved', 'unavailable');

CREATE TABLE users (
  id serial PRIMARY KEY,
  username varchar(50) NOT NULL UNIQUE CHECK(username NOT LIKE '% %'),
  password text NOT NULL,
  full_name varchar(100) NOT NULL,
  account_created_on date NOT NULL DEFAULT NOW()
);

/* Problem with foreign key constraint
  - on delete set null, unable to delete records in
  - users table if referenced in books because it violates
  - the status_matches_user_id_state constraint

*/
CREATE TABLE books (
  id serial PRIMARY KEY,
  title varchar(200) NOT NULL,
  author varchar(100) NOT NULL,
  genre varchar(100) NOT NULL,
  published date,
  description text,
  status status NOT NULL DEFAULT 'available',
  cover_page_link text NOT NULL DEFAULT '#',
  user_id integer REFERENCES users(id) ON DELETE SET NULL DEFAULT NULL
);

ALTER TABLE books 
ADD CONSTRAINT status_matches_user_id_state CHECK (
  (user_id IS NOT NULL AND (status='unavailable' OR status='reserved')) OR 
  (user_id IS NULL AND status='available')
);

INSERT INTO users (id, username, password, full_name)
           VALUES (1, 'admin', '$2a$12$l.nxnTnKaxuCmNIms/.Z2erizU0smu.W2Ho8SJIzq2F/RpZHoV2aK', 'admin'),
                  (2, 'catchemall999', '$2a$12$xPGxr91IIClWsitpFutmQevbvpzrZ0VMxKurloFL1oGmjZuU/9Ka2', 'Ash Ketchum'),
                  (3, 'iwilldominatetheworld', '$2a$12$ZFFKU7pzUTuTegXiuYxvQOvksW6kfUF6Nj/MYHq2BBrEZgsktXHmS', 'Lord Voldemort'),
                  (4, 'onion_rings', '$2a$12$SAF4VTPPpha1N85lz29Qie0jZEdwvyXxfjeYrG6/kt//o00RdcpVu', 'Mr. O''Rings'),
                  (5, 'foo_bar_baz', '$2a$12$QYu1JwY1jNU3oaagzu.BbOMIIoUczbQyRZCD.ZhI/p4V0H1zkmUmC', 'Foo Bar Baz Qux');

INSERT INTO books (title, author, genre, published, user_id, status)
           VALUES ('To Kill a Mocking Bird', 'Harper Lee', 'Thriller, Fiction, Novel', '07-11-1960', 1, 'unavailable'),
                  ('Nineteen Eighty-Four', 'George Orwell', 'Science fiction, Dystopian Fiction, Social science fiction, Political fiction', '06-08-1949', NULL, 'available'),
                  ('The Unbearable Lightness of Being', 'Milan Kundera', 'Novel, Romance novel, Philosophical fiction, Magical Realism', NULL, NULL, 'available'),
                  ('Lord of the Flies', 'William Golding', 'Allegorical novel', '11-17-1954', 2, 'unavailable'),
                  ('Gone Girl', 'Gillian Flynn', 'Novel, Thriller, Fiction, Mystery, Suspense', '05-24-2012', NULL, 'available'),
                  ('Notes From Underground', 'Fydor Dostoevsky', 'Novel, Novella, Fantasy Fiction, Philosophical Fiction', NULL, NULL, 'available'),
                  ('Brave New World', 'Aldous Huxley', 'Novel, Science fiction, Dystopian Fiction', NULL, NULL, 'available'),
                  ('Harry Potter and the Philosopher''s Stone', 'J.K. Rowling', 'Novel, Children''s literature, Fantasy Fiction, High fantasy', '06-26-1997', NULL, 'available'),
                  ('Harry Potter and the Chamber of Secrets', 'J.K. Rowling', 'Novel, Children''s literature, Fantasy Fiction, High fantasy', '07-02-1998', NULL, 'available'),
                  ('Harry Potter and the Prisoner of Azkaban', 'J.K. Rowling', 'Novel, Children''s literature, Fantasy Fiction, High fantasy', '07-08-1999', NULL, 'available'),
                  ('Harry Potter and the Goblet of Fire', 'J.K. Rowling', 'Novel, Children''s literature, Fantasy Fiction, High fantasy', '07-08-2000', 3, 'unavailable'),
                  ('Harry Potter and the Order of the Phoenix', 'J.K. Rowling', 'Novel, Children''s literature, Fantasy Fiction, High fantasy', '06-21-2003', NULL, 'available');

           
                  
