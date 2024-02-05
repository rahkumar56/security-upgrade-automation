#!/bin/bash

# Function to fetch the latest version using GitHub API
fetch_latest_version() {
    local repo_url="$1"
    local pat_token="$2"

    # Get the latest release from the GitHub API
    latest_version=$(curl --location "${repo_url}/releases/latest" \
        --header 'Accept: application/vnd.github.v3+json' \
        --header "Authorization: Bearer ${pat_token}" \
        --header 'X-GitHub-Api-Version: 2022-11-28' \
        | jq -r '.tag_name')

    version_without_v="${latest_version#v}"

    echo "${version_without_v}"
}

# fetch_latest_version() {
#     local repo_url="$1"
#     local pat_token="$2"

#     # Print the curl command
#     echo "Fetching latest version for repository: ${repo_url}"
#     curl_command="curl --location '${repo_url}/releases/latest' \
#         --header 'Accept: application/vnd.github.v3+json' \
#         --header 'Authorization: Bearer ${pat_token}' \
#         --header 'X-GitHub-Api-Version: 2022-11-28'"

#     #echo "Executing curl command:"
#     #echo "$curl_command"

#     # Get the latest release from the GitHub API
#     response=$(eval "$curl_command")

#     # Print the response
#     #echo "Curl Response:"
#    # echo "$response"

#     # Parse the latest version from the response using jq
#     latest_ver=$(echo "$response" | jq -r '.tag_name')

#     # Remove 'v' prefix from version, if present
#     version_without_v="${latest_ver#v}"

#     #echo "Latest Version without 'v': ${version_without_v}"

#     echo "${version_without_v}"
# }


# Function to replace the version in the step config image
replace_version() {
    local file="$1"
    local image_name="$2"
    local new_version="$3"

    # Replace the version in the YAML file
   # sed -i "s|${image_name}:[0-9.]*|${image_name}:${new_version}|g" "$file"
    # Replace the existing Go version with the new version
      #sed -i "s/${image_name}:[0-9.]*/${image_name}:${new_version}/g" "$file"
      sed "s|${image_name}:[0-9.]*|${image_name}:${latest_version}|g" "$yaml_file" > temp.yaml && mv temp.yaml "$file"


}

# Function to get value by key
get_repoownerinfo_by_imagename() {
    local key="$1"
    local index

    for index in "${!image_keys[@]}"; do
        if [[ "${image_keys[$index]}" == "$key" ]]; then
            value=repo_owner_values[$index]
            echo "${repo_owner_values[$index]}"
            return 0
        fi
    done

    # Key not found
    echo "repo Owner value not found for key:"$key
    return 1;
}

update_version_images(){
    local image_names_list="$1"
    local pat="$2"

    for image_name in $image_names_list; do
    # Extract repository and owner from image name
    echo ''
    echo ''
    echo "************Started***************************"
    echo 'Inside loop: image name ::'$image_name
    repo_owner=$(echo "${image_name}" | cut -d'/' -f1)
    repo_n=$(echo "${image_name}" | cut -d'/' -f2)
    repo_name=$(echo "${repo_n}" | cut -d':' -f1)
    imagePath=$(echo "${image_name}" | cut -d':' -f1)
    echo 'imagePath: '$imagePath
    echo "repo_owner: "$repo_owner
    echo "repo_name: "$repo_name

     if [[ ! " ${excluded_reponame[@]} " =~ " ${repo_name} " ]]; then
        # Your code for the current iteration
        #Get repo owner and repo name from map
         repoOwner=$(get_repoownerinfo_by_imagename "$repo_name")
         echo "Repo owner : ${repoOwner}"

          # Fetch the latest version and replace in the YAML file
         latest_version=$(fetch_latest_version "https://api.github.com/repos/${repoOwner}" $pat)
         echo 'latest_version:'$latest_version
         
         #check whether rootless is suffixed after version
         new_image_name=$imagePath':'$latest_version
         if [[ $image_name == *"-rootless"* ]]; then
        # Append '-rootless' to the new value
            new_version="${latest_version}-rootless"
            new_image_name=$imagePath':'$new_version
         else
            # Use the original version if no '-rootless'
            new_version="$latest_version"
            new_image_name=$imagePath':'$new_version
        fi  
         echo 'new_image_name: '$new_image_name
         echo 'new_version: '$new_version

         #replace new version in yml
         replace_version "${yaml_file}" "${imagePath}" "${new_version}"
         echo 'replacement done for :'$imagePath
         echo '************Ended***************************'
         echo ''
         echo ''
         
    else
        # Skip this iteration
        echo "Skipping key: $imagename, value: $reponame"
        continue
    fi
   
done

echo "Versions replaced successfully!"

}


