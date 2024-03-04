#!/bin/bash

if [ -z "$workDir" ]; then
  workDir=$(mktemp -d -t raiseRepoXXX)
fi
if [ "$DRY_RUN" = false ]; then
  echo ""; echo "This is NOT a DRY RUN! We will push to the origin Repos!"; echo "";
else
  echo ""; echo "This is a DRY RUN! Nothing is pushed!"
  echo "Change it by setting the variable 'DRY_RUN' to 'false' before executing this script. ('export DRY_RUN=false')"; echo ""
fi
if [ -z "$autoMerge" ]; then
  autoMerge=0
fi
if [ -z "$sourceBranch" ]; then
  sourceBranch="master"
fi
if [ -z "$newBranch" ]; then
  uuid=$(date +%s%N)
  newBranch="${sourceBranch}-${uuid}"
fi

function runRepoUpdate {
  currentDir=$(pwd)
  updateAction=$1
  shift
  repos=("$@")

  echo ""; echo "Convert the follwoing "${#repos[@]}" repos:"
  for repo in "${repos[@]}"; do
    echo " - ${repo}"
  done

  reposToPush=()

  for repo in "${repos[@]}"; do
     echo ""; echo "==> start converting repo '${repo}'"; echo ""
    
    branchExists=$(git ls-remote --heads ${repo} refs/heads/${sourceBranch})
    if [[ -z ${branchExists} ]]; then
      echo ""; echo "--> skipping repo '${repo}' because it has no '${sourceBranch}' branch";
      continue
    fi

    cloneDir="${workDir}/${repo}"
    echo "git: clone branch '${sourceBranch}' of repo '${repo}' to '${cloneDir}'"
    git clone -b ${sourceBranch} -q "${repo}" "${cloneDir}"

    cd "${cloneDir}"

    echo "git: create new branch '${newBranch}'"
    git checkout -q -b "${newBranch}" 

    skipReason=""
    ${updateAction}
    if [[ -n ${skipReason} ]]; then
      echo ""; echo "--> skipping repo '${repo}' because: ${skipReason}";
      continue
    fi

    reposToPush+=(${repo})
    echo ""; echo "--> finished converting repo '${repo}'";
  done

  if [ "$DRY_RUN" != false ]; then
    echo ""; echo "Because this is a DRY RUN we are finished here and do NOT push!"
    cd "${currentDir}"
    return;
  fi

  if [ "${#reposToPush[@]}" -eq 0 ]; then
    echo ""; echo "Finished here because no repo has changed, nothing to push!"
    cd "${currentDir}"
    return;
  fi

  echo ""; echo "Push the follwoing "${#reposToPush[@]}" repos:"
  for repo in "${reposToPush[@]}"; do
    echo " - ${repo}"
  done

  for repo in "${reposToPush[@]}"; do
    echo ""; echo "==> start pushing repo '${repo}'"; echo ""

    cloneDir="${workDir}/${repo}"
    cd "${cloneDir}"

    echo "Push branch ${newBranch} to repo ${repo}"
    git push -q -u origin "${newBranch}"

    gh auth login --with-token < ${tokenFile}
    gh pr create --fill --base ${sourceBranch}

    if [ "$autoMerge" = "1" ]; then
      gh pr merge --merge
    fi

    echo ""; echo "--> finished pushing repo '${repo}'";
  done
  cd "${currentDir}"
}
