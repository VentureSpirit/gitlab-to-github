require 'bundler'
Bundler.require

# Load Configuration
CONFIG = YAML.load(File.read('config.yml'))
Gitlab.endpoint = CONFIG["gitlab"]["endpoint"]
Gitlab.private_token = CONFIG["gitlab"]["private_token"]

GITHUB_CLIENTS = CONFIG["user_mapping"].map do |username, token|
  [username, Github.new(oauth_token: token)]
end.to_h

def github_client(username)
  GITHUB_CLIENTS[username] || GITHUB_CLIENTS.first.last
end

# gitlab username, payload must include +title+ and +body+, and can optionally include +milestone+
def create_issue(username, payload)
  # TODO map milestones
  github_client(username).issues.with(user: CONFIG["github"]["project_user"], repo: CONFIG["github"]["project_repo"]).create(payload)
end

# TODO: def create_comment()

# For debugging
# require 'pry'
# binding.pry

issues = []
comments = {}
uploads = []
users = []

# Get all the issues
page = 0
loop do
  extra_issues = Gitlab.issues(CONFIG["gitlab"]["project_id"], per_page: 100, page: page)
  break if extra_issues.count <= 0
  page += 1
  issues += extra_issues
end
puts "Got #{issues.count} issues"

# Get all the comments (notes)
comments = {}
issues.each do |issue|
  comments[issue.id] = Gitlab.issue_notes(CONFIG["gitlab"]["project_id"], issue.id)
end
puts "Got #{comments.values.flatten.count} comments"

# List all users:
users = issues.map { |issue| issue.author.username }
users += comments.values.flatten.map { |comment| comment.author.username }
users.uniq!
puts "Got #{users.count} users"

p users

# Fetch all the uploads
upload_regex = /\((http[^(]*\/uploads\/[^)]*)\)/
issues.each do |issue|
  uploads += issue.description.scan(upload_regex)
end
comments.values.flatten.each do |comment|
  # attachment is just a string :-/
  # We'll have to do this one manually
  # uploads << comment.attachment if comment.attachment
end
puts "Got #{uploads.count} uploads"

# uploads.each { |u| p u }
