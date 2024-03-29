import re
import shutil
import git
from git import Repo
import os
from urllib.parse import urlparse
from github import Github
import requests

#create branch
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
    reponame=create_repo_folder(repo_url)
    Repo.clone_from(repo_url, reponame)

# Function to read the existing SCM version from delegate-service-config.yml
def read_go_version(directory):
    with open(os.path.join(directory, "go.mod"), "r") as file:
        lines = file.readlines()

    for line in lines:
        if line.startswith("go "):
            existing_scm_version = line.split(" ")[1].strip()
            return existing_scm_version

    return None

def extract_version_from_line(line):
    match_general = re.search(r'go(\d+\.\d+(\.\d+)?)', line)
    if match_general:
        return match_general.group(1)

    match_droneYml1 = re.search(r'golang:(\d+\.\d+(\.\d+)?)', line)
    if match_droneYml1:
        return match_droneYml1.group(1)

    match_specific_line = re.search(r'go1:(\d+\.\d+(\.\d+)?)', line)
    if match_specific_line:
        return match_specific_line.group(1)

    # Try to match the specific version pattern (e.g., go 1.21)
    match_specific = re.search(r'go (\d+\.\d+)', line)
    if match_specific:
        return match_specific.group(1)

    match_docker = re.search(r'go1:(\d+\.\d+)', line)
    if match_docker:
        return match_docker.group(1)

    match_droneYml = re.search(r'golang:(\d+\.\d+)', line)
    if match_droneYml:
        return match_droneYml.group(1)



    return None


def extract_version_from_file(file_path):
    matched_versions = []
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
            content = file.readlines()

            for line in content:
                version = extract_version_from_line(line)
                if version:
                    matched_versions.append(version)

            print(f"Version not found in {file_path}")
            return matched_versions
    except UnicodeDecodeError:
        # Handle non-UTF-8 encoded characters if necessary
        print(f"UnicodeDecodeError: Skipping file {file_path} due to non-UTF-8 encoded characters.")
        return None
    except FileNotFoundError:
        print(f"File not found: {file_path}")
        return None

def update_go_version(repo_path ,new_scm_version):
    # Read existing SCM version
    exclude_folders = ['.git', '.github', '.idea', '.harness', '.aeriform']
    #existing_scm_version = read_scm_version(repo_path)
    existing_scm_version = "1.21"

    if existing_scm_version:

        if compare_versions(existing_scm_version, new_scm_version) > 0:
            print(
                f"New version {new_scm_version} is lower than existing version {existing_scm_version}. Keeping the existing version.")
            return
        # Search and replace SCM version in all files
        # search_and_replace(repo_path, existing_scm_version, new_scm_version)

        # Update SCM version in all files
        for subdir, _, files in os.walk(repo_path):
            for file in files:
                file_path = os.path.join(subdir, file)

                # Skip excluded files
                if any(exclude_folder in file_path for exclude_folder in exclude_folders):
                    continue

                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                except UnicodeDecodeError:
                    # Handle non-UTF-8 encoded characters if necessary
                    print(f"UnicodeDecodeError: Skipping file {file_path} due to non-UTF-8 encoded characters.")
                    continue
                #version1 = []
                version1 = extract_version_from_file(file_path)
                print(f"all the version list fetched from file:")
                print(version1)
                if len(version1) <=0:
                    continue
                for existing_scm_version in version1:
                    print(f"Version extracted from {file_path}: {existing_scm_version}")

                    if existing_scm_version is None:
                        continue

                    if '.' not in existing_scm_version:
                        # Update the version up to the major version only
                        existing_major_version = existing_scm_version.split('.')[0]
                        new_major_version = new_scm_version.split('.')[0]
                        content = content.replace(existing_major_version, new_major_version)
                    else:
                        # Update the version up to the minor version if it exists in the existing version
                        existing_major_version, existing_minor_version = existing_scm_version.split('.')[:2]
                        new_major_version, new_mid_version, new_minor_version = new_scm_version.split('.')[:3]

                        if not new_minor_version:  # If the new version has no minor version
                            content = content.replace(f"{existing_major_version}.{existing_minor_version}",
                                                      new_major_version)
                        else:
                            if len(existing_scm_version) > 4:
                                content = content.replace(existing_scm_version, new_scm_version)
                            else:
                                content = content.replace(existing_scm_version,
                                                          f"{new_major_version}.{new_mid_version}")

                    try:
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.write(content)
                    except UnicodeEncodeError:
                        # Handle non-UTF-8 encoded characters if necessary
                        print(f"UnicodeEncodeError: Unable to write changes to file {file_path}.")

