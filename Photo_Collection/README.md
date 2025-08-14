
This directory stores photo collection files.

# Photo Collection

This directory stores photo archives downloaded via `ph_cl.sh`.

## Usage

1. Prepare a text file where each line is a direct download link.

2. Run the script from this directory, passing the list file and a target folder name:
   ```bash
   bash ph_cl.sh urls.txt MyAlbum
   ```
   The script downloads each file into `MyAlbum` and extracts any ZIP or RAR archives.

2. Run the script, specifying that file and a target directory name:
   ```bash
   bash ../ph_cl.sh urls.txt Photo_Collection
   ```
   The script downloads each file into the directory and extracts any ZIP or RAR archives.


If an archive unpacks files directly, the script creates a folder named after the archive to keep things tidy.
