# app.rb
require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'pry-remote'
require 'redcarpet'
require 'bcrypt'
require 'yaml'

configure do
  enable :sessions
  set :session_secret, 'the_session'
end

DATA_FOLDER = 'files'
ROOT = File.expand_path('..', __FILE__)
USERS = YAML.load_file(ROOT + '/users.yml')

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("#{ROOT}/test/data", __FILE__)
  else
    File.expand_path("#{ROOT}/#{DATA_FOLDER}", __FILE__)
  end
end

def admin_session
  { "rack.session" => { user: "admin" } }
end

before do
  pattern = File.join(data_path, '*')
  @file_list = Dir.glob(pattern).map{ |f| File.basename(f) }
end

helpers do
  def render_markdown(text)
    renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    renderer.render(text)
  end
end

def signed_in
  session.key?(:user)
end

def check_user_credentials(username, password)
   bcrypt_pw = BCrypt::Password.new(USERS[username])
  ((USERS.keys.include? username) && (bcrypt_pw == password))
end

def not_signed_in_message_and_redirect
  unless signed_in then (session[:error] = "You must be signed in to do that." ; redirect "/" ) end
end

get "/new" do
  not_signed_in_message_and_redirect
  erb :new
end

post "/new" do
  not_signed_in_message_and_redirect
  filename = params[:new_filename]
  unless filename == ''
    path = File.join(data_path, filename)
    File.open(path, "w") do |file|
      file.write('')
    end
    session[:success] = "#{filename} was created."
    redirect "/"
  else
    session[:error] = "A name is required."
    status 422
    erb :new
  end
end

get "/" do
  erb :files
end

post "/:filename" do
  not_signed_in_message_and_redirect
  path = File.join(data_path, params[:filename])
  File.open(path, 'w') do |f|
    f.puts params[:new_content].strip
  end
  session[:success] = "#{params[:filename]} was edited"
  redirect "/"
end

get "/:filename/edit" do |filename|
  not_signed_in_message_and_redirect

  path = File.join(data_path, filename)
  @contents =   File.read(path)
  @filename = filename
  erb :edit
end

get "/:users/signin" do
  redirect "/" if signed_in
  erb :signin
end

post "/users/signin" do
  if signed_in
    redirect "/"
  else
    if check_user_credentials(params[:username], params[:password])
      session[:success] = 'Welcome!'
      session[:user] = params[:username]
      redirect "/"
    else
      status 422
      session[:error] = 'Invalid Credentials.'
      erb :signin
    end
  end
end

post "/users/signout" do
  if signed_in
    session[:user] = nil
  end
  session[:success] = 'You are signed out.'
  redirect "/"
end

post "/:filename/delete" do |filename|
  not_signed_in_message_and_redirect
  path = File.join(data_path, filename)
  File.delete(path) if File.exist? path
  session[:success] = "#{filename} was deleted"
  redirect "/"
end

get "/*.*" do
  base, ext = params[:splat]
  filename = params[:splat].join('.')
  path = File.join(data_path, filename)
  if @file_list.include?(filename)
    @contents = File.read(path)
    case ext
    when 'txt'
      headers['Content-Type'] = 'text/plain'
      @contents
    when 'md'
      headers['Content-Type'] = 'text/html'
      erb render_markdown(@contents)
    end
  else
    session[:error] = "#{filename} doesn't exist."
    redirect "/"
  end
end