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
