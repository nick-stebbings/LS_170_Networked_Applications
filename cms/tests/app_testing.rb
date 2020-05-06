ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "redcarpet"
require "fileutils"

require_relative "../app.rb"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
  end
  
  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end
  
  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document('about.txt')
    create_document('lipsum.txt')
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    ['about.txt', 'lipsum.txt'].each do |filename|
      assert_includes last_response.body, filename
    end
    assert_includes last_response.body, "New Document"
  end

  def test_text_file_renders
    create_document("about.txt", "This is a content management system using SINATRA.")
    get "/about.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body,  "This is a content management system using SINATRA."
  end
  
  def test_markdown_file_renders
    create_document("cheese.md", "*Stilton*")
    get "/cheese.md"
    
    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
    assert_includes last_response.body, '<em>Stilton</em>'
  end
  
  def test_attempt_to_access_invalid_file
    get "/randomfile.txt"
    assert_equal 302, last_response.status
    assert_equal "randomfile.txt doesn't exist.", session[:error]
  end
  
  def test_edit_page_allows_input_and_loads_contents_when_signed_in
    create_document("cheese.md", "*Stilton*")
    get "/cheese.md/edit", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, '*Stilton*'
  end  
  
  def test_edit_page_posts_changes_when_signed_in
    post "/testing.txt", {"new_content" => "This is a test."}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "testing.txt was edited", session[:success]
    
    get "/testing.txt"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "This is a test."
  end
  
  def test_edit_page_when_signed_out
    get "/cheese.md/edit" 
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]
  end

  def test_new_document_page_allows_input_when_signed_in
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
  end

  def test_new_document_when_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]
  end

  def test_new_document_page_disallows_blank_input
    post "/new", {"new_filename" => ""}, admin_session
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_new_document_created_when_valid
    post "/new", {"new_filename" => "valid_filename.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "valid_filename.txt was created.", session[:success]

    get "/"
    assert_includes last_response.body, "valid_filename.txt"
  end

  def test_new_document_created_when_signed_out
    post "/new"
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]
  end
  
  def test_deleting_document_when_signed_in
    filename = 'a_test.txt'
    path = File.join(data_path, filename)
    create_document(filename)

    post "/#{filename}/delete", {}, admin_session
    assert_equal 302, last_response.status
    refute File.exist?(path)
  
    assert_includes session[:success], 'was deleted'
  end
  
  def test_deleting_document_when_signed_out
    filename = 'a_test.txt'
    path = File.join(data_path, filename)
    create_document(filename)

    post "/#{filename}/delete"
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]
  end
  
  def test_signing_in_form_exists
    get '/users/signin'
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<form'
    assert_includes last_response.body, "submit"
  end
  
  def test_signing_in_form_with_valid_credentials
    post '/users/signin', "username" => USERS.keys.first, "password" => USERS.values.first
    assert_equal 302, last_response.status
    assert_equal session[:success], 'Welcome!'
    assert_equal session[:user], 'admin'

    get last_response["Location"]
    assert_includes last_response.body, 'admin is signed in'
  end
  
  def test_signing_in_form_with_invalid_credentials
    post '/users/signin', "username" => 'aaadmin', "password" => 'bleg'
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid'
    refute session[:user]
  end
  
  def test_signed_in_index_has_signout_button
    get '/', {}, admin_session
    assert_includes last_response.body, 'Sign Out</button>'
  end
  
  def test_clicking_signout_button_shows_message
    get '/', {}, admin_session
    assert_includes last_response.body, 'admin is signed in.'

    post '/users/signout'
    
    assert_equal 302, last_response.status
    assert_includes session[:success], 'signed out'
    refute session[:user]
  end
  
  def test_signed_out_index_has_signin_button
    get '/'
    assert_includes last_response.body, 'Sign In</button>'
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end























