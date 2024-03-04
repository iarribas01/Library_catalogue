require 'bcrypt'
require 'pg'
ENV['APP_ENV'] = "production"
class DatabasePersistence
  def initialize(logger)
    @logger = logger
    if (ENV['APP_ENV'] == "test")
      @db = PG.connect(dbname: "test")
    elsif (ENV['APP_ENV'] == "production")
      @db = PG.connect(host: "localhost", user: "admin", password: "password123", dbname: "library")
    elsif (ENV['APP_ENV'] === "development")
      @db = PG.connect(dbname: "development")
    else
      puts("Invalid app environment: #{ENV['APP_ENV']}")
    end
  end

  def connect_db_admin
    puts("connected as #{whoami}")
    sql = "SET ROLE admin"
    query(sql)
  end

  def connect_db_user
    puts("connected as #{whoami}")
    sql = "SET ROLE admin"
    query(sql)
  end

  def whoami
    sql = "SELECT current_user"
    query(sql).first
  end

  def query(statement, *params)
    (@logger.info("#{statement}: #{params}")) if (ENV['APP_ENV'] != "test")
    @db.exec_params(statement, params)
  end

  def book(id)
    sql = "SELECT * FROM books WHERE id=$1"
    query(sql, id).first
  end

  def books_grouped(books_per_page, offset)
    sql = "SELECT * FROM books ORDER BY title LIMIT $1 OFFSET $2"
    query(sql, books_per_page, offset)
  end

  def book_exists?(id)
    sql = "SELECT exists (SELECT 1 FROM books WHERE id=$1)"
    query(sql, id).first['exists'] == 't'
  end

  def total_num_books
    sql = "SELECT count(id) FROM books"
    query(sql).first["count"].to_i
  end

  def login_success?(username, password)
    sql = <<~SQL
      SELECT username, password FROM users
      WHERE username=$1
    SQL

    user = query(sql, username).first
    password_match?(password, user["password"])
  end

  def user_exists?(username)
    sql = "SELECT exists (SELECT 1 FROM users WHERE username=$1)"
    query(sql, username).first["exists"] == 't'
  end

  def create_user(username, password, full_name)
    sql = "INSERT INTO users (username, password, full_name) VALUES ($1, $2, $3)"
    query(sql, username, encrypt(password), full_name)
  end

  def edit_user(id, username, full_name)
    sql = "UPDATE users SET username=$1, full_name=$2 WHERE id=$3"
    query(sql, username, full_name, id)
  end

  def get_user_info(username)
    sql = "SELECT * FROM users WHERE username=$1"
    query(sql, username).first
  end

  def reserve_book(user_id, book_id)
    sql = "UPDATE books SET status='reserved', user_id=$1 WHERE id=$2"
    query(sql, user_id, book_id)
  end

  def get_reserved_books(user_id)
    sql = "SELECT * FROM books WHERE user_id=$1 AND status='reserved'"
    query(sql, user_id).to_a
  end

  def cancel_reservation(book_id)
    sql = "UPDATE books SET status='available', user_id=NULL WHERE id=$1"
    query(sql, book_id)
  end

  def get_checked_out_books(user_id)
    sql = "SELECT * FROM books WHERE user_id=$1 AND status='unavailable'"
    query(sql, user_id).to_a
  end

  def get_user_id(username)
    sql = "SELECT id FROM users WHERE username=$1"
    query(sql, username).first["id"].to_i
  end

  # admin only priviledges ==================

  def get_all_user_info
    sql = "SELECT * FROM users WHERE username!='admin' ORDER BY full_name"
    query(sql)
  end

  def check_out_book(book_id, user_id)
    sql = "UPDATE books SET status='unavailable', user_id=$1 WHERE id=$2"
    query(sql, user_id, book_id)
  end

  def delete_user(username)
    sql = "DELETE FROM users WHERE username=$1"
    query(sql, username)
  end

  def get_all_reserved_books
    sql = <<~SQL
      SELECT u.username, b.id, b.title, b.author, b.status, b.user_id FROM books as b
      JOIN users AS u
      ON b.user_id = u.id
      WHERE status='reserved';
    SQL

    query(sql)
  end

  def get_all_checked_out_books
    sql = <<~SQL
      SELECT u.username, b.id, b.title, b.author, b.status, b.user_id FROM books as b
      JOIN users AS u
      ON b.user_id = u.id
      WHERE status='unavailable';
    SQL

    query(sql)
  end

  def delete_book(book_id)
    sql = "DELETE FROM books WHERE id=$1"
    query(sql, book_id)
  end

  def return_book(book_id)
    sql = "UPDATE books SET status='available', user_id=NULL WHERE id=$1;"
    query(sql, book_id)
  end

  def add_book(title, author, published, cover_page_link, genre, description)
    sql = <<~SQL
      INSERT INTO books (title, author, published, cover_page_link, genre, description)
      VALUES ($1, $2, $3, $4, $5, $6)
    SQL
    query(sql, title, author, published, cover_page_link, genre, description)
  end

  def edit_book(id, title, author, published, cover_page_link, genre, description)
    sql = <<~SQL
      UPDATE books
      SET title=$1, author=$2, published=$3, cover_page_link=$4, genre=$5, description=$6
      WHERE id=$7
    SQL
    query(sql, title, author, published, cover_page_link, genre, description, id)
  end

  private

  def encrypt(password)
    BCrypt::Password.create(password)
  end

  # checks plaintext guessed password with hashed password that's stored in database
  def password_match?(guessed_pw, stored_pw)
    stored_pw = BCrypt::Password.new(stored_pw)
    stored_pw == guessed_pw
  end
end