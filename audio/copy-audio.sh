#!/bin/bash



copy_file () {
	
  total=${#@}
  count=1
  timestamp=$(date)
  root_path="${AUDIO_REPOSITORY_PATH:-$HOME/audio}"
  reaper_project_path=$root_path
  reaper_project_name="practice"

  # Pre-access to force hydration
  stat "$(root_path "$TARGET_DIR")" > /dev/null 2>&1
  	
  echo "Copying $total items to Audiorepository."
	
  for file_name in "$@"
  do
	
	# extract the date and time
	creation_date="date_not_found"
	creation_time="time_not_found"
	creation_date_line=`exiftool $file_name | grep -h "Date/Time Original"`
	
	if [[ $creation_date_line =~ ([0-9]{4}:[0-9]{2}:[0-9]{2})\ ([0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then		
		date=${BASH_REMATCH[1]}
		creation_date=${date//:/-}
		echo "Date found: $creation_date"
   
		time=${BASH_REMATCH[2]}
		creation_time=${time//:/-}
	  # echo "Time found: $creation_time"
    
    # create a directory for the year, if it doesn't exist
    [[ $creation_date_line =~ ([0-9]{4}) ]] 
    creation_year="${BASH_REMATCH[1]} practice"
    # echo "year directory: $creation_year"
	fi
	
	# if a note has been made in the recorder, add it to the filename
	file_note=""
	note_metadata=`exiftool $file_name | grep -h "Bwfxml Note"`

	echo "note_metadata: $note_metadata"
	if { [[ -n $note_metadata ]] && [[ ! $note_metadata =~ ^[[:space:]]*$ ]]; } || { [[ -n ${note_metadata[0]} ]] && [[ ! ${note_metadata[0]} =~ ^[[:space:]]*$ ]]; }; then
		file_note=$(echo "$note_metadata" | awk -F': ' '{print $2}')
		if [[ -n $file_note ]] && [[ ! $file_note =~ ^[[:space:]]*$ ]]; then
			# echo "Note found"
			file_note="$file_note "
		else
			# If there's no note, try to use the Originator
			echo "using Originator"
			note_metadata=`exiftool $file_name | grep -h "Originator"`
			if { [[ -n $note_metadata ]] && [[ ! $note_metadata =~ ^[[:space:]]*$ ]]; } || { [[ -n ${note_metadata[0]} ]] && [[ ! ${note_metadata[0]} =~ ^[[:space:]]*$ ]]; }; then
				file_note=$(echo "$note_metadata" | awk -F': ' '{print $2}')
				file_note="$file_note "
			fi
		fi
	fi
	
	file_name_with_extension=$(basename "$file_name")
	base_name=${file_name_with_extension%.*}
	
	new_file_name="$file_note$creation_date $creation_time $base_name.wav"
	base_path="$root_path/$creation_year/$creation_date"
    path="$root_path/$creation_year/$creation_date/tracks"
    echo "copying $file_name to $path"

    mkdir -p "$path"
	
	if [ -e "$path/$new_file_name" ]; then
	    echo "File $path/$new_file_name already exists. File was not copied."
	else
	  # echo "copying $new_file_name"
    cp -n "$file_name" "$path/$new_file_name"
	fi
	
	echo "count $count"

	# Sometimes my recording session crosses over midnight. Let's store the creation date of the first file
	# so that we can create the project in the correct location.
	if [ $count -eq 1 ]; then
		# Convert to timestamp
		timestamp=$(date -j -f "%Y-%m-%d" "$creation_date" +%s)
		echo "timestamp: $timestamp"
		
		# Convert timestamp to YYMMDD format
		date_short=$(date -j -r "$timestamp" +"%y%m%d")
		echo "date_short: $date_short"
		
		reaper_project_name="$reaper_project_name $date_short"
		reaper_project_path="$base_path"
	fi
	
	# If we're on the last item, create a Reaper project for the files if none exists.
	if [ $count -eq $total ]; then

	
		echo "creating a new reaper project: $reaper_project_path/$reaper_project_name.RPP"
		if [ -e "$reaper_project_path/$reaper_project_name.RPP" ]; then
			echo "Reaper project already exists"
		else
			echo "Creating Reaper project"
			nohup "$REAPER_BIN" -template "$REAPER_TEMPLATE" -saveas "$reaper_project_path/$reaper_project_name.RPP" &> /dev/null &
		fi
	fi
	
	((count++))
  done
}

export -f copy_file 

if [[ -n $1 ]]; then
	# echo "paramater found"
	ls $1/*.WAV | xargs bash -c 'copy_file $@' _
else
	# echo "no parameter found"
	ls *.WAV | xargs bash -c 'copy_file $@' _
fi

