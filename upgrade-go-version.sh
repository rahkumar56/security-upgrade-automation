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
       # cat "$filename"
        echo '************************Before change end************************'

        # Search for the existing Go version and replace it with the new version
        go_version=$(grep -E "image: golang:*" "$filename" | head -n 1 | awk -F ':' '{print $3}')
        echo 'existing file go_version: '$go_version

        # Replace the existing Go version with the new version
        sed -i "s/golang:${go_version}/golang:${new_go_version}/g" "$filename"

        # Commit the changes
        echo '************************After change start************************'
        #cat "$filename"
        echo '************************After change end************************'
     elif [ "$filename" = "go.mod" ]; then
        # Your additional condition for ".anotherfile"
        echo '************************Before change start************************'
        #cat "$filename"
        echo '************************Before change end************************'

        # Search for the existing Go version and replace it with the new version
        go_version=$(grep -E "^go [0-9]+\.[0-9]+" "$filename" | awk '{print $2}')
        echo 'existing file go_version: '$go_version

        # Replace the existing Go version with the new version
        sed -i "s/go ${go_version}/go ${new_go_version}/g" "$filename"

        # Commit the changes
        echo '************************After change start************************'
       # cat "$filename"
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

    # Split the URL by "/"
    IFS="/" read -ra url_parts <<< "$repo_url"

    # Get the length of the array
    length=${#url_parts[@]}

    # Extract repository name and owner
    export repo_name="${url_parts[length-1]}"
    export repo_owner="${url_parts[length-2]}"

    echo "Repository Name: $repo_name"
    echo "Repository Owner: $repo_owner"
}

clone_repo(){
    local repo="$1"
    local feature_branch="$2"
    # Clone the repository
     echo "***************clone repo repo: $repo \n\n"
    repo_name=$(basename "$repo" .git)
    echo 'Repo : '$repo

     get_repo_info $repo
    echo "***************in call Repository Name: $repo_name"
    echo "**************in call Repository Owner: $repo_owner"
    
    git config --global user.email "rahul.kumar@harness.io"
    git config --global user.name "rahkumar56"
    git remote set-url origin https://rahkumar56:$pat_token@github.com/$repo_owner/$repo_name
    pwd

   # git clone "$repo"
    git clone "https://rahkumar56:${pat_token}@github.com/${repo_owner}/${repo_name}.git"
    cd "$repo_name" || exit
    #Git Config
     git config --global user.email "rahul.kumar@harness.io"
     git config --global user.name "rahkumar56"
     git remote set-url origin https://rahkumar56:$pat_token@github.com/$repo_owner/$repo_name
    pwd
    ls -la
    export base_ranch=$(git rev-parse --abbrev-ref HEAD)
    # Print the branch name
    echo "Current Git branch: $base_ranch"
    git checkout -b $feature_branch
    git push origin $feature_branch
    git fetch origin
    git pull origin
}

commit_generate_pr(){
    echo $pat_token
    echo $pat_token |base64
    # Push the changes to a new branch  
    git status 
    git add .
    git status
    git commit -m "Updated ci-manager-config.yml with latest plugin versions"
    git push origin $feature_branch
    
    # Create a pull request
    # NOTE: You'll need to integrate with a platform-specific API or use a tool like Hub for GitHub.
    # Example for GitHub using Hub:
    #hub pull-request -m "Update Go version to $new_go_version"
    echo 'commit and push is success'
    #Generate PR 
    echo 'Going to hit generate PR curl in side sh file.'
    get_repo_info $repo
    echo "***************in call Repository Name: $repo_name"
    echo "**************in call Repository Owner: $repo_owner"
    echo $repo_name
    echo $repo_owner
    echo $pat_token |base64
    echo $pat_token 
    echo $feature_branch
    echo $base_ranch
    url='https://api.github.com/repos/'$repo_owner'/'$repo_name'/pulls'
    echo $url
    body='{ "title":"Updated ci-manager-config.yml with latest plugin versions", "body":"Updated ci-manager-config.yml with latest plugin versions.", "head":"'$repo_owner':'$feature_branch'", "base":"'$base_ranch'" }'
    echo $body
    echo $pat_token
    # curl --verbose --location "$url" \
    # --header 'Accept: application/vnd.github+json' \
    # --header "Authorization: Bearer $pat_token" \
    # --header 'Content-Type: application/json' \
    # --data "$body"
    curl_response=$(curl --location "$url" \
    --header 'Accept: application/vnd.github+json' \
    --header "Authorization: Bearer $pat_token" \
    --header 'Content-Type: application/json' \
    --data "$body")
    # Parse the latest version from the response using jq
    pr_url=$(echo "$curl_response" | jq -r '.url')
    echo 'pr_url::'$pr_url
    echo 'curl_response :: '$curl_response
    echo 'slack_webhook url::'$slack_webhook
    response=$(curl --location --silent --output - "$slack_webhook" \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode "payload={\"channel\": \"security_automation\", \"username\": \"Security-Automation\", \"type\": \"mrkdwn\", \"text\": \"*Security Automation: PR is generated for plugins repos:* :white_check_mark: $pr_url\", \"icon_emoji\": \":harnesshd:\"}")
    echo "Response: $response"
    #echo "***************Ended Execution for the repo: $repo_name \n\n PR url: $pr_url"
    echo $pr_url
}

