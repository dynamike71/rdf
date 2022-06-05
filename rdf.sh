#/bin/sh

# Program description:
#
# 1. find and sort all files by size
#
# 2. sequential read of sorted-files and compare all files with same size
#    a) no differences found, remove 
#    b) differences found, next  
#


# Step 2: Compare files and remove if no diff
CompareAndRemove() {

	# Skip, if filenames are equal or not readable or already removed
	if [ ! -r "$2" ] || [ ! -r "$1" ] || [ "$1" == "$2" ] || [[ " ${RemovedFilesArr[*]} " =~ " $2 " ]]; then
		return
	fi

	# If comparison on previous runs are already done for this file combination and a difference was detected, 
	# another diff is not anymore required. The files are different (if none of them where modified meanwhile)
	if [ "$UseSkipDiff" == "true" ]; then
		if [[ " ${SkipDiffFileArr[*]} " =~ " $1|$2 " ]] || [[ " ${SkipDiffFileArr[*]} " =~ " $2|$1 " ]]; then
			echo "# Skipped: Diff already done : $1|$2"
			return
		fi
	fi

	local diff=`diff -q "$1" "$2"`	

	# No differences found, remove
	if [ "$diff" == "" ]; then

		if [ "$report_only" == "false" ]; then

			echo "# Removing $2 : identical with $1"
			echo "rm \"$2\"" 

			if [ -e "$2" ]; then
				rm "$2"
			fi
		else

			echo "# Intent to remove $2 : identical with $1"
			echo "# rm \"$2\"" 
		fi

		RemovedFilesArr+=("$2")
	fi

	# Difference found => save the compared files in order to avoid comparison on restarts
	if [ "$diff" != "" ]; then
		echo "$1|$2" >> "$SkipDiffFile"
	fi
}

# Step 2: Read "SameFileSizeArr" in order to compare all files with same size
CheckDuplicateFile() {										# echo "CheckDuplicateFile"

	local fname1
	local fname2	

	RemovedFilesArr=()


	for (( cntr1 = 0; cntr1 < ${#SameFileSizeArr[@]}; cntr1++ )); do

		fname1=${SameFileSizeArr[$cntr1]};

		if [ -r "$fname1" ]; then

			for (( cntr2 = 0; cntr2 < ${#SameFileSizeArr[@]}; cntr2++ )); do

				fname2=${SameFileSizeArr[$cntr2]};

				# Skip if comparison already done previously or file is not readable
				if [ $cntr2 -le $cntr1 ] || [ ! -r "$fname2" ]; then 
					continue
				fi

				CompareAndRemove "$fname1" "$fname2"

			done
		fi
	
	done

	SameFileSizeArr=()
}

PrintDate() {
	printf "# %s : %s %s\n" "$1" $(date '+%Y-%m-%d %H:%M:%S')
}

ReadSkipDiffFile() {

	SkipDiffFileArr=()

	while read -r line; do
		SkipDiffFileArr+=("$line")
	done < "$SkipDiffFile"
}

CheckRestart() {

	UseSkipDiff="true"

	if [ -r "$SkipDiffFile" ]; then

		echo -n "This is a restart. "
		echo -n "Skip comparison for file combinations already detected as being differnt on previous runs ? (y/n) [y] : "
		read answer

		if [ "$answer" == "n" ] || [ "$answer" == "N" ]; then
			UseSkipDiff="false"
		fi

		if [ "$UseSkipDiff" == "true" ]; then
			ReadSkipDiffFile
		fi
	fi
}

Init() {
	if [ "$1" == "" ] || [ $# -eq 0 ]; then	
		Usage
		exit
	fi

	report_only="false"

	if [ "$1" == "-report-only" ] || [ "$1" == "--report-only" ]; then
		file_suffix=$2			# second parameter
		report_only="true"
	else
		file_suffix=$1			# first parameter 
		if [ "$2" == "-report-only" ] || [ "$2" == "--report-only" ]; then
			report_only="true"
		fi
	fi

	if [ "$report_only" == "true" ]; then
		echo "Report-Only-Mode"
	fi
}

# Step 1: Find all files and sort by size
FindAndSortFiles() {

	PrintDate "Find Start"

	FilesSortedBySizeArr=()

	while IFS= read -r -d $'\n'; do
		FilesSortedBySizeArr+=("$REPLY")
	done < <(find -type f -name "$1" -printf "%s|%p\n" | sort -n )

	PrintDate "Find End  "
}

# Step 2: main algorithm 
CompareFiles() {

	local last_size="undefined"

	SameFileSizeArr=()

	for line in "${FilesSortedBySizeArr[@]}"; do

		local fsize=`printf "%s" "$line" | cut -d "|" -f1`
		local fname=`printf "%s" "$line" | cut -d "|" -f2`

		if [ ! -r "$fname" ]; then 
			echo "$fname unreadable"; 
			continue; 
		fi 
	
		# If size has changed, compare files with same size
		if [ "$last_size" != "$fsize" ] && [ "$last_size" != "undefined" ]; then
			CheckDuplicateFile 
		fi

		last_size=$fsize

		SameFileSizeArr+=("$fname")

	done 

	# last size not yet done because size has not changed
	CheckDuplicateFile 
}

Usage() {
	echo 
	echo "Remove Duplicate Files"
	echo " Searches a directory (with subdirs) for identical files and removes/reports them"
	echo
	echo "USAGE: $0 \"file-suffix\" [--report-only]"
	echo
	echo "       Example: $0 \"*.jpg\" --report-only"
	echo
	echo "WARNING: it is extremely important to use double quote for the search patten of files (file-suffix)"
	echo 
	echo "OPTION:"
	echo " -report-only : just create report file without removing files"
	echo
}

Main() {

	Init "$1" "$2"

	CheckRestart

	PrintDate "Start remove duplicate files"

	FindAndSortFiles "$1" "$2"
	CompareFiles

	PrintDate "End remove duplicate files"

}

##############################
###      Start of all     ####
##############################

	# In order to boost performance on restarts, the file "SkipDiffFile" contains a list of comparisons where a difference has 
	# already been detected and there is no need to "diff" again the combination of files. 
	SkipDiffFile=".rdf-skip-diff.txt"	

	Main "$1" "$2" 



