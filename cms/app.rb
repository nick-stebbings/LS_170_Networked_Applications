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
FILETYPES = { '.txt' => { header: 'text/plain'},
              '.html' => { header: 'text/html'},
              '.md' => { header: 'text/html'}}

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

  def next_file_number(filename, ext, type = :duplicate)
    clean_filename = filename.match(/(.*?)(?=[\(.])/)[1]
    regexp = %r{#{File.basename(clean_filename, ext)}\(#{"v_" if type == :legacy}(?<num>\d)\)#{ext}}x
    candidates = @file_list.select { |f| f =~ regexp }
    duplicate_numbers = candidates.map { |filename| filename.match(regexp)[1].to_i }
    (duplicate_numbers.empty? ? 0 : duplicate_numbers.max) + 1
  end

  def file_contents(filename)
    return filename if filename.nil?
    path = File.join(data_path, filename) if FILETYPES.key?(File.extname(filename))
    File.exist?(path) ? File.read(path) : nil
  end
end

def signed_in?
  session.key?(:user)
end

def check_user_credentials(username, password)
  begin
    bcrypt_pw = BCrypt::Password.new(USERS[username])
    ((USERS.keys.include? username) && (bcrypt_pw == password))  
  rescue => exception
    false
  end
end

def redirect_with_error_unless_signed_in
  unless signed_in? then (session[:error] = "You must be signed in to do that." ; redirect "/" ) end
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def changes_made?(path, new_contents)
  return nil unless File.exist? path
  File.read(path).strip != new_contents.strip
end

get "/new" do
  redirect_with_error_unless_signed_in
  erb :new
end

post "/new" do
  redirect_with_error_unless_signed_in
  filename = params[:new_filename]
  ext = File.extname(filename)
  path = File.join(data_path, filename) if FILETYPES.key?(ext)
  duplicate = !!(copied_content = file_contents(params[:original_filename]))

  if !FILETYPES[ext] 
    session[:error] = (filename == '' ? "A name is required." : "You tried to create an unsupported filetype.")
  elsif (@file_list.include? filename)
    session[:error] = 'The file already exists.'
  else
    create_document(filename, (copied_content if duplicate))
    session[:success] = "#{filename} was created."
    redirect "/"        
  end
    status 422
    erb :new
end

get "/" do
  erb :files
end

post "/:filename" do |filename|
  redirect_with_error_unless_signed_in
  path = File.join(data_path, filename)
  changed = changes_made?(path, params[:new_content].strip)
  if changed
    ext = File.extname(filename)
    v_num = next_file_number(filename, ext, :legacy)
    legacy_filename = "#{File.basename(filename, ext).sub(/(?:[\(].*[\)])?(?=$)/, "(v_#{v_num})") + ext}"
    copied_content = file_contents(filename)
    create_document(legacy_filename, copied_content)
  end

  File.open(path, 'w') do |f|
    f.puts params[:new_content].strip
  end

  session[:success] = "#{filename} was edited" << (changed ? " and the old version was saved." : "")
  redirect "/"
end

get "/:filename/edit" do |filename|
  redirect_with_error_unless_signed_in
  path = File.join(data_path, filename)

  @contents =   File.read(path)
  @filename = filename
  erb :edit
end

get "/:users/signin" do
  redirect "/" if signed_in?
  erb :signin
end

post "/users/signin" do  
  redirect "/" if signed_in?

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

post "/users/signout" do
  session[:user] = nil if signed_in?
  session[:success] = 'You are signed out.'

  redirect "/"
end

post "/:filename/delete" do |filename|
  redirect_with_error_unless_signed_in
  path = File.join(data_path, filename)

  File.delete(path) if File.exist? path
  session[:success] = "#{filename} was deleted"

  redirect "/"
end

get "/:filename" do |filename|
  path = File.join(data_path, filename)
  if @file_list.include?(filename)
    @contents = File.read(path)
    ext = File.extname(path)
    headers['Content-Type'] = FILETYPES[ext][:header]
    case ext
    when '.txt'
      @contents
    when '.md'
      erb render_markdown(@contents)
    end
  else
    session[:error] = "#{filename} doesn't exist."
    redirect "/"
  end
end