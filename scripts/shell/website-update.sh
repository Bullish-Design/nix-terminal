#!bin/bash

# Pushes a new commit with all changed files to the website repo.

# Eventually build up to grab a commit message from an LLM generated log file.

# De-hardcoded: WEBSITE_DIR env-var override, $HOME-relative fallback.
repo_path="${WEBSITE_DIR:-$HOME/Documents/Projects/Website}"
remote=upstream
branch_name=main
commit_message="Updated Website from script"
is_test=false


# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -test)
            is_test=true
            shift
            ;;
        *)
            # Any other argument is treated as the commit message
            commit_message="$1"
            shift
            ;;
    esac
done


# Script starts here
cd "$repo_path/website/themes/roxo-muted" || { echo "Failed to change directory to $repo_path/website"; exit 1; }
echo ""
echo "Current directory: $(pwd)"
echo ""
#git submodule update --remote
#echo ""
git pull origin master
echo ""


cd "$repo_path/website" || { echo "Failed to change directory to $repo_path/website"; exit 1; }
echo ""
echo "Current directory: $(pwd)"
echo ""


# Run hugo command based on test flag
if [ "$is_test" = true ]; then
    echo "Running in test mode with hugo server"
    hugo server --cleanDestinationDir --ignoreCache --disableFastRender
else
    echo "Running production build"
    hugo --cleanDestinationDir --ignoreCache
    echo ""

    # Only proceed with git operations if not in test mode
    cd "$repo_path" || { echo "Failed to change directory to $repo_path"; exit 1; }
    echo ""
    echo "Current directory: $(pwd)"
    echo ""
    echo "Starting the update process:"
    echo "    Adding all files to git."
    git add .
    echo "    Committing changes with message: $commit_message"
    echo ""
    git commit -m "$commit_message"
    echo ""
    echo "    Pushing changes to GitHub."
    echo ""
    git push "$remote" "$branch_name"
    echo ""
    echo "Done."
    echo ""
fi
