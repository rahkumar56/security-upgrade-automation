#!/bin/bash
get_latest_go_version() {
    latest_version=$(curl -sL https://golang.org/VERSION?m=text)
    echo "$latest_version"
}

extract_version() {
    # Extract the first line
    first_line=$(echo "$1" | head -n 1)

    # Remove the "go" prefix to get the version
    version=$(echo "$first_line" | sed 's/go//')

    # Drop the last value from the version using cut
    version=$(echo "$version" | cut -d. -f1,2)

    # Return the extracted version
    echo "$version"
}

update_version() {
    local filename="$1"

    if [ "$filename" = ".drone.yml" ]; then
        echo '************************Before change start************************'
        cat "$filename"
        echo '************************Before change end************************'

        # Search for the existing Go version and replace it with the new version
        go_version=$(grep -E "image: golang:*" "$filename" | head -n 1 | awk -F ':' '{print $3}')
        echo 'existing file go_version: '$go_version

        # Replace the existing Go version with the new version
        sed -i "s/golang:${go_version}/golang:${new_go_version}/g" "$filename"

        # Commit the changes
        echo '************************After change start************************'
        cat "$filename"
        echo '************************After change end************************'
     elif [ "$filename" = "go.mod" ]; then
        # Your additional condition for ".anotherfile"
        echo '************************Before change start************************'
        cat "$filename"
        echo '************************Before change end************************'

        # Search for the existing Go version and replace it with the new version
        go_version=$(grep -E "^go [0-9]+\.[0-9]+" "$filename" | awk '{print $2}')
        echo 'existing file go_version: '$go_version

        # Replace the existing Go version with the new version
        sed -i "s/go ${go_version}/go ${new_go_version}/g" "$filename"

        # Commit the changes
        echo '************************After change start************************'
        cat "$filename"
        echo '************************After change end************************'
        # Add your logic for ".anotherfile" here
    else
        echo "Not a valid file. Skipping modification."
    fi
}

get_repo_info() {
    local repo_url="$1"
    # Remove '.git' from the end of the URL
    repo_url="${repo_url%.git}"
    echo 'repo_url : $repo_url'
    # Split the URL by "/"
      IFS="/" read -ra url_parts <<< "$repo_url"
    # Get the length of the array
    length=${#url_parts[@]}
    # Extract repository name and owner
    repo_name="${url_parts[length-1]}"
    repo_owner="${url_parts[length-2]}"
    # Print repo info
    echo "Repository Name: $repo_name"
    echo "Repository Owner: $repo_owner"
}

#repositories=(<+pipeline.variables.repoUrl>)
repositories=("https://github.com/drone-plugins/drone-gcs.git")
latest_version=$(get_latest_go_version)
echo "Latest version value in checkfornew verson:$latest_version"
new_go_version=$(extract_version "$latest_version")
echo 'Latest new_go_version:'$new_go_version
new_go_version='1.20'
echo 'Latest new_go_version:'$new_go_version


# Ensure that git and hub are installed
command -v git >/dev/null 2>&1 || { echo >&2 "Git is required but not installed. Aborting."; exit 1; }
command -v hub >/dev/null 2>&1 || { echo >&2 "Hub is required but not installed. Aborting."; exit 1; }
hub version

# Loop through the repositories
for repo in "${repositories[@]}"; do
    # Clone the repository
    repo_name=$(basename "$repo" .git)
    echo 'Repo : '$repo
    git clone "$repo"
    cd "$repo_name" || exit
    pwd
    ls -la
    base_ranch=$(git rev-parse --abbrev-ref HEAD)
    # Print the branch name
    echo "Current Git branch: $base_ranch"
    git checkout -b <+pipeline.variables.FeatureBranch>
    git fetch origin
    git pull origin
    #Update go version in files
    update_version ".drone.yml"
    update_version "go.mod"

    #Get Repo info
    get_repo_info "https://github.com/drone-plugins/drone-gcs.git"
    echo "***************in call Repository Name: $repo_name"
    echo "**************in call Repository Owner: $repo_owner"
    
    git config --global user.email "rahul.kumar@harness.io"
    git config --global user.name "rahkumar56"
    git remote set-url origin https://rahkumar56:<+pipeline.variables.PAT_Token>@github.com/drone-plugins/drone-gcs.git
    # Push the changes to a new branch   
    git add .
    git commit -m "Update Go version to $new_go_version"
    git push origin <+pipeline.variables.FeatureBranch>

    # Create a pull request
    # NOTE: You'll need to integrate with a platform-specific API or use a tool like Hub for GitHub.
    # Example for GitHub using Hub:
    #hub pull-request -m "Update Go version to $new_go_version"
    echo 'commit and push is success'
    curl --location 'https://api.github.com/repos/$repo_owner/$repo_name/pulls' \
    --header 'Accept: application/vnd.github+json' \
    --header 'Authorization: Bearer <+pipeline.variables.PAT_Token>' \
    --header 'Content-Type: application/json' \
    --data '{
        "title": "Updated go version",
        "body": "Please pull these awesome changes in!",
        "head": "$repo_owner:<+pipeline.variables.FeatureBranch>",
        "base": "$base_ranch"
    }'

        cd ..
    done