update_vmnames(){
    local file="$1"
    local vm_names_list="$2"
    local pat="$3"

    for name in $vm_names_list; do
    # Extract repository and owner from image name
    echo ''
    echo ''
    echo "************Started***************************"
    echo 'Inside loop: image name ::'$name
    # Extract repo_owner and repo_name using awk
    repo_owner=$(echo "$name" | awk -F'/' '{print $2}')
    repo_name=$(echo "$name" | awk -F'/' '{print $3}' | cut -d'@' -f1)

    echo "Repo Owner: $repo_owner"
    echo "Repo Name: $repo_name"
    

     if [[ ! " ${excluded_reponame[@]} " =~ " ${repo_name} " ]]; then
          # Fetch the latest version and replace in the YAML file
         latest_version=$(fetch_latest_version "https://api.github.com/repos/${repo_owner}/${repo_name}" $pat)
         echo 'latest_version:'$latest_version
         #replace vmContainerlessStepConfig names
         sed "s|${name}|github.com/${repo_owner}/${repo_name}@refs/tags/v${latest_version}|g" "$yaml_file" > temp.yaml && mv temp.yaml "$file"
         echo 'replacement done for :'$imagePath
         echo '************Ended***************************'
         echo ''
         echo ''
         
    else
        # Skip this iteration
        echo "Skipping key: $imagename, value: $reponame"
        continue
    fi
   
done

echo "Versions replaced successfully!"

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
    export hc_repo_name="${url_parts[length-1]}"
    export hc_repo_owner="${url_parts[length-2]}"

    echo "Repository Name: $hc_repo_name"
    echo "Repository Owner: $hc_repo_owner"
}

clone_repo(){
    local repo="$1"
    local feature_branch="$2"
    # Clone the repository
     echo "***************clone repo repo: $repo \n\n"
    repo_name=$(basename "$repo" .git)
    echo 'Repo : '$repo

     get_repo_info $repo
    echo "***************in call Repository Name: $hc_repo_name"
    echo "**************in call Repository Owner: $hc_repo_owner"
    
    git config --global user.email "rahul.kumar@harness.io"
    git config --global user.name "rahkumar56"
    git remote set-url origin https://rahkumar56:$pat_token@github.com/$hc_repo_owner/$hc_repo_name
    pwd

    git clone "$repo"
    git clone "https://rahkumar56:${pat_token}@github.com/${hc_repo_owner}/${hc_repo_name}.git"
    cd "$repo_name" || exit
     #Get Repo info
    # get_repo_info $repo
    # echo "***************in call Repository Name: $hc_repo_name"
    # echo "**************in call Repository Owner: $hc_repo_owner"
    
     git config --global user.email "rahul.kumar@harness.io"
     git config --global user.name "rahkumar56"
     git remote set-url origin https://rahkumar56:$pat_token@github.com/$hc_repo_owner/$hc_repo_name
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
    echo 'Going to hit generate PR curl in side sh file.'ec
    echo $hc_repo_name
    echo $hc_repo_owner
    echo $pat_token |base64
    echo $pat_token 
    echo $feature_branch
    echo $base_ranch
    url='https://api.github.com/repos/'$hc_repo_owner'/'$hc_repo_name'/pulls'
    echo $url
    body='{ "title":"Updated ci-manager-config.yml with latest plugin versions", "body":"Updated ci-manager-config.yml with latest plugin versions.", "head":"'$hc_repo_owner':'$feature_branch'", "base":"'$base_ranch'" }'
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

    curl -X POST --data-urlencode "payload={\"channel\": \"<+pipeline.variables.channel_name>
    \", \"username\": \"Security-Automation\",\"type\": \"mrkdwn\", \"text\":\"*Security Automation : PR Is generated for ci-manager-config.yml file :* :white_check_mark: :$pr_url", \"icon_emoji\": \":harnesshd:\"}" https://hooks.slack.com/services/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

    #echo "***************Ended Execution for the repo: $repo_name \n\n PR url: $pr_url"
    echo $pr_url

}

image_keys=("kaniko" "kaniko-ecr" "kaniko-acr" "kaniko-gcr" "drone-git" "gcs" "s3" "artifactory" "cache" "docker" "acr" "ecr" "gcr" "gar")
repo_owner_values=("drone/drone-kaniko" "drone/drone-kaniko" "drone/drone-kaniko" "drone/drone-kaniko" "wings-software/drone-git" "drone-plugins/drone-gcs" "drone-plugins/drone-s3" "harness/drone-artifactory" "drone-plugins/drone-meltwater-cache" "drone-plugins/drone-docker" "drone-plugins/drone-docker" "drone-plugins/drone-docker" "drone-plugins/drone-docker" "drone-plugins/drone-docker"  )
excluded_reponame=( "slsa-plugin" "ssca-plugin" "null" "sto-plugin")
yaml_file="332-ci-manager/config/ci-manager-config.yml"
#pat_token='<PAT_Token>'
repo_url='https://github.com/harness/harness-core.git'
#feature_branch='testRahul'

echo 'yaml_file path: ' $yaml_file
echo 'pat_token: ' $pat_token
echo 'feature_branch: '$feature_branch
#clone repo and switch dir into repo
clone_repo $repo_url $feature_branch

# Extract image names from the YAML file and update their versions
 image_names=$(yq eval '.ciExecutionServiceConfig.stepConfig.*.image' "$yaml_file" | tr -d '"')
 echo 'image_names:\n' $image_names
 update_version_images "${image_names}" "${pat_token}"

 vmimage_names=$(yq eval '.ciExecutionServiceConfig.stepConfig.vmImageConfig.*' "$yaml_file" | tr -d '"')
 echo 'image_names:\n' $vmimage_names
 update_version_images "${vmimage_names}" "${pat_token}"

vmnames=$(yq eval '.ciExecutionServiceConfig.stepConfig.vmContainerlessStepConfig.*.name' "$yaml_file" | tr -d '"')
echo 'image_names:\n' $vmnames
update_vmnames "${yaml_file}" "${vmnames}" "${pat_token}"

commit_generate_pr
