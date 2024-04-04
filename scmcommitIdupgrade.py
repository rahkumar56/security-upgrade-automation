import re
import git
from git import Repo
import os
from urllib.parse import urlparse
from github import Github
import requests
import subprocess


# Function to clone a repository
def create_repo_folder(github_url):
    # Parse the GitHub URL to extract the repository name
    parsed_url = urlparse(github_url)
    global repo_name
    repo_name = os.path.splitext(os.path.basename(parsed_url.path))[0]

    # Create a folder with the repository name
    global repo_folder
    repo_folder = os.path.join(os.getcwd(), repo_name)

    if not os.path.exists(repo_folder):
        os.makedirs(repo_folder)
        print(f"Folder '{repo_folder}' created successfully.")
    else:
        print(f"Folder '{repo_folder}' already exists.")

    return repo_name


def create_branch(repo_path, feature_branch):
    try:
        repo = git.Repo(repo_path)

        # Get the current branch
        global base_branch
        base_branch = repo.active_branch.name

        # Pull changes from the current branch
        repo.git.pull('origin', base_branch)

        # Create a new branch from the current branch
        new_branch = repo.create_head(feature_branch)
        new_branch.checkout()

        print(f"New branch '{feature_branch}' created successfully.")

    except git.GitCommandError as e:
        print(f"Error creating branch: {e}")


# Function to clone a repository
def clone_repository(repo_url):
    reponame = create_repo_folder(repo_url)
    # subprocess.run(["git", "config", "--global", "user.email", "rahul.kumar@harness.io"])
    # subprocess.run(["git", "config", "--global", "user.name", "rahkumar56"])
    # Repo.git.remote("set-url", "origin", remote_url)
    repo_name = repo_url.split('/')[-1].split('.')[0]
    global repo_owner
    repo_owner = repo_url.split('/')[-2]
    remote_url = f"https://rahkumar56:{pat_token}@github.com/{repo_owner}/{repo_name}.git"
    print(f"Remote repo url::{remote_url}")
    # subprocess.run(["git", "remote", "set-url", "origin", remote_url])
    Repo.clone_from(remote_url, reponame)


# def clone_repository(repo_url, destination_path):
#     Repo.clone_from(repo_url, destination_path)

# Function to read the existing SCM version from delegate-service-config.yml
def read_scm_version(directory):
    with open(os.path.join(directory, "270-delegate-service-app/delegate-service-config.yml"), "r") as file:
        lines = file.readlines()

    for line in lines:
        if line.startswith("scmVersion:"):
            existing_scm_version = line.split(":")[1].strip()
            return existing_scm_version

    return None


# Function to search and replace keyword in all files
# def search_and_replace(directory, keyword, new_value, exclude_folders=None):
#     if exclude_folders is None:
#         exclude_folders = ['.git','.github', '.idea', '.harness', '.aeriform']
#
#     for subdir, _, files in os.walk(directory):
#         # Skip excluded folders
#         if any(exclude_folder in subdir for exclude_folder in exclude_folders):
#             continue
#
#         for file in files:
#             file_path = os.path.join(subdir, file)
#
#             # Skip excluded files
#             if any(exclude_folder in file_path for exclude_folder in exclude_folders):
#                 continue
#
#             try:
#                 with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
#                     content = f.read()
#             except UnicodeDecodeError:
#                 # Handle non-UTF-8 encoded characters if necessary
#                 print(f"UnicodeDecodeError: Skipping file {file_path} due to non-UTF-8 encoded characters.")
#                 continue
#
#             content = content.replace(keyword, new_value)
#
#             try:
#                 with open(file_path, 'w', encoding='utf-8') as f:
#                     f.write(content)
#             except UnicodeEncodeError:
#                 # Handle non-UTF-8 encoded characters if necessary
#                 print(f"UnicodeEncodeError: Unable to write changes to file {file_path}.")
#


# Function to update SCM version in delegate-service-config.yml and all files
# def update_scm_version(repo_path, new_scm_version):
#     # exclude these dir and files
#     exclude_folders = ['.git', '.github', '.idea', '.harness', '.aeriform']
#     # Read existing SCM version
#     global existing_scm_commitid
#     existing_scm_commitid = read_scm_version(repo_path)
#
#     if existing_scm_commitid:
#         # Search and replace SCM version in all files
#         # search_and_replace(repo_path, existing_scm_version, new_scm_version)
#
#         # Update SCM version in all files
#         for subdir, _, files in os.walk(repo_path):
#             for file in files:
#                 file_path = os.path.join(subdir, file)
#
#                 # Skip excluded files
#                 if any(exclude_folder in file_path for exclude_folder in exclude_folders):
#                     continue
#
#                 try:
#                     with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
#                         content = f.read()
#                 except UnicodeDecodeError:
#                     # Handle non-UTF-8 encoded characters if necessary
#                     print(f"UnicodeDecodeError: Skipping file {file_path} due to non-UTF-8 encoded characters.")
#                     continue
#
#                 content = content.replace(f"{existing_scm_commitid}", f"{new_scm_commitid}")
#
#                 try:
#                     with open(file_path, 'w', encoding='utf-8') as f:
#                         f.write(content)
#                 except UnicodeEncodeError:
#                     # Handle non-UTF-8 encoded characters if necessary
#                     print(f"UnicodeEncodeError: Unable to write changes to file {file_path}.")
#

