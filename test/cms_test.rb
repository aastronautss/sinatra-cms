ENV["RACK_ENV"] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = '')
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env['rack.session']
  end

  def test_index
    create_document 'about.md'
    create_document 'changes.txt'

    get '/', {}, { 'rack.session' => { user: 'admin' } }
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_history_txt
    create_document 'history.txt', 'test text'

    get '/history.txt', {}, { 'rack.session' => { user: 'admin' } }
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'test text'
  end

  def test_history_signed_out
    create_document 'history.txt'

    get '/history.txt'
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_nonexistent_file
    get '/doesnt-exist.txt', {}, { 'rack.session' => { user: 'admin' } }
    assert_equal 302, last_response.status
    assert_equal 'doesnt-exist.txt does not exist.', session[:message]
  end

  def test_markdown_files
    create_document 'test.md', '# This is a header'

    get '/test.md', {}, { 'rack.session' => { user: 'admin' } }
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>This is a header</h1>'
  end

  def test_edit_document
    create_document 'changes.txt'

    get '/changes.txt/edit', {}, { 'rack.session' => { user: 'admin' } }

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_edit_document_signed_out
    create_document 'changes.txt'

    get '/changes.txt/edit'
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    create_document 'changes.txt'
    post "/changes.txt", { file_text: "new content" }, { 'rack.session' => { user: 'admin' } }

    assert_equal 302, last_response.status
    assert_equal 'changes.txt was updated.', session[:message]

    get "/changes.txt", {}, { 'rack.session' => { user: 'admin' } }
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_updating_document_signed_out
    create_document 'chagnes.txt'

    post '/changes.txt', file_text: 'new content'
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form
    get "/new", {}, { 'rack.session' => { user: 'admin' } }

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_vew_new_document_form_signed_out
    get '/new'
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document
    post "/new", { filename: "test.txt" }, { 'rack.session' => { user: 'admin' } }
    assert_equal 302, last_response.status

    get last_response["Location"], {}, { 'rack.session' => { user: 'admin' } }
    assert_includes last_response.body, "test.txt has been created"

    get "/", {}, { 'rack.session' => { user: 'admin' } }
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_signed_out
    post '/new', filename: 'test.txt'
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document_without_filename
    post "/new", { filename: "" }, { 'rack.session' => { user: 'admin' } }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_deleting_document
    create_document("test.txt")

    post "/test.txt/delete", {}, { 'rack.session' => { user: 'admin' } }

    assert_equal 302, last_response.status

    get last_response["Location"], {}, { 'rack.session' => { user: 'admin' } }
    assert_includes last_response.body, "test.txt has been deleted"

    get "/", {}, { 'rack.session' => { user: 'admin' } }
    refute_includes last_response.body, "test.txt"
  end

  def test_deleting_document_signed_out
    create_document('test.txt')

    post '/test.txt/delete'
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Welcome"
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_bad_credentials
    post '/users/signin', username: 'admin', password: 'wrong password'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid credentials!'
  end

  def test_signin_signout
    post '/users/signin', username: 'admin', password: 'secret'
    get last_response['Location']
    assert_includes last_response.body, 'Welcome'

    post '/users/signout'
    get last_response['Location']

    assert_includes last_response.body, 'You are now signed out.'
    assert_includes last_response.body, 'Sign in'
  end
end
