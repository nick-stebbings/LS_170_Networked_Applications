
    #// 1 When a user loads the home page, they should be redirected to a page that lists all of the users' names. Load the users from the users.yaml file (content below).
    #//2 Each of the users' names should be a link to a page for that user.
    #// 3 On each user's page, display their email address. Also display their interests, with a comma appearing between each interest.
    #4//  At the bottom of each user's page, list links to all of the other users pages. Do not include the user whose page it is in this list.
    #//5  Add a layout to the application. At the bottom of every page, display a message like this: "There are 3 users with a total of 9 interests."
    #// 6 Update the message printed out in #5 to determine the number of users and interests based on the content of the YAML file. Use a helper method, count_interests, to determine the total number of interests across all users.
    #//7 Add a new user to the users.yaml file. Verify that the site updates accordingly.

require "sinatra"
require "sinatra/reloader"
require 'yaml'

set :port, 4567
set :bind, '0.0.0.0'

before do
  @users = YAML.load_file('users.yaml')
end

helpers do
  def count_interests # this is long winded!
    interests = @users.values.reduce([]) do |total_interests, user_details|
      user_details.each do |key, interest|
        next unless (key == :interests)
        total_interests << interest
      end
      total_interests
    end
    [@users.keys.size, interests.flatten.uniq.size]
  end
end

get '/' do
  erb :home
end

get "/*" do |name|
  if (@users.keys.include?(name.to_sym))
    erb :user
  else
    redirect '/'
    nil
  end
end
