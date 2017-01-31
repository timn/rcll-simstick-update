##########################################################################
#  functions.sh - rcll-simstick-update auxiliary functions
#
#  Created: Mon May 30 10:18:40 2016
#  Copyright  2016  Tim Niemueller [www.niemueller.de]
##########################################################################

#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Library General Public License for more details.
#
#  Read the full text in the LICENSE.GPL file in the doc directory.


# Pront failure message
print_fail()
{
		local COMPONENT=$1
		local MESSAGE=$2
		>&2 echo -e "\033[1;31mFAIL|$COMPONENT:\033[0m $MESSAGE"
}

# Check if script dir (current directory assumed to be just that)
# is a git repo and that git is available
git_repo_check()
{
		if [ -d .git ]; then
				# Check for git
				if type -P git >/dev/null ; then
						return 0
				else
						print_fail "git_repo_check" "git not found"
						return 1
				fi
		else
				print_fail "git_repo_check" "directory $(dirname $(pwd)) is not a git repository"
				return 1
		fi
}

# Update the script/current directory git repository
git_repo_fetch()
{
		local REMOTE_URL=$(git config --get remote.origin.url)
		local REPO_DIR=$(pwd)

		echo "Fetching updates in $REPO_DIR"
		echo "  - remote: $REMOTE_URL"

		if ! git fetch; then
				print_fail "git_repo_pull" "Failed to fetch from remote $REMOTE_URL"
				return 1
		fi
}

# Stash any local modifications
git_repo_stash()
{
		if ! git stash; then
				print_fail "git_repo_stash" "Failed to stash changes"
				return 1
		fi
}

git_repo_changed()
{		
		local LOCAL_HEAD=$(git rev-parse @)      || return 1
		local REMOTE_HEAD=$(git rev-parse @{u})  || return 1
		local BASE_HEAD=$(git merge-base @ @{u}) || return 1

		[ -n "$LOCAL_HEAD" ]  || return 2
		[ -n "$REMOTE_HEAD" ] || return 2
		[ -n "$BASE_HEAD" ]   || return 2
		
		if [ $LOCAL_HEAD = $REMOTE_HEAD ]; then
				echo up-to-date
		elif [ $LOCAL_HEAD = $BASE_HEAD ]; then
				echo pull
		elif [ $REMOTE_HEAD = $BASE_HEAD ]; then
				echo push
		else
				echo diverged
		fi
}


# Fetch from remote and integrate changes in current directory
git_repo_pull()
{
		if [ "$1" != "no-fetch" ]; then
				git_repo_fetch
		fi
		
		local REMOTE_URL=$(git config --get remote.origin.url)
		local REPO_DIR=$(pwd)
		local REPO_NAME=$(basename $REPO_DIR)

		local REPO_CHANGED=$(git_repo_changed) || return $?

		case "$REPO_CHANGED" in
				pull)
						echo "Pulling changes from remote"
						if ! git pull --ff-only ; then
								print_fail "git_repo_pull" "failed to update $(dirname $(pwd))"
								return 1
						fi
						;;
				push)
						print_fail "git_pull" "Repository $REPO_NAME contains local changes to push"
						;;
				diverged)
						print_fail "git_pull" "Repository $REPO_NAME local and remove have diverged"
						;;
				up-to-date)
						echo "Repository $REPO_NAME is already up to date"
						;;
				*)
						echo "Unknown repository state for $REPO_NAME"
						return 1
						;;
		esac

		return 0
}

git_repo_pull_cond_build()
{
		local REPO_DIR=$(pwd)
		local REPO_NAME=$(basename $REPO_DIR/)
		local REPO_CHANGED=$(git_repo_changed) || exit $?
		local BUILD_CMD=${1:-make -j4 all gui}
		
		case "$REPO_CHANGED" in
				pull)
						git_repo_pull no-fetch || exit $?
						echo -e "\n\n"
						echo "*** Building software ***"
						$BUILD_CMD
						;;
				push)
						print_fail "git_repo_pull_cond_build" "Repository $REPO_NAME contains local changes to push"
						return 1
						;;
				diverged)
						print_fail "git_repo_pull_cond_build" "Repository $REPO_NAME local and remove have diverged"
						return 1
						;;
				up-to-date)
						echo "Repository $REPO_NAME is already up to date"
						;;
				*)
						echo "Unknown repository state for $REPO_NAME"
						return 1
						;;
		esac

		return 0
}


# Get commit hash of script/current directory repository
git_repo_hash()
{
		local GIT_HASH=$(git rev-parse HEAD)
		if [ -z "$GIT_HASH" ]; then
				print_fail "git_repo_hash" "determining HEAD hash failed"
				return 1
		fi
		echo $GIT_HASH
		return 0
}

print_sechead()
{
		local SECHEAD=$1
		local HALF_WIDTH_L=$(((64-${#SECHEAD})/2))
		local HALF_WIDTH_R=$HALF_WIDTH_L
		if (( ( $HALF_WIDTH_L * 2 + ${#SECHEAD} ) < 64 )); then
				HALF_WIDTH_R=$(( $HALF_WIDTH_R + 1 ))
		fi
	  
		echo -e "\n"
		echo -e "\033[1;32m##########################################################################\033[0m"
		printf "\\033[1;32m###\\033[0m %${HALF_WIDTH_L}s \\033[1;33m%s\\033[0m %${HALF_WIDTH_R}s \\033[1;32m###\\033[0m\n" "" "$SECHEAD" ""
		echo -e "\033[1;32m##########################################################################\033[0m"
		echo
}

ros_package_assert()
{
		local ROS_PACKAGE=$1

		if ! rospack find $ROS_PACKAGE >/dev/null 2>&1 ; then
				print_fail "ros_detect" "Could not find package $ROS_PACKAGE"
				return 1
		fi
		return 0
}

ros_package_dir()
{
		local ROS_PACKAGE=$1
		ros_package_assert "$ROS_PACKAGE" || return $?
		local ROS_PACKAGE_DIR=$(rospack find $ROS_PACKAGE) || return $?
		echo $ROS_PACKAGE_DIR
		return 0
}

ros_detect()
{
		if ! type -P rospack >/dev/null ; then
				print_fail "ros_detect" "Could not detect rospack"
				return 1
		fi
		if [ -z "$ROS_DISTRO" ]; then
				print_fail "ros_detect" "ROS_DISTRO not set, forgot to source setup.bash?"
				return 2
		fi
		if ! ros_package_assert roscpp ; then
				print_fail "ros_detect" "Could not find roscpp package, has ROS been built?"
				return 3
		fi
		case $ROS_DISTRO in
				hydro|indigo|jade|kinetic)
						echo "Detected compatible ROS $ROS_DISTRO"
						;;
				boxturtle|cturtle|diamondback|electric|fuerte|groovy)
						print_fail "ros-detect" "Detected old incompatible ROS $ROS_DISTRO"
						return 4
						;;
				*)
						echo "Detected unknown ROS $ROS_DISTO, just assuming compatibility"
						;;
		esac
		return 0
}

