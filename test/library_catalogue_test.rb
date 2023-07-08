ENV['APP_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'

require_relative '../library_catalogue'

Minitest::Reporters.use!

class LibraryCatalogueTest < Minitest::Test 
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end

  def login
    {"rack.session" => {:user => {full_name: "Foo Bar Baz Qux", username: "foo_bar_baz"}}}
  end

  def teardown
    PG.connect(dbname: "test").exec("DELETE FROM users WHERE id>5")
  end

  # ============== TESTS ============== 

  def test_home_page
    get "/", {}, login
    assert_equal(last_response.status, 302)
    follow_redirect!
    assert(last_response.ok?)
    assert_includes(last_response.body, "Showing 1-5 of 12")
  end

  def test_error_for_invalid_page
    get "/books?page=999999999999", {}, login
    assert_equal(last_response.status, 302)
    follow_redirect!
    assert_includes(last_response.body, "Whoops! Something went wrong. You cannot view that page. You must view a page number less than 3.")

    get "/books?page=-999999999999", {}, login
    assert_equal(last_response.status, 302)
    follow_redirect!
    assert_includes(last_response.body, "Whoops! Something went wrong. You cannot view that page. You must view a page number greater than 0.")
  end

  def test_default_page_number
    get "/books", {}, login
    assert(last_response.ok?)
    assert_includes(last_response.body, "Showing 1-5 of 12")
  end

  def test_error_for_page_as_string
    get "/books?page=heres-some-nonsense", {}, login
    assert_equal(last_response.status, 302)
    follow_redirect!
    assert_includes(last_response.body, "Whoops! Something went wrong. You cannot view that page. You must use a number for the page.")
  end

  def test_view_book
    get "/view/1", {}, login
    assert(last_response.ok?)
    assert_includes(last_response.body, "To Kill a Mocking Bird")
    assert_includes(last_response.body, "Harper Lee")
    assert_includes(last_response.body, "Thriller, Fiction, Novel")
    assert_includes(last_response.body, "Book is currently unavailable")
  end

  def test_error_for_invalid_book_id
    get "/view/999999999", {}, login
    assert_equal(last_response.status, 302)
    follow_redirect!
    assert(last_response.ok?)
    assert_includes(last_response.body, "Sorry. The book id you entered '999999999' is not in our system.")

    get "/", {}, login
    refute_includes(last_response.body, "Sorry. The book id you entered '999999999' is not in our system.")
  end

  def test_inputs_do_not_reset_for_login_page
    post "/login", {"username" => "johnsmith123", "password" => ""}
    assert_includes(last_response.body, "johnsmith123")
  end

  def test_denied_access_unless_logged_in
    get "/"
    assert_equal(last_response.status, 302)
    follow_redirect!
    assert_includes(last_response.body, "You must be logged in first to view that page.")
  end

  def test_error_for_invalid_login_info
    post "/login", {"username" => "fakeusername", "password" => ""}
    assert_includes(last_response.body, "You must enter a password.")

    post "/login", {"username" => "fakeusername", "password" => "password"}
    assert_includes(last_response.body, "We cannot find anyone with the username 'fakeusername'.")
  end


  def test_error_for_invalid_signup_info
    post "/signup", {"full_name" => "", "username" => "", "password" => ""}
    assert(last_response.ok?)
    assert_includes(last_response.body, "You must enter your name.")
    post "/signup", {"full_name" => "John Smith", "username" => "", "password" => ""}
    assert_includes(last_response.body, "You must enter a username")
    post "/signup", {"full_name" => "John Smith", "username" => "johnsmith1234", "password" => ""}
    assert_includes(last_response.body, "You must enter a password")
  end

  def test_sign_up
    post "/signup", {"full_name" => "John Smith", "username" => "johnsmith1234", "password" => "password"}
    assert_equal(last_response.status, 302)
    follow_redirect!
    assert_includes(last_response.body, "You have successfully signed up.")

    post "/login", {"username" => "johnsmith1234", "password" => "password"}
    follow_redirect!
    follow_redirect!
    assert_includes(last_response.body, "You are now logged in as johnsmith1234.")
  end

  def test_logout
    get "/logout", {}, login
    assert_equal(last_response.status, 302)
    follow_redirect!
    assert_includes(last_response.body, "You logged out.")
  end

  def test_profile_page
    get "/profile", {}, login
    assert(last_response.ok?)
    assert_includes(last_response.body, "Foo Bar Baz Qux")
    assert_includes(last_response.body, "foo_bar_baz")
    assert_includes(last_response.body, "You have no books placed on reservation.")
    assert_includes(last_response.body, "You have no books checked out.")
  end


  # def test_reserve_book
  #   post "/reserve?id=2", {}, login
  #   assert_includes(last_response.body, "You have successfully reserved the book 'Nineteen Eighty-Four")

  #   get "/profile", {}, login
  #   assert(last_response.ok?)
  #   assert_includes(last_response.body, "Foo Bar Baz Qux")
  #   assert_includes(last_response.body, "foo_bar_baz")
  #   assert_includes(last_response.body, "Books currently reserved:")
  #   assert_includes(last_response.body, "Nineteen Eighty-Four --- George Orwell")
  # end

  def test_error_for_reserving_nonextistent_book
    post "/reserve?id=9999999999", {}, login
    assert_includes(last_response.body, "Whoops! Something went wrong. You cannot reserve that book as it is not in our system.")
  end
end