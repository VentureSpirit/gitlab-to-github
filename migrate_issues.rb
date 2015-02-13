require 'bundler'
Bundler.require

Gitlab.endpoint = ENV['ENDPOINT']
Gitlab.private_token = ENV['TOKEN']
PROJECT_ID = 47 # onegame

# gitlab_id => github_id
MILESTONE_MAPPING = {}

# gitlab_user_id => api_token
# You can get the api_token at https://github.com/settings/applications#personal-access-tokens
USER_MAPPING = {}

issues = []
comments = {}
uploads = []
users = []

# Get all the issues
page = 0
loop do
  extra_issues = Gitlab.issues(PROJECT_ID, per_page: 100, page: page)
  break if extra_issues.count <= 0
  page += 1
  issues += extra_issues
  puts "Total issues: #{issues.count}"
end

# Get all the comments (notes)
comments = {}
issues.each do |issue|
  comments[issue.id] = Gitlab.issue_notes(PROJECT_ID, issue.id)
end

puts "Got #{comments.values.flatten.count} comments in total"

# List all users:
users = issues.map { |issue| issue.author.username }
users += comments.values.flatten.map { |comment| comment.author.username }
users.uniq!
puts "Got #{users.count} users"

# TODO: Fetch all the uploads
