for repo in "${repositories[@]}"; do
    # Clone the repository
    repo_name=$(basename "$repo" .git)
    echo 'Repo : '$repo
    git clone "$repo"
    cd "$repo_name" || exit
     #Get Repo info
    get_repo_info $repo
    echo "***************in call Repository Name: $repo_name"
    echo "**************in call Repository Owner: $repo_owner"
    
    git config --global user.email "shobhit.singh@harness.io"
    git config --global user.name "ShobhitSingj11"
    git remote set-url origin https://ShobhitSingh:$pat_token@github.com/$repo_owner/$repo_name
    # pwd
    # ls -la
    # base_ranch=$(git rev-parse --abbrev-ref HEAD)
    # Print the branch name
    # echo "Current Git branch: $base_ranch"
    # git checkout -b $feature_branch
    # git push origin $feature_branch
    # git fetch origin
    # git pull origin
    # #Update go version in files
    # update_version ".drone.yml"
    # update_version "go.mod"

    echo $pat_token
    echo $pat_token |base64
    
    # Push the changes to a new branch   
    # git add .
    # git commit -m "Update Go version to $new_go_version"
    # git push origin $feature_branch
    
    # Create a pull request
    # NOTE: You'll need to integrate with a platform-specific API or use a tool like Hub for GitHub.
    # Example for GitHub using Hub:
    #hub pull-request -m "Update Go version to $new_go_version"
    echo 'commit and push is success'
    curl --location 'https://api.github.com/repos/$repo_owner/$repo_name/pulls' \
    --header 'Accept: application/vnd.github+json' \
    --header 'Authorization: Bearer $pat_token' \
    --header 'Content-Type: application/json' \
    --data '{
        "title": "Updated go version",
        "body": "Please pull these awesome changes in!",
        "head": "$repo_owner:$feature_branch",
        "base": "$base_ranch"
    }'

        cd ..
    done
