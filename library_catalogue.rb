require 'sinatra'
require 'rack'
# use Rack::Logger
require 'sinatra/content_for'
require 'securerandom'

require_relative './lib/database_persistence'
require_relative './lib/pagination.rb'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
  set :environment, :production
end

before do
  @storage = DatabasePersistence.new(logger)
  puts(@storage.whoami)
  authenticate!
end

before "/admin/*" do 
  authenticate_admin!
end

# =============== METHODS =============== 
helpers do
  def logger
    request.logger
  end

  def logged_in?
    !!session[:user]
  end

  def admin?
    session[:user][:username] == "admin"
  end
end

# ensure every page can only be accessed if user is logged on
def authenticate!
  if !logged_in? && (request.path_info != "/login" && request.path_info != "/signup")
    session[:error] = "You must be logged in first to view that page."
    redirect "/login"
  end
end

# prevents non-admins from accessing admin pages
def authenticate_admin!
  unless admin?
    session[:error] = "You do not have access to view that page."
    redirect "/"
  end
end

# prevent unauthorized users from accessing specific pages
def authenticate_for_private_access!
  if !admin? && session[:user][:username] != params[:username]
    session[:error] = "You do not have access to that page."
    redirect "/"
  end
end

def validate_book!(id)
  unless @storage.book_exists?(id)
    session[:error] = "Whoops! Something went wrong. The book id '#{id}' does not exist in our system. "
    redirect "/books"
  end
end

def validate_user!(username, redirect_path = "/")
  unless @storage.user_exists?(username)
    session[:error] = "We cannot find anyone with the username '#{params[:username]}'."
    redirect redirect_path
  end
end

# =============== ROUTES =============== 

not_found do
  session[:error] = "Sorry, that page doesn't exist."
  redirect "/"
end

get "/" do
  redirect "/books?page=1&genre=all"
end

get "/login" do
  erb :login
end

get "/signup" do
  erb :signup
end

get "/logout" do
  session[:success] = "You logged out."
  session[:user] = nil
  redirect "/login"
end

get "/profile/:username" do
  validate_user!(params[:username])
  authenticate_for_private_access!

  @user = @storage.get_user_info(params[:username])
  @reserved_books = @storage.get_reserved_books(@user["id"])
  @checked_out_books = @storage.get_checked_out_books(@user["id"])
  
  erb :profile
end

get "/profile/:username/edit" do
  @old_username = params[:username].downcase
  validate_user!(@old_username)
  authenticate_for_private_access!
  
  user = @storage.get_user_info(@old_username)
  @id = user["id"]
  @full_name = user["full_name"]
  
  erb :edit_profile
end

post "/profile/:username/edit" do 
  validate_user!(params[:username])

  @id = params[:id]
  @full_name = params["full_name"]
  @old_username = params[:username]
  @new_username = params["new_username"].downcase

  if @full_name.empty?
    session[:error] = "You must enter your name."
    erb :edit_profile
  elsif @new_username.empty?
    session[:error] = "You must enter a username."
    erb :edit_profile
  elsif @new_username.include?(' ')
    session[:error] = "Your username cannot contain spaces."
    erb :edit_profile
  elsif @old_username != @new_username && @storage.user_exists?(@new_username) 
    session[:error] = "That username is already taken. Please choose another one."
    erb :edit_profile
  else
    if !admin? 
      session[:user][:username] = @new_username
      session[:user][:full_name] = @full_name
    end
    @storage.edit_user(@id, @new_username, @full_name)
    session[:success] = "Profile has been updated."
    redirect "/"
  end

end

get "/books" do
  books_per_page = 5
  current_page = params[:page]

  if current_page.nil?
    current_page = 1
  elsif current_page.to_i.to_s != current_page # check if the page provided is a number  
    session[:error] = "Whoops! Something went wrong. You cannot view that page. You must use a number for the page."
    redirect "/books"
  else
    current_page = current_page.to_i
  end

  @pagination = Pagination.new(books_per_page, @storage.total_num_books, current_page)

  if @pagination.reached_lower_limit?
    session[:error] = "Whoops! Something went wrong. You must view a page number greater than 0."
    redirect "/books"
  elsif @pagination.reached_upper_limit?
    session[:error] = "Whoops! Something went wrong. We don't have enough books to be able to display that many pages! You must view a page number less than #{@pagination.max_pages}."
    redirect "/books"
  end

  @books = @storage.books_grouped(@pagination.items_per_page, @pagination.offset)

  erb :home
end

get "/view/:id" do
  id = params[:id]
  validate_book!(id)
  @book = @storage.book(id)
  erb :book
end

post "/login" do
  @username = params["username"].downcase
  @password = params["password"]

  if @username.empty?
    session[:error] = "You must enter a username."
    erb :login
  elsif @password.empty?
    session[:error] = "You must enter a password."
    erb :login
  else
    if !@storage.user_exists?(@username)
      session[:error] = "We cannot find anyone with the username '#{@username}'."
      erb :login
    elsif !@storage.login_success?(@username, @password)
      session[:error] = "Incorrect password entered."
      erb :login
    else
      user = @storage.get_user_info(@username)
      session[:user] = {
        id: user["id"],
        username: user["username"],
        full_name: user["full_name"],
        account_created_on: user["account_created_on"]
      }
      session[:success] = "You are now logged in as #{@username}."
      redirect "/"
    end
  end