#repositories=(<+pipeline.variables.repoUrl>)
echo 'Inside pipeline file'
echo 'feature_branch: ' $feature_branch
echo 'inp_repositories : ' $inp_repositories
echo 'pat_token: ' $pat_token
#input repo urls
IFS=',' read -ra repositories <<< "$inp_repositories"
echo "repositories elements: ${repositories[@]}"
echo 'repositories :'$repositories
#repositories=("https://github.com/drone-plugins/drone-gcs.git")
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
     echo "***************Started Execution for the repo: $repo_name \n\n"
    repo_name=$(basename "$repo" .git)
    echo 'Repo : '$repo
    clone_repo $repo $feature_branch
    # git clone "$repo"
    # cd "$repo_name" || exit
    #  #Get Repo info
    # get_repo_info $repo
    # echo "***************in call Repository Name: $repo_name"
    # echo "**************in call Repository Owner: $repo_owner"
    
    # git config --global user.email "rahul.kumar@harness.io"
    # git config --global user.name "rahkumar56"
    # git remote set-url origin https://rahkumar56:$pat_token@github.com/$repo_owner/$repo_name
    # pwd
    # ls -la
    # export base_ranch=$(git rev-parse --abbrev-ref HEAD)
    # # Print the branch name
    # echo "Current Git branch: $base_ranch"
    # git checkout -b $feature_branch
    # git push origin $feature_branch
    # git fetch origin
    # git pull origin
    #Update go version in files
    update_version ".drone.yml"
    update_version "go.mod"

    echo $pat_token
    echo $pat_token |base64
    
    # Push the changes to a new branch   
    # git add .
    # git commit -m "Update Go version to $new_go_version"
    # git push origin $feature_branch
    
    # # Create a pull request
    # # NOTE: You'll need to integrate with a platform-specific API or use a tool like Hub for GitHub.
    # # Example for GitHub using Hub:
    # #hub pull-request -m "Update Go version to $new_go_version"
    # echo 'commit and push is success'
    # #Generate PR 
    # echo 'Going to hit generate PR curl in side sh file.'
    # echo $repo_owner
    # echo $repo_name
    # echo $pat_token |base64
    # echo $pat_token 
    # echo $feature_branch
    # echo $base_ranch
    # url='https://api.github.com/repos/'$repo_owner'/'$repo_name'/pulls'
    # echo $url
    # body='{ "title":"Updated go version", "body":"Please pull these awesome changes in!", "head":"'$repo_owner':'$feature_branch'", "base":"'$base_ranch'" }'
    # echo $body
    # echo $pat_token
    # curl --verbose --location "$url" \
    # --header 'Accept: application/vnd.github+json' \
    # --header "Authorization: Bearer $pat_token" \
    # --header 'Content-Type: application/json' \
    # --data "$body"
    commit_generate_pr
    echo $pat_token
    echo $pat_token |base64
    echo "***************Ended Execution for the repo: $repo_name \n\n"
        cd ..
    done
