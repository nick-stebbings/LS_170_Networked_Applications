require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

helpers do
  def get_list(id)  # Return a list using the list_id, else return nil
    list = session[:lists].find {|list| list[:id] == id.to_i}
    return (list ? list : nil)

    session[:error] = "The specified list was not found."
    redirect "/lists"
  end
  
  def get_todos(id)
    list = get_list(id)
    return (list ? list[:todos] : nil)
  end

  def get_next_id(of)  # Return next id in overall lists array/a specific TDL
    if (of == :lists)
      max = session[:lists].map { |list| list[:id] }.max || 0
    else
      max = of[:todos].map { |todo| todo[:id] }.max || 0
    end
    max + 1
  end

  def list_completed?(id)
    tasks = get_todos(id)
    tasks.all? { |task| task[:completed] } && tasks.size > 0
  end  
  
  def incomplete_tasks(id)
    get_todos(id).reject { |task| task[:completed] }
  end
  
  def incomplete_tasks_string(id)
    "#{incomplete_tasks(id).size}/#{list_size(id)}"
  end

  def list_size(id)
    get_todos(id).size
  end
  
  def sort_todos(todos, &block)  # Sort Todos on a list by "completed"
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_completed?(list[:id]) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end
  # def sort_lists(list)  # My slightly longer implementation, for sorting all lists
  #   completed = 
  #   {  false: [],
  #       true: []
  #   }
  #   list.each_with_index do |list, idx|
  #     list_completed?(list[:id]) ? completed[:true].push(idx) : completed[:false].push(idx) 
  #   end

  #   completed.each do |_, arr|
  #     list.each_with_index do |list, idx|
  #       yield(list, idx) if arr.include?(idx)
  #     end
  #   end
  # end

  def error_for_list_name(name)  # Return an error message if the name is invalid, otherwise return nil.
    if !(1..100).cover? name.size   
      "The list name must be between 1 and 100 characters"
    elsif session[:lists].any? {|list| list[:name] == name }
      "The list name must be unique."
    end
  end


  def error_for_todo(text)  # Return an error message if the Todo is invalid, otherwise return nil.
    if !(1..100).cover? text.size   
      "The task must be between 1 and 100 characters"
    end
  end
end

before do
  session[:lists] ||= []
end

not_found do
  session[:error] = "The requested page was not found."
  redirect "/lists"
end

get "/" do
  redirect "/lists"
end

get "/lists" do  # View list of lists
  @lists = session[:lists]
  erb :lists, layout: :layout
end

get "/lists/new" do  # Render the new list form
  erb :new_list, layout: :layout
end

post "/lists" do  # Create a new list
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { id: get_next_id(:lists), name: list_name, todos: []}
    session[:success] = "The list has been created."  
    redirect '/lists'     
  end
end

get "/lists/:id" do  # View a Todo list 
  @list_id = params[:id].to_i
  @list = get_list(@list_id)
  erb :list, layout: :layout
end

get "/lists/:id/edit" do  # Edit an existing Todo List
  id = params[:id].to_i
  @list = get_list(id)
  erb :edit_list, layout: :layout
end

post "/lists/:id/delete" do # Delete existing Todo List
  id = params[:id].to_i
  session[:lists].reject!{ |list| list[:id] == id }
  if env['HTTP_X_REQUESTED_WITH'] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end


post "/lists/:id" do  # Update an existing TDL
  id = params[:id].to_i
  @list = get_list(id)
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been renamed."  
    redirect "/lists/#{id}"    
  end
end

post "/lists/:id/complete_all" do  # Complete all tasks on a list
  id = params[:id].to_i
  @list = get_list(id)

  @list[:todos].each do |task|
    task[:completed] = true
  end

  session[:success] = 'List marked as complete.'
  redirect "/lists/#{id}"
end

post "/lists/:id/todos" do  # Add a Todo to an existing TDL
  @list_id = params[:id].to_i
  @list = get_list(@list_id)
  todo_text = params[:todo].strip

  error = error_for_todo(todo_text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { id: get_next_id(@list), name: todo_text, completed: false }
    session[:success] = "The task has been added."  
    redirect "/lists/#{@list_id}"    
  end
end

post "/lists/:list_id/todos/:task_id" do |list_id, task_id|  # Mark an existing Todo as completed
  @list_id = list_id.to_i
  @list = get_list(@list_id)

  task = @list[:todos].find { |task| task[:id] == task_id.to_i }
  is_completed = (params[:completed] == 'true')
  task[:completed] = is_completed

  session[:success] = 'The task has been updated'
  redirect "/lists/#{list_id}"
end

post "/lists/:list_id/todos/:task_id/delete" do |list_id, task_id| # Delete existing Todo
  @list_id = list_id.to_i
  @list = get_list(@list_id)

  @list[:todos].delete_if{ |task| task[:id] == task_id.to_i }
  if env['HTTP_X_REQUESTED_WITH'] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The task has been deleted."
    redirect "/lists/#{list_id}"
  end
end