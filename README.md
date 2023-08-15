# Pasta - Automated Torrent Extraction Script

      ▄▄▄· ▄▄▄· .▄▄ · ▄▄▄▄▄ ▄▄▄· 
     ▐█ ▄█▐█ ▀█ ▐█ ▀. •██  ▐█ ▀█ 
      ██▀·▄█▀▀█ ▄▀▀▀█▄ ▐█.▪▄█▀▀█ 
     ▐█▪·•▐█ ▪▐▌▐█▄▪▐█ ▐█▌·▐█ ▪▐▌
     .▀    ▀  ▀  ▀▀▀▀  ▀▀▀  ▀  ▀

**Pasta** is a versatile and powerful bash script designed to automate extracting torrent archives (*.rar). This script was designed to work
with the Transmission Bittorrent client as a post-download archive extractor. 

## Features

- Batch extraction for convenience.
- Customizable exclusion of unwanted directories.
- Support for RAR file format.
- Automatic logging of activities.
- Interactive and silent modes.
- Flexible configuration through command line options.

## Integration with Transmission

Make sure to stop the transmission daemon and then edit the `"settings.json"` file:

```json
"script-torrent-done-enabled": true, 
"script-torrent-done-filename": "/data/transmission-data/scripts/pasta.sh",
```
Note: Please don't include command line options when using the script with transmission.

Use the absolute path based on your installation, and make sure to make the script executable
and have the appropriate ownership permissions:

```bash
chmod 755 /data/transmission-data/scripts/pasta.sh
```

## Usage

You can use this script to batch process your archived torrents from the command line
or configure it to run automatically after a torrent is moved to the transmission completed directory.

```bash
./pasta.sh [-v] [-b] [-h]

-v: Enable verbose mode to display detailed output.
-b: Enable batch processing to process all eligible directories.
-h: Display the help message and usage instructions.
```
## Note for New Users
- To customize the behavior of the script, you can modify the values of the configuration variables at the beginning of the script. Be cautious when changing these values, as incorrect settings may lead to unexpected behavior.
- When configuring `EXCLUDED_DIRS`, provide the exact names of directories you want to exclude from processing.
- Before using this script, please ensure you have set up the required dependencies and paths according to your system's configuration.

## Configuration Variables

#### P_BATCH
- Default Value: `false`
- Description: Determines whether the script will process torrents in batch mode. If set to `true`, the script will process all torrents in the specified directory.

#### EXCLUDED_DIRS
- Default Value: `"anime" "misc" "backups"`
- Description: A list of directory names you want the script to exclude when processing torrents. Wildcards are not supported, and you should provide the exact names of the directories you want to exclude.

#### COMPLETED_DIR
- Default Value: `"/data/completed"`
- Description: The base directory where the script will search for completed torrents to process. All subdirectories under this path will be scanned for torrent archives.

#### MIN_FILE_AGE
- Default Value: `900` (15 minutes in seconds)
- Description: The minimum age (in seconds) that a torrent directory needs to be before the script considers processing it. Torrents younger than this value will be skipped.

#### REMOVE_RAR_FILES
- Default Value: `false`
- Description: Determines whether the script will remove the extracted RAR files after processing. Set to `true` if you want to remove these files.

#### LOG_DIR and LOG_FILE
- Default Value for LOG_DIR: `"/data/transmission-home"`
- Default Value for LOG_FILE: `"${LOG_DIR}"/pasta.log`
- Description: `LOG_DIR` specifies the directory where the log file will be stored. `LOG_FILE` specifies the full path to the log file. Modify `LOG_DIR` to your desired log directory path.

#### VERBOSE
- Default Value: `false`
- Description: If set to `true`, the script will display more detailed information during processing. Set to `false` by default.






