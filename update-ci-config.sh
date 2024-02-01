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


image_keys=("kaniko" "kaniko-ecr" "kaniko-acr" "kaniko-gcr" "drone-git" "gcs" "s3" "artifactory" "cache" "docker" "acr" "ecr" "gcr" "gar")
repo_owner_values=("drone/drone-kaniko" "drone/drone-kaniko" "drone/drone-kaniko" "drone/drone-kaniko" "wings-software/drone-git" "drone-plugins/drone-gcs" "drone-plugins/drone-s3" "harness/drone-artifactory" "drone-plugins/drone-meltwater-cache" "drone-plugins/drone-docker" "drone-plugins/drone-docker" "drone-plugins/drone-docker" "drone-plugins/drone-docker" "drone-plugins/drone-docker"  )
excluded_reponame=( "slsa-plugin" "ssca-plugin" "null" "sto-plugin")
#yaml_file="/Users/rahulkumar/Documents/security_upgrade/ci-manager-config.yml"
#pat_token='<PAT_Token>'
echo 'yaml_file path: ' $yaml_file
echo 'pat_token: ' $pat_token

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