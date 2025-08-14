# Make_Torrent

Directory for torrent-related scripts.

`Make_torrent.sh` ensures the `ctorrent` package is installed (using `apt` on
Debian 12) before creating a torrent file with `ctorrent`.

Usage:

```bash
./Make_torrent.sh /path/to/file_or_directory
```

The script invokes:

```bash
ctorrent -t -p -u "https://tracker.m-team.cc/" -s "/path/to/file_or_directory.torrent" /path/to/file_or_directory
```
