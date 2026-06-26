#!bin/bash

# Pushes a new commit with all changed files to the Notes repo.

# Eventually build up to grab a commit message from an LLM generated log file.

# De-hardcoded: NOTES_DIR env-var override, $HOME-relative fallback.
repo_path="${NOTES_DIR:-$HOME/Documents/Notes}"
remote=upstream
branch_name=main
commit_message="Obsidian Updated from laptop"
time_stamp=" @ $(date)"
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

commit_message="$commit_message$time_stamp"

# Script starts here
cd "$repo_path" || { echo "Failed to change directory to $repo_path"; exit 1; }
echo ""
echo "Current directory: $(pwd)"
echo ""

# Run hugo command based on test flag
if [ "$is_test" = true ]; then
    echo "Running in test mode with hugo server"
    #hugo server --cleanDestinationDir --ignoreCache --disableFastRender
else
    echo "Pushing Notes to Github"
    echo ""

    #echo ""
    echo "Starting the update process:"
    echo "    Adding all files to git."
    echo ""
    git add .
    echo "    Committing changes with message: $commit_message"
    echo ""
    git commit -m "$commit_message"
    echo ""
    echo "    Pulling changes from GitHub."
    echo ""
    git pull "$remote" "$branch_name"
    echo ""
    echo "    Pushing changes to GitHub."
    echo ""
    git push "$remote" "$branch_name"
    echo ""
    echo "Done."
    echo ""
fi
