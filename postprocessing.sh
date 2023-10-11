#!/bin/bash

time=$(date +"%Y%m%d_%H%M%S") # Take a timestamp at startup. Will take more as the script runs. 

# Files
lockFile='/Volumes/PLEX/dvrProcessing.lock' # To run the postprocessing for one recording at a time. 
inFile="$1" # The file path to the video file. PLEX passes this in as the argument for the script. 
inFileNoExt=${1%.*} # The file path of the video file with the video's extension removed. 
tmpFile="$inFileNoExt.mkv" # A temp file path, but which once fully processed will replace the original. 
tmpFileSrt="$inFileNoExt.srt" # Temp file path to hold the subtitles to be baked into the final .mkv
dvrPostLog="/Volumes/PLEX/recorderLogs/recorder_${time}.log" # Log output for this script. 
comskipIni="/Volumes/PLEX/generalComskip.ini" # The ini file containing comskip settings. 

# External tools
# Point at the install locations for ffmpeg, ffprobe, comcut, and ccextractor. 
ffmpeg=/opt/homebrew/bin/ffmpeg
ffprobe=/opt/homebrew/bin/ffprobe
cut=/Users/joaquin/Repos/comchap/comcut
cc=/Users/joaquin/Repos/ccextractor/mac/ccextractor

echo "'$time' Plex DVR Postprocessing script started" | tee $dvrPostLog

# Check if post processing is already running
while [ -f $lockFile ]
do
    time=`date '+%Y-%m-%d %H:%M:%S'`
	echo "'$time' $lockFile' exists, sleeping processing of '$inFile'" | tee -a $dvrPostLog
	sleep 10
done

# Set the lock file. 
time=`date '+%Y-%m-%d %H:%M:%S'`
echo "'$time' Creating lock file for processing '$inFile'" | tee -a $dvrPostLog
touch $lockFile

# Run comcut to remove commercials. 
time=`date '+%Y-%m-%d %H:%M:%S'`
# Skip comcut for some news recordings where it doesn't matter or is unstable.  
if [[ $inFile == *"KPBS"* || $inFile == *"Las noticias"* ]]; then
	echo "'$time' This file does not require commercial markers. Skipping comchap." | tee -a $dvrPostLog
else # Otherwise run comcut to remove commercials. 
	echo "'$time' Comcut started on '$inFile'" | tee -a $dvrPostLog
	$cut --comskip-ini=$comskipIni --keep-edl "$inFile" 2>&1 | tee -a $dvrPostLog
fi

# After cutting the file, extract the subtitles as a .srt file
time=`date '+%Y-%m-%d %H:%M:%S'`
echo "'$time' Subtitle extraction started on '$inFile'" | tee -a $dvrPostLog
$cc "$inFile" -o "$tmpFileSrt" 2>&1 | tee -a $dvrPostLog

# Determine the video size so we can set an appropriate encoding bitrate for the output. 
videoSize=$($ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$1" | head -1)

echo $videoSize | tee -a $dvrPostLog
ffmpegOpts=""
if [[ $videoSize -ge 1080 ]]; then
    ffmpegOpts="-vf 'yadif=1:-1:1' -b:v 6000k"
elif [[ $videoSize -ge 720 ]]; then
    ffmpegOpts="-b:v 3000k"
else
	ffmpegOpts="-vf 'yadif=1:-1:1' -b:v 1500k"
fi

# Prep the final ffmpeg command to run the encode. 
if [ -f "$tmpFileSrt" ]; then
	# Quick and dirty language check so we can set the subtitle language in the .mkv file. 
	# Doing this by copying the language of the 1st audio track. It would be better to directly get the language of 
	# the closed captions, but I haven't figured that out. This is close enough, the closed captions are almost certainly in the language of the primary audio.
    progLang=$($ffprobe -v error -select_streams a -show_entries stream_tags=language -of default=nw=1:nk=1 "$1" | head -1)
    echo $progLang | tee -a $dvrPostLog
    ffmpegCmd="$ffmpeg -i \"$inFile\" -f srt -i \"$tmpFileSrt\" -map 0:0 -map 0:1 -map 1:0 -c:v hevc_videotoolbox $ffmpegOpts -c:a copy -c:s srt -metadata:s:s:0 language=$progLang \"$tmpFile\""
else 
    ffmpegCmd="$ffmpeg -i \"$inFile\" -c:v hevc_videotoolbox $ffmpegOpts -c:a copy \"$tmpFile\""
fi

# Now that we have all the necessary variables, run ffmpeg to encode to .mkv
time=`date '+%Y-%m-%d %H:%M:%S'`
echo "'$time' Transcoding started on '$inFile'" | tee -a $dvrPostLog 
echo $ffmpegCmd | tee -a $dvrPostLog
eval $ffmpegCmd 2>&1 | tee -a $dvrPostLog

# Overwrite original ts file with the transcoded file
time=`date '+%Y-%m-%d %H:%M:%S'`
echo "'$time' Remove .ts file" | tee -a $dvrPostLog
rm -f "$inFile"
rm -f "$tmpFileSrt"

#Remove lock file
time=`date '+%Y-%m-%d %H:%M:%S'`
echo "'$time' All done! Removing lock for '$inFile'" | tee -a $dvrPostLog
rm $lockFile

exit 0