end

post "/signup" do
  @full_name = params["full_name"]
  @username = params["username"].downcase
  @password = params["password"]

  if @full_name.empty?
    session[:error] = "You must enter your name."
    erb :signup
  elsif @username.empty?
    session[:error] = "You must enter a username."
    erb :signup
  elsif @password.empty?
    session[:error] = "You must enter a password."
    erb :signup
  elsif @username.include?(' ')
    session[:error] = "Your username cannot contain spaces."
    erb :signup
  elsif @storage.user_exists?(@username)
    session[:error] = "That username is already taken. Please choose another one."
    erb :signup
  else
    @storage.create_user(@username, @password, @full_name)
    session[:success] = "You have successfully signed up."
    redirect "/login"
  end
end

post "/reserve" do
  id = params[:id]
  validate_book!(id)

  book = @storage.book(id)
  @storage.reserve_book(session[:user][:id], id)
  session[:success] = "You have successfully reserved the book '#{book["title"]}'. Awaiting confirmation from librarian."
  redirect "/"
end

post "/cancel_reservation/book" do
  book_id = params[:id]
  validate_book!(book_id)

  @storage.cancel_reservation(book_id)
  session[:success] = "You've cancelled a reservation for the book '#{params[:title]}'"
  redirect "/"
end


# ============================= ADMIN PRIVILEGES

get "/admin/" do
  erb :admin
end

get "/admin/users" do
  @users = @storage.get_all_user_info
  erb :users
end

get "/admin/reserved_books" do
  @reserved_books = @storage.get_all_reserved_books
  erb :reserved_books
end

get "/admin/checked_out_books" do
  @checked_out_books = @storage.get_all_checked_out_books
  erb :checked_out_books
end

get "/admin/add/book" do
  erb :edit_book
end

post "/admin/delete/book" do
  id = params[:id].to_i
  validate_book!(id)

  @book = @storage.book(id)
  @storage.delete_book(id)
  session[:success] = "You have successfully removed '#{@book["title"]}' from the system."
  redirect "/"
end

post "/admin/add/book" do
  @title = params["title"]
  @author = params["author"]
  @published = params["published"]
  @cover_page_link = params["cover_page_link"]
  @genre = params["genre"]
  @description = params["description"]

  if @title.empty? || @title.length > 200
    session[:error] = "You must input a title that is between 1-200 characters."
    erb :edit_book
  elsif @author.empty? || @author.length > 100
    session[:error] = "You must input an author that is between 1-100 characters."
    erb :edit_book
  elsif @genre.empty? || @genre.length > 100
    session[:error] = "You must input one or multiple genres that is between 1-100 characters."
    erb :edit_book
  else
    @published = nil if @published.empty?
    @cover_page_link = '#' if @description.empty?
    @description = nil if @description.empty?

    @storage.add_book(@title, @author, @published, @cover_page_link, @genre, @description)
    session[:success] = "You have successfully added the book '#{@title}' by #{@author} to the library."
    redirect "/admin/add/book"
  end
end

post "/admin/delete/user/:username" do
  validate_user!(params[:username], "/admin/users")

  @storage.delete_user(params[:username])
  session[:success] = "You have successfully removed the user '#{params[:username]}' from the system."
  redirect "/admin/users"
end

post "/admin/checkout/book" do
  book_id = params[:id]
  validate_book!(book_id)

  user_id = params[:user_id]
  validate_user!(params[:username])

  book = @storage.book(book_id)
  @storage.check_out_book(book_id, user_id)
  session[:success] = "You have successfully checked out '#{book["title"]}'."
  redirect "/admin/reserved_books"
end

get "/admin/edit/book/:id" do
  id = params[:id].to_i
  validate_book!(id)

  @book = @storage.book(id)
  @id = @book["id"]
  @title = @book["title"]
  @author = @book["author"]
  @published = @book["published"]
  @cover_page_link = @book["cover_page_link"]
  @genre = @book["genre"]
  @description = @book["description"]

  erb :edit_book
end

post "/admin/edit/book" do
  id = params[:id].to_i
  validate_book!(id)

  @title = params["title"]
  @author = params["author"]
  @published = params["published"]
  @cover_page_link = params["cover_page_link"]
  @genre = params["genre"]
  @description = params["description"]

  if @title.empty? || @title.length > 200
    session[:error] = "You must input a title that is between 1-200 characters."
    erb :edit_book
  elsif @author.empty? || @author.length > 100
    session[:error] = "You must input an author that is between 1-100 characters."
    erb :edit_book
  elsif @genre.empty? || @genre.length > 100
    session[:error] = "You must input one or multiple genres that is between 1-100 characters."
    erb :edit_book
  else
    @published = nil if @published.empty?
    @cover_page_link = nil if @cover_page_link.empty?
    @storage.edit_book(id, @title, @author, @published, @cover_page_link, @genre, @description)
    session[:success] = "You have successfully edited the book '#{@title}' by #{@author}."
    redirect "/"
  end
end

post "/admin/return/book" do
  book_id = params[:id].to_i
  validate_book!(book_id)
  
  user_id = params[:user_id]
  validate_user!(params[:username])
  
  book = @storage.book(book_id)
  @storage.return_book(book_id)
  session[:success] = "You have successfully returned '#{book["title"]}'."
  redirect "/admin/checked_out_books"
end