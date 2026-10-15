#!/usr/bin/env bash
# Commit paths to a bot branch, open its PR with auto-merge, run CI and wait for the merge.
# Usage: open-bot-pr.sh BRANCH TITLE BODY PATH...
set -euo pipefail
branch=$1 title=$2 body=$3
shift 3
bot='41898282+github-actions[bot]@users.noreply.github.com'

# Replace an earlier bot branch. Keep a branch that has commits from another author.
lease=$(git ls-remote origin "refs/heads/$branch" | cut -f1)
if [ -n "$lease" ]; then
  authors=$(gh api "repos/$GITHUB_REPOSITORY/compare/main...$lease" --jq '[.commits[].commit.author.email] | unique | join(" ")')
  if [ -n "$authors" ] && [ "$authors" != "$bot" ]; then
    echo "$branch has commits from another author. Merge or delete it first." >&2
    exit 1
  fi
fi
git switch -c "$branch"
git add -- "$@"
git -c user.name='github-actions[bot]' -c user.email="$bot" commit -m "$title"
git push --force-with-lease="refs/heads/$branch:$lease" origin "HEAD:refs/heads/$branch"
pr=$(gh pr list --head "$branch" --base main --state open --json url --jq '.[0].url // empty')
[ -n "$pr" ] || pr=$(gh pr create --base main --head "$branch" --title "$title" --body "$body")
gh pr merge "$pr" --auto --squash

# GITHUB_TOKEN pushes do not start push CI. Dispatch CI for each new head.
gh workflow run check.yml --ref "$branch"
deadline=$((SECONDS + 1800))
while [ "$SECONDS" -lt "$deadline" ]; do
  sleep 30
  info=$(gh pr view "$pr" --json state,mergeStateStatus,mergedBy --jq '"\(.state) \(.mergeStateStatus) \(.mergedBy.is_bot // false)"')
  read -r state status merged_by_bot <<<"$info"
  if [ "$state" = MERGED ]; then
    # A human merge pushes to main and starts its CI. A bot merge does not.
    if [ "$merged_by_bot" = true ]; then gh workflow run check.yml --ref main; fi
    exit 0
  fi
  [ "$state" = OPEN ] || {
    echo 'The PR was closed.' >&2
    exit 1
  }
  if [ "$status" = BEHIND ]; then
    gh pr update-branch "$pr"
    gh workflow run check.yml --ref "$branch"
  elif gh pr checks "$pr" --required --json bucket --jq '.[].bucket' 2>/dev/null | grep -qx fail; then
    echo 'A required check failed.' >&2
    exit 1
  fi
done
echo 'The PR did not merge before the time limit.' >&2
exit 1
