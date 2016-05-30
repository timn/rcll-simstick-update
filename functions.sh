##########################################################################
#  functions.sh - rcll-simstick-update auxiliary functions
#
#  Created: Mon May 30 10:18:40 2016
#  Copyright  2016  Tim Niemueller [www.niemueller.de]
############################################################################/

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

git_repo_check()
{
		if [ -d .git ]; then
				# Check for git
				if type -P git >/dev/null ; then
						return 0
				else
						echo "FAIL|rcll-simstick-update: git not found"
						return 1
				fi
		else
				echo "FAIL|rcll-simstick-update: directory is not a git repository" 
				return 1
		fi
}

git_repo_pull()
{
		if ! git pull --ff-only ; then
				echo "FAIL|rcll-simstick-update: git pull failed"
				return 1
		fi
		return 0
}
