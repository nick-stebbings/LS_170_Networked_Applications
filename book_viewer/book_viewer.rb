require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

set :port, 4567
set :bind, '0.0.0.0'

before do
  @contents = File.readlines('data/toc.txt') 
  @search_results = []
end

helpers do
  def in_paragraphs(text)
    text.split("\n\n").map { |para| "<p>#{para}</p>" }.join
  end
end

def each_chapter
  @contents.each_with_index do |chap_name, idx|
    chapter_contents = File.read("data/chp#{idx + 1}.txt")
    yield(idx + 1, chap_name, chapter_contents)
  end
  @contents
end

def each_paragraph(chapter, markup = false)
  chapter = in_paragraphs(chapter) unless markup
  paragraphs = chapter.split(/(?<=<\/p>)/)[0..-2]
  paragraphs.each_with_index do |markup_text, idx|
    yield(idx + 1, markup_text)
  end
  chapter
end

def run_search!(match_criteria)
  each_chapter do |chap_num, name, contents|
    each_paragraph(contents) do |para_num, para_text|
      para_text.gsub!(match_criteria, "<strong>#{match_criteria}</strong>")
      @search_results << {:chap_num => chap_num,
                          :chap_name => name,
                          :para_num => para_num,
                          :para_text => para_text } if para_text.include? match_criteria
    end
  end
end

not_found do
  redirect "/"  
end

get "/" do
    # Directory Challenge:
    # @current_dir = Dir.glob('public/*.*')
    # sorted = params['sort_order']
    # @current_dir.reverse! if sorted == 'za'
    # erb :directory
  @title = 'The Adventures of Sherlock Holmes'
  erb :home
end

get "/chapters/:name" do
  number = params[:name]
  # redirect '/' unless (1..@contents.size).cover?(number)
  @title = "Chapter #{number}: #{@contents[number.to_i - 1]}"
  @chapter = File.read("data/chp#{number}.txt")
  erb :chapter
end

get "/search" do
  match_criteria = params['query']
  # match_criteria = %r{\b#{params['query']}\b}
  
  run_search!(match_criteria) if (params['query'] && params['query'] != '')
  erb :search
end