def update_scm_version(repo_path, new_scm_version):
    # exclude these dir and files
    exclude_folders = ['.git', '.github', '.idea', '.harness', '.aeriform', '.md', '.java.pb.meta']
    include_files = ['.sh', '.yml', '.java', 'Docker']

    global existing_scm_commitid
    existing_scm_commitid = read_scm_version(repo_path)

    if existing_scm_commitid:
        for subdir, _, files in os.walk(repo_path):
            for file in files:
                file_path = os.path.join(subdir, file)

                # Skip excluded files and folders
                if any(exclude_folder in file_path for exclude_folder in exclude_folders):
                    continue

                # Check if the filename contains any element of include_files
                if any(include_file in file for include_file in include_files):
                    print(f'Updated filepath::{file_path}')
                    try:
                        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                            content = f.read()
                    except UnicodeDecodeError:
                        print(f"UnicodeDecodeError: Skipping file {file_path} due to non-UTF-8 encoded characters.")
                        continue

                    content = content.replace(f"{existing_scm_commitid}", f"{new_scm_commitid}")

                    try:
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.write(content)
                    except UnicodeEncodeError:
                        print(f"UnicodeEncodeError: Unable to write changes to file {file_path}.")


def create_pull_request(repo_path, feature_branch, base_branch, title, body):
    slack_msg = ""
    repo = Repo(repo_path)
    origin = repo.remote('origin')
    g = Github(pat_token)  # Replace with your GitHub personal access token
    repo_name = repo.remote().url.split('/')[-1].split('.')[0]
    repo_owner = repo.remote().url.split('/')[-2]
    print(f"repo_name::{repo_name}\n repo_owner::{repo_owner}")

    subprocess.run(["git", "config", "--global", "user.email", "rahul.kumar@harness.io"])
    subprocess.run(["git", "config", "--global", "user.name", "rahkumar56"])
    remote_url = f"https://rahkumar56:{pat_token}@github.com/{repo_owner}/{repo_name}.git"
    print(f"Remote repo url::{remote_url}")
    subprocess.run(["git", "remote", "set-url", "origin", remote_url])
    repo.git.remote("set-url", "origin", remote_url)
    if not repo.is_dirty():
        slack_msg = f"No Changes to commit, new_scm_commitid:: {new_scm_commitid} is equal to existing_scm_commitid ::{existing_scm_commitid}  "
        return slack_msg
    # Add and commit changes
    repo.git.add(A=True)
    repo.git.commit('-m', 'Update GO Version to latest version in all the files')
    # Push changes to the new branch
    repo.git.push(origin, feature_branch)
    feature_branch = repo_owner + ":" + feature_branch
    print(
        f"repo_name::{repo_name}\n repo_owner::{repo_owner}\nfeature_branch::{feature_branch}\nbase_branch::{base_branch}")
    github_repo = g.get_repo(repo_owner + "/" + repo_name)
    pull_request = github_repo.create_pull(title=title, body=body, head=feature_branch, base=base_branch)
    slack_msg = f"SCM Commit Id is updated ::* {pull_request.html_url} "
    return slack_msg


def send_slack_notification(webhook_url, message):
    payload = {
        "channel": "ci-release-validation",
        "username": "ci-release-validation",
        "type": "mrkdwn",
        "text": f"*Security Automation: {message}  -  :white_check_mark:",
        "icon_emoji": ":harnesshd:"
    }
    # payload = {
    #     "text": message
    # }
    response = requests.post(webhook_url, json=payload)
    if response.status_code == 200:
        print(f"Notification sent successfully::{response}")
    else:
        print(f"Failed to send notification. Status code: {response.status_code} and response: {response}")


base_branch = None
repo_name = None
repo_folder = None
pr_title = "Update SCM commit id in all files"
pr_body = "This pull request updates the scm commit id in all files."

existing_scm_commitid = None
new_scm_commitid = None
# Example usage
if __name__ == "__main__":
    # Replace these values with your specific information
    new_scm_commitid =  repo_url = os.getenv("new_scm_commitid")
    repo_url = os.getenv("repo_url")
    print(f"repo_url:: {repo_url}")
    feature_branch = os.getenv("feature_branch")
    print(f"feature_branch::{feature_branch}")
    slack_webhook = os.getenv("slack_webhook")
    print(f"slack_webhook::{slack_webhook}")
    new_scm_commitid = os.getenv("new_scm_commitid")
    print(f"newSCMCommitId::{new_scm_commitid}")
    pat_token = os.getenv("pat_token")
    print(f"pat_token::{pat_token}")

   

# destination_path = "/Users/rahulkumar/PycharmProjects/SecurityUpgrades/repo_clone1"
# branch_name = "update_SCMVersion_branch"
# base_branch = "main"

# pr_title = "Update SCM Version in all files"
# pr_body = "This pull request updates the UpdateSCMVersion in all files."
# new_scm_version = "a07a4795"

# Clone the repository
clone_repository(repo_url)
print("clone repo is compeleted")
# create and  checkout to feature branch
create_branch(repo_folder, feature_branch)

# Update SCM version in delegate-service-config.yml and all files
update_scm_version(repo_folder, new_scm_commitid)

# Create a pull request
msg = create_pull_request(repo_folder, feature_branch, base_branch, pr_title, pr_body)
print(f"slack msg:: {msg}")
print(f"Pull request created: {msg.html_url}")
# Send slack notification
send_slack_notification(slack_webhook, msg)