def compare_versions(version1, version2):
    pattern = re.compile(r'(\d+)(?:\.(\d+))?(?:\.(\d+))?')
    matches1 = re.match(pattern, version1)
    matches2 = re.match(pattern, version2)

    if matches1 and matches2:
        components1 = list(map(lambda x: int(x) if x else 0, matches1.groups()))
        components2 = list(map(lambda x: int(x) if x else 0, matches2.groups()))

        for comp1, comp2 in zip(components1, components2):
            if comp1 < comp2:
                return -1
            elif comp1 > comp2:
                return 1

    return 0


def create_pull_request(repo_path, feature_branch, base_branch, title, body):
    repo = Repo(repo_path)
    origin = repo.remote('origin')

    # Create a new branch
    # repo.git.checkout(base_branch)
    # repo.git.pull()
    # repo.git.checkout('-b', feature_branch)

    # Add and commit changes
    repo.git.add(A=True)
    repo.git.commit('-m', 'Update keyword')

    # Push changes to the new branch
    repo.git.push(origin, feature_branch)

    # Create a pull request using GitHub API
    g = Github(pat_token)  # Replace with your GitHub personal access token
    repo_name = repo.remote().url.split('/')[-1].split('.')[0]
    repo_owmner = repo.remote().url.split('/')[-2]
    feature_branch = repo_owmner + ":" + feature_branch
    print("repo_name::"+repo_name+"\nrepo_owmner::"+repo_owmner+"\nfeature_branch::"+feature_branch+"\nbase_branch::"+base_branch)
    github_repo = g.get_repo(repo_owmner+"/"+repo_name)
    pull_request = github_repo.create_pull(title=title, body=body, head=feature_branch, base=base_branch)
    return pull_request

def send_slack_notification(webhook_url, pr_url):
    payload = {
    "channel": "security_automation",
    "username": "Security-Automation",
    "type": "mrkdwn",
    "text": f"*Security Automation: GO Version is upgraded and PR is generated::* {pr_url}   -  :white_check_mark:",
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

def get_latest_go_version():
    url = "https://golang.org/VERSION?m=text"
    response = requests.get(url)
    if response.status_code == 200:
        version_info = response.text.strip()
        latest_version = re.search(r"go(\d+\.\d+\.\d+)", version_info)
        if latest_version:
            return latest_version.group(1)
    return None


pr_title = "Update go Version in all files"
pr_body = "This pull request updates the go version in all files."
#module = ''
#repo_url = 'https://github.com/drone-plugins/drone-docker.git,https://github.com/drone-plugins/drone-meltwater-cache.git'

#feature_branch = "test_rah22"
base_branch = None
repo_name = None
repo_folder = None


# Example usage
if __name__ == "__main__":
    # Split the repo_url by comma to get individual repository URLs
    latest_go_version = get_latest_go_version()
    print(f"Latest go version::{latest_go_version}")
    latest_go_version = "1.22.1"
    repo_url = os.getenv("repo_url")
    print(f"repo_url:: {repo_url}")
    feature_branch = os.getenv("feature_branch")
    print(f"feature_branch::{feature_branch}")
    slack_webhook = os.getenv("slack_webhook")
    print(f"slack_webhook::{slack_webhook}")
    modules = os.getenv("cimodules")
    print(f"modules::{modules}")
    pat_token = os.getenv("pat_token")
    print(f"pat_token::{pat_token}")
    module_list = modules.split(',')
    repo_urls = repo_url.split(',')
    for url in repo_urls:
        # Clone the repository
        clone_repository(url)

        # print repo name and owner after clone
        print(f"Repo_name new value after clone:{repo_name}")
        print(f"repo_folder new value after clone:{repo_folder}")

        # Checkout to new feature branch
        create_branch(repo_folder, feature_branch)
        # print current base branch for the repo
        print(f"base_branch new value after checkout to feature branch:{base_branch} for the repo {repo_name}")

        if repo_name == 'harness-core':
            for module in module_list:
                print(f"module::{module}")
                repo_path = os.path.join(repo_name, module)
                print(f"repo_path : : {repo_path}")
                update_go_version(repo_path, latest_go_version)
        else:
            # Update SCM version in delegate-service-config.yml and all files
            update_go_version(repo_name, latest_go_version)

        # Create a pull request
        pr = create_pull_request(repo_folder, feature_branch, base_branch, pr_title, pr_body)
        print(f"Pull request created: {pr.html_url}")
        # Send slack notification
        send_slack_notification(slack_webhook, pr.html_url)
