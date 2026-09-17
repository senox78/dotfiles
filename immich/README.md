# Immich recovery on Fedora

This stack is pinned to Immich `v3.1.0`, matching the backup:

`~/Downloads/immich-db-backup-20260916T210020-v3.1.0-pg16.15.sql.gz`

The existing assets stay at `/run/media/rei/hdd/immich`. The fresh Docker
database uses `/run/media/rei/ssd/immich-docker-v3.1.0/postgres`; the old
NixOS PostgreSQL directory is not reused or removed.

The server is initially exposed only at `http://127.0.0.1:2283`.

## Restore

1. Ensure both data disks are mounted read-write and Docker is running.
2. Copy `.env.example` to `.env` and replace `DB_PASSWORD` with a random
   alphanumeric password.
3. Start the fresh stack with `sudo docker compose up -d`.
4. Open `http://127.0.0.1:2283`, choose **Restore from backup**, upload the
   matching `.sql.gz` file, review the filesystem integrity checks, and restore.
5. Verify users, albums, original images, thumbnails, and videos before changing
   the version or removing any old data.

The media directory is mounted at both `/data` (the Docker default) and its old
NixOS absolute path. This preserves paths already stored in the restored DB.
