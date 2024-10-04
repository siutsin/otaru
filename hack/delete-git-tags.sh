#!/bin/bash

# Fetch all tags from the remote
git fetch --tags

# Delete all remote tags
echo "Deleting all remote tags..."
for tag in $(git tag -l)
do
  git push origin --delete refs/tags/$tag
done

# Delete all local tags
echo "Deleting all local tags..."
git tag -l | xargs -r git tag -d

echo "All tags have been deleted locally and remotely."
