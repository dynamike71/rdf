#/bin/sh

# Program description:
#
# 1. find and sort all files by size
#
# 2. sequential read of sorted-file and compare all files with same size
#    a) no differences found, remove 
#    b) differences found, next  
#


# Step 2: Compare files and remove if no diff
function CompareAndRemove {

	# if filenames are equal or not accessible
	if [ ! -s "$2" ] || [ ! -s "$1" ] || [ "$1" == "$2" ]; then
		return
	fi

	local diff=`diff -q "$1" "$2"`	# alternative: sum1=`sha1sum "$1"`; sum2=`sha1sum "$2"`; if [ "$sum1" != "$sum2" ]; then

	if [ "$diff" == "" ]; then
		if [ "$report_only" == "false" ]; then
			echo "# Removing $2 : identical with $1"
			echo "rm '$2'" 
			rm "$2"
		else
			echo "# Intent to remove $2 : identical with $1"
			echo "# rm '$2'" 
		fi
	fi
}

# Step 2: Read "todo_file" in order to compare all files with same size
function CheckDuplicateFile {

	local fname1
	local fname2	

	while read -r fname1; do
		local cntr1=`expr $cntr1 + 1`

		if [ -r "$fname1" ]; then
			local cntr2=0

			while read -r fname2; do
				cntr2=`expr $cntr2 + 1`

				# Skip if comparison already done previously or file is not readable
				if [[ $cntr2 -le $cntr1 ]] || [ ! -r "$fname2" ]; then continue; fi

				CompareAndRemove "$fname1" "$fname2"

			done < "$todo_file"
		fi
	done < "$todo_file"

	rm "$todo_file"
}

function PrintDate {
	printf "# %s : %s %s\n" "$1" $(date '+%Y-%m-%d %H:%M:%S')
}

function Init {

	if [ "$1" == "" ]; then
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

function CreateTempFiles {

	tmp_prefix="rdf"

	sortfile=$(mktemp /tmp/$tmp_prefix.XXXXXX)
	todo_file=$(mktemp /tmp/$tmp_prefix.XXXXXX)
}

# Step 1: Find all files and sort by size
function FindAndSortFiles {

	PrintDate "Find Start"

	find -type f -name "$1" -printf "%s|%p\n" | sort > "$sortfile"

	PrintDate "Find End  "
}

# Step 2: main algorithm 
function CompareFiles {

	local last_size="undefined"

	while read -r line; do

		local fsize=`echo $line | cut -d "|" -f1`
		local fname=`echo $line | cut -d "|" -f2`

		if [ ! -s "$fname" ]; then 
			echo "$fname unreadable"; 
			continue; 
		fi 
	
		if [ "$last_size" != "$fsize" ] && [ "$last_size" != "undefined" ]; then
			CheckDuplicateFile 
		fi

		last_size=$fsize

		echo "$fname" >> "$todo_file"

	done < "$sortfile"

	# last size not yet done because size has not changed
	CheckDuplicateFile 

	rm "$sortfile"
}

function Usage() {
	echo 
	echo "Remove Duplicate Files"
	echo " Searches a directory (with subdirs) for identical files and removes them"
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

function Main {				

	Init "$1" "$2"

	CreateTempFiles 

	PrintDate "Start remove duplicate files"

	FindAndSortFiles "$1" "$2"
	CompareFiles

	PrintDate "End remove duplicate files"

}

##############################
###      Start of all     ####
##############################

	Main "$1" "$2" 



