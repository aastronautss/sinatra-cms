VALID_EXTENSIONS = ['.md', '.txt'].freeze

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

require 'pry'

root = File.expand_path('..', __FILE__)

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  @files = Dir.glob(data_path + '/*').map { |path| File.basename path }
end

def render_markdown(file_text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(file_text)
end

def render_file(file_path)
  file_name = params[:filename]
  file_text = File.read(file_path)

  case File.extname(file_path)
  when '.md'
    erb render_markdown(file_text), layout: :layout
  else
    headers["Content-Type"] = "text/plain"
    file_text
  end
end

def valid_extension?(file_path)
  VALID_EXTENSIONS.include? File.extname(file_path)
end

def load_user_credentials
  credentials_path = if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/users.yml', __FILE__)
  else
    File.expand_path('../users.yml', __FILE__)
  end
  YAML.load_file(credentials_path)
end

def digest_pass(pass)
  BCrypt::Password.create(pass)
end

def valid_credentials?(user, pass)
  credentials = load_user_credentials

  if credentials.key? user
    correct_pass = credentials[user]
    BCrypt::Password.new(correct_pass) == pass
  else
    false
  end
end

def signed_in?
  !!session[:user]
end

def redirect_if_signed_out
  if !signed_in?
    session[:message] = "You must be signed in to do that."
    redirect '/users/signin'
  end
end

helpers do
  def admin?
    session[:user] == 'admin'
  end
end

get '/' do
  if signed_in?
    erb :index, layout: :layout
  else
    redirect '/users/signin'
  end
end

get '/users/signin' do
  erb :signin, layout: :layout
end

post '/users/signin' do
  user = params[:username]
  pass = params[:password]

  if valid_credentials? user, pass
    session[:user] = user
    session[:message] = "Welcome!"
    redirect '/'
  else
    session[:message] = "Invalid credentials!"
    status 422
    erb :signin
  end
end

post '/users/signout' do
  session[:user] = nil
  session[:message] = "You are now signed out."
  redirect '/users/signin'
end

get '/new' do
  redirect_if_signed_out
  erb :new, layout: :layout
end

post '/new' do
  redirect_if_signed_out

  filename = params[:filename]
  file_path = File.join data_path, filename

  if filename.size == 0
    session[:message] = "A name is required!"
    status 422
    erb :new
  elsif !valid_extension? file_path
    session[:message] = "Invalid file type!"
    status 422
    erb :new
  else
    File.write(file_path, '')
    session[:message] = "#{filename} has been created."

    redirect '/'
  end
end

get '/:filename' do
  redirect_if_signed_out

  file_path = data_path + '/' + params[:filename]

  if File.exist? file_path
    render_file(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
  redirect_if_signed_out

  file_path = data_path + '/' + params[:filename]

  if File.exist? file_path
    @file_text = File.read(file_path)
    erb :edit, layout: :layout
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

post '/:filename' do
  redirect_if_signed_out

  file_path = data_path + '/' + params[:filename]

  if File.exist? file_path
    File.write(file_path, params[:file_text])
    session[:message] = "#{params[:filename]} was updated."
    redirect '/'
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

post '/:filename/delete' do
  redirect_if_signed_out

  file_path = File.join data_path, params[:filename]

  if File.exist? file_path
    File.delete file_path
    session[:message] = "#{params[:filename]} has been deleted."
    redirect '/'
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end
