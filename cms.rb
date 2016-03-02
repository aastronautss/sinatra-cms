VALID_EXTENSIONS = ['.md', '.txt']

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'

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

get '/' do
  erb :index, layout: :layout
end

get '/new' do
  erb :new, layout: :layout
end

post '/new' do
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
  file_path = data_path + '/' + params[:filename]

  if File.exist? file_path
    render_file(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
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
