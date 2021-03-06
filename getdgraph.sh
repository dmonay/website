#!/usr/bin/env bash
#
#                  Dgraph Installer Script
#
#   Homepage: https://dgraph.io
#   Requires: bash, curl, tar or unzip
#
# Hello! This is a script that installs Dgraph
# into your PATH (which may require password authorization).
# Use it like this:
#
#	$ curl https://get.dgraph.io | bash
#
# This should work on Mac, Linux, and BSD systems.

set -e

BLACK='\033[30;1m'
RED='\033[91;1m'
GREEN='\033[32;1m'
RESET='\033[0m'
WHITE='\033[97;1m'

print_instruction() {
    printf "$WHITE$1$RESET\n"
}

print_step() {
    printf "$BLACK$1$RESET\n"
}

print_error() {
    printf "$RED$1$RESET\n"
}

print_good() {
    printf "$GREEN$1$RESET\n"
}

install_dgraph() {

printf $BLACK
cat << "EOF"
  _____                        _
 |  __ \                      | |
 | |  | | __ _ _ __ __ _ _ __ | |__
 | |  | |/ _` | '__/ _` | '_ \| '_ \
 | |__| | (_| | | | (_| | |_) | | | |
 |_____/ \__, |_|  \__,_| .__/|_| |_|
          __/ |         | |
         |___/          |_|

EOF
printf $RESET

	# Check curl is installed
	if ! hash curl 2>/dev/null; then
		print_error "Could not find curl. Please install curl and try again.";
		exit 1;
	fi

	sudo_cmd=""
	if hash sudo 2>/dev/null; then
		sudo_cmd="sudo"
	fi

	install_path="/usr/local/bin"

	release_version="$(curl -s https://api.github.com/repos/dgraph-io/dgraph/releases | grep "tag_name" | awk '{print $2}' | tr -dc '[:alnum:].\n\r' | head -n1)"
	print_step "Latest release version is $release_version."

	platform="$(uname | tr '[:upper:]' '[:lower:]')"
	if [ "$platform" = "linux" ]; then
		md5cmd=md5sum
	else
		md5cmd="md5 -r"
	fi

	checksum_file="dgraph-checksum-$platform-amd64-$release_version".md5
	checksum_link="https://github.com/dgraph-io/dgraph/releases/download/"$release_version"/"$checksum_file
	print_step "Downloading checksum file."
	if curl -L --progress-bar "$checksum_link" -o "/tmp/$checksum_file"; then
		print_step "Download complete."
	else
		print_error "Sorry. Binaries not available for your platform. Please compile manually: https://wiki.dgraph.io/Beginners_Guide"
		echo
		exit 1;
	fi

	dgraph=$(grep -m 1 /usr/local/bin/dgraph  /tmp/$checksum_file | awk '{print $1;}')
	dgraphloader=$(grep -m 1 /usr/local/bin/dgraphloader  /tmp/$checksum_file | awk '{print $1;}')

	print_step "Comparing checksums for dgraph binaries"

	if $md5cmd /usr/local/bin/dgraph &>/dev/null && $md5cmd /usr/local/bin/dgraphloader &>/dev/null; then
		dgraphsum=$($md5cmd /usr/local/bin/dgraph | awk '{print $1;}')
		dgraphloadersum=$($md5cmd /usr/local/bin/dgraphloader | awk '{print $1;}')
	else
		dgraphsum=""
		dgraphloadersum=""
	fi

	if [ "$dgraph" == "$dgraphsum" ] && [ "$dgraphloader" == "$dgraphloadersum" ]; then
		print_good "You already have Dgraph $release_version installed."
	else
		tar_file=dgraph-$platform-amd64-$release_version".tar.gz"
		dgraph_link="https://github.com/dgraph-io/dgraph/releases/download/"$release_version"/"$tar_file

		# Backup existing dgraph binaries in HOME directory
		if hash dgraph 2>/dev/null; then
			dgraph_path="$(which dgraph)"
			dgraph_backup="dgraph_backup_olderversion"
			print_step "Backing up older versions in ~/$dgraph_backup (password may be required)."
			mkdir -p ~/$dgraph_backup
			$sudo_cmd mv $dgraph_path* ~/$dgraph_backup/.
		fi

		# Download and untar Dgraph binaries
		if curl --output /dev/null --silent --head --fail "$dgraph_link"; then
			print_step "Downloading $dgraph_link"
			curl -L --progress-bar "$dgraph_link" -o "/tmp/$tar_file"
			print_good "Download complete."
		else
			print_error "Sorry. Binaries not available for your platform. Please compile manually: https://wiki.dgraph.io/Beginners_Guide";
			echo
			exit 1;
		fi

		print_step "Inflating binaries (password may be required).";
		$sudo_cmd tar -C /usr/local/bin -xzf /tmp/$tar_file --strip-components=1;
		rm "/tmp/"$tar_file;

		# Check installation
		if hash dgraph 2>/dev/null; then
			print_good "Dgraph binaries $release_version have been installed successfully in /usr/local/bin.";
		else
			print_error "Installation failed. Please try again.";
			exit 1;
		fi
	fi

	icu=$(grep -m 1 /icudt58l.dat  /tmp/$checksum_file | awk '{print $1;}')

	icufile="icudt58l.dat"
	iculoc="/usr/local/share/$icufile"
	if $md5cmd $iculoc &>/dev/null; then
		icusum=$($md5cmd $iculoc | awk '{print $1;}')
	else
		icusum=""
	fi

	if [ "$icu" == "$icusum" ]; then
		print_good "You already have ICU v58.2 data file."
	else
		if [ -f $iculoc ]; then
			$sudo_cmd rm $iculoc
		fi
		print_step "Downloading ICU data file.";
		curl -L --progress-bar https://github.com/dgraph-io/dgraph/releases/download/$release_version/$icufile -o /tmp/$icufile;
		$sudo_cmd mv /tmp/$icufile /usr/local/share/
		print_good "ICU data file for v58.2 has been downloaded and put in /usr/local/share.";
	fi

	if [ "$ICU_DATA" != "$iculoc" ]; then
print_error "
###########################################  IMPORTANT  #################################################
#                                                                                                       #
#  You do not have ICU_DATA environment variable set.                                                   #
#  To use the indexing features of Dgraph, export the ICU_DATA variable to your ~/.bashrc or ~/.zshrc. 	#
#                                                                                                       #
#  echo \"export ICU_DATA=/usr/local/share/icudt58l.dat\" >> ~/.bashrc                                    #
#  echo \"export ICU_DATA=/usr/local/share/icudt58l.dat\" >> ~/.zshrc                                     #
#                                                                                                       #
#########################################################################################################
"
	else
		print_good "You already have ICU_DATA environment variable correctly set."
	fi
	print_instruction "Please visit https://wiki.dgraph.io/Get_Started for further instructions on usage."
}

install_dgraph "$@"
