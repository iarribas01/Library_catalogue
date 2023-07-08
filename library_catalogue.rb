require 'sinatra'
require 'sinatra/contrib'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'securerandom'

require_relative './database_persistence'

BOOKS_PER_PAGE = 5

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
  set :environment, :development
end

before do
  @storage = DatabasePersistence.new(logger)
  authenticate!
end

before "/admin/*" do 
  authenticate_admin!
end

# =============== METHODS =============== 
helpers do
  # given the current page number the user is on
  # returns array of page numbers the user
  # can nagivate to -- to be used in pagination
  def nav_pages_array(p)
    if max_pages == 1
      [ 1 ]
    elsif max_pages == 2
      [ 1, 2 ]
    elsif reached_lower_limit?( p-1 )
      [ p, p+1, p+2 ]
    elsif reached_upper_limit?( p )
      [ p-2, p-1, p ]
    else
      [ p-1, p, p+1 ]
    end
  end
  
  def logged_in?
    !!session[:user]
  end

  def admin?
    session[:user][:username] == "admin"
  end
end

def authenticate!
  if !logged_in? && (request.path_info != "/login" && request.path_info != "/signup")
    session[:error] = "You must be logged in first to view that page."
    redirect "/login"
  end
end

def authenticate_admin!
  unless admin?
    session[:error] = "You do not have access to view that page."
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

def max_pages
  (@storage.total_num_books.to_f / BOOKS_PER_PAGE ).ceil
end

def reached_lower_limit?(page)
  page <= 0
end

def reached_upper_limit?(page)
  page > max_pages
end

# =============== ROUTES =============== 

not_found do
  session[:error] = "Sorry, that page doesn't exist."
  redirect "/"
end

get "/" do
  redirect "/books?page=1&genre=all"
end

get "/search" do
  genres = params["genre"].split(',').map(&:strip)
  if genres.length == 0
    session[:hint] = "You must enter a genre."
    redirect "/"
  else
    books_grouped_for_genre(BOOKS_PER_PAGE, @start - 1, genres)



  end
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


# ======== error for nonexistent username
# ========= must be your own profile or admin
get "/profile/:username" do
  
  @user = @storage.get_user_info(params[:username])
  @reserved_books = @storage.get_reserved_books(@user["id"])
  @checked_out_books = @storage.get_checked_out_books(@user["id"])
  
  erb :profile
end

get "/books" do
  # default page to 1 if not specified
  if params[:page].nil?
    @page = 1 if params[:page].nil?
  # check if the page provided is a number 
  elsif params[:page].to_i.to_s != params[:page] 
    session[:error] = "Whoops! Something went wrong. You cannot view that page. You must use a number for the page."
    redirect "/books"
  else
    @page = params[:page].to_i
  end
  
  if reached_lower_limit?(@page)
    session[:error] = "Whoops! Something went wrong. You cannot view that page. You must view a page number greater than 0."
    redirect "/books"
  elsif reached_upper_limit?(@page)
    session[:error] = "Whoops! Something went wrong. You cannot view that page. You must view a page number less than #{max_pages}."
    redirect "/books"
  else
    @finish = @page * BOOKS_PER_PAGE
    @start = @finish - BOOKS_PER_PAGE + 1
    @total_num_books = @storage.total_num_books
    @finish = @finish > @total_num_books ? @total_num_books : @finish
    @books = @storage.books_grouped(BOOKS_PER_PAGE, @start - 1)

    erb :home
  end
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
  id = params[:id].to_i
  validate_book!(id)

  book = @storage.book(id)
  @storage.reserve_book(session[:user][:id], id)
  session[:success] = "You have successfully reserved the book '#{book["title"]}'. Awaiting confirmation from librarian."
  redirect "/"
end

# ============================= ADMIN PRIVILEDGES

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

get "/admin/add_book" do
  erb :add_book
end

post "/admin/delete/book" do
  id = params[:id].to_i
  validate_book!(id)

  @book = @storage.book(id)
  @storage.delete_book(id)
  session[:success] = "You have successfully removed '#{@book["title"]}' from the system."
  redirect "/"
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

post "/admin/cancel_reservation/book" do


end

post "/admin/return/book" do
  book_id = params[:id]
  validate_book!(book_id)
  
  user_id = params[:user_id]
  validate_user!(params[:username])
  
  book = @storage.book(book_id)
  @storage.return_book(book_id)
  session[:success] = "You have successfully returned '#{book["title"]}'."
  redirect "/admin/checked_out_books"
end