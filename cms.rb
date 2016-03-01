require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

root = File.expand_path('..', __FILE__)

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  @files = Dir.glob(root + '/data/*').map { |path| File.basename path }
end

get '/' do
  erb :index, layout: :layout
end

get '/:filename' do
  headers['Content-Type'] = 'text/plain'
  File.read(root + '/data/' + params[:filename])
end
