# plex-postprocessing
A post-processing script for Plex Recordings to cut commercials, compress, and add subtitles. 

Requires [ffmpeg](https://ffmpeg.org/download.html), [ccextractor](https://github.com/CCExtractor/ccextractor), [comskip](https://github.com/erikkaashoek/Comskip), and [comchap](https://github.com/BrettSheleski/comchap)

The script sets up a lock file so only one processing request goes through at a time to prevent overloading the computer.

Then, using Comskip and comchap, looks for commercials and removes them.

Once that is done, the script uses ccextractor to pull the closed captions and save them as a .srt file.

Finally, the script uses ffmpeg to compress into an h265 mkv and embeds the subtitles that were pulled using ccextractor into the mkv. The h265 video bitrate is set higher or lower depending on the recording's original resolution. 

At the very end, removes all temporary files created by the script. Plex takes care of moving the processed recording.

The script can be used by updating the #Files and #External Tools sections with your own paths. Make sure to save the script in the location specified by Plex in [it's documentation](https://support.plex.tv/articles/225877347-live-tv-dvr/). 
