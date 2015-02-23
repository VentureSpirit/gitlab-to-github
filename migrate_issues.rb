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

# gitlab username, payload must include +title+ and +body+, and can optionally include +milestone+ and +labels+
def create_issue(username, payload)
  github_client(username).issues.with(user: CONFIG["github"]["project_user"], repo: CONFIG["github"]["project_repo"]).create(payload)
end

def update_issue(username, issue_number, payload)
  github_client(username).issues.with(user: CONFIG["github"]["project_user"], repo: CONFIG["github"]["project_repo"],  number: issue_number).edit(payload)
end

def create_comment(username, issue_number, payload)
  github_client(username).issues.comments.with(user: CONFIG["github"]["project_user"], repo: CONFIG["github"]["project_repo"],  number: issue_number).create(payload)
end

def create_label(username, payload)
  github_client(username).issues.labels.with(user: "venturespirit", repo: CONFIG['github']['project_repo']).create(payload)
end

# For debugging
# require 'pry'
# binding.pry

issues = []
comments = {}
uploads = []
users = []
labels = []

# Get all the labels and create the labels on github
# duplicate label names will return error code 422
labels = Gitlab.labels(CONFIG["gitlab"]["project_id"])
labels.each do |label|
  colorlabel = label.color.delete! '#'
  username = CONFIG["github"]["label_creator"]
  create_label(username, {color: colorlabel, name: label.name})
end
puts "Got #{labels.count} labels"

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

uploads.each { |u| p u }

p "create the issues"
# create all the issues on github
issues.each do |issue|
  payload = {
    title: issue.title,
    body: issue.description,
    labels: issue.labels
  }

  if issue.milestone
    payload['milestone'] = CONFIG['milestone_mapping'][issue.milestone.title]
  end

  if issue.assignee
    payload['assignee'] = CONFIG['gitlab_user_to_github_user_mapping'][issue.assignee.username]
  end

  githubissue = create_issue(issue.author.username, payload)
  if issue.state === "closed"
    puts "update the issue's state to closed"
    update_issue(issue.author.username, githubissue.body.number, {state: "closed"})
  end

  comments[issue.id].each do |comment|
    puts "adding comments to issue"
    create_comment(comment.author.username, githubissue.body.number, {body: comment.body})
  end

end
