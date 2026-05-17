#!/usr/bin/env python3

import os
import hashlib
import sqlite3
import time
from pathlib import Path

DB_FILE = '/tmp/image_duplicates.db'
LOG_FILE = f'/tmp/duplicate_images_{int(time.time())}.log'

# Initialize database
def init_db():
    if os.path.exists(DB_FILE):
        os.remove(DB_FILE)
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS images (
        id INTEGER PRIMARY KEY,
        path TEXT,
        filename TEXT,
        extension TEXT,
        md5 TEXT
    )''')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_md5 ON images(md5)')
    conn.commit()
    return conn

# Calculate MD5 hash of a file
def calculate_md5(filepath):
    hash_md5 = hashlib.md5()
    try:
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    except Exception as e:
        print(f'Error calculating MD5 for {filepath}: {e}')
        return None

# Recursively scan directory
def scan_directory(top_dir, conn):
    cursor = conn.cursor()
    valid_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp', '.arw', '.psd', '.nef', '.dng']
    batch = []
    total_committed = 0
    for root, _, files in os.walk(top_dir):
        for file in files:
            ext = os.path.splitext(file)[1].lower()
            if ext in valid_extensions:
                filepath = os.path.join(root, file)
                print(f'Processing: {filepath}')
                md5 = calculate_md5(filepath)
                if md5:
                    batch.append((root, file, ext, md5))
                    if len(batch) >= 50:
                        cursor.executemany('INSERT INTO images (path, filename, extension, md5) VALUES (?, ?, ?, ?)', batch)
                        conn.commit()
                        total_committed += len(batch)
                        print(f'Committed batch of {len(batch)} files (Total: {total_committed})')
                        batch = []
    if batch:
        cursor.executemany('INSERT INTO images (path, filename, extension, md5) VALUES (?, ?, ?, ?)', batch)
        conn.commit()
        total_committed += len(batch)
        print(f'Committed final batch of {len(batch)} files (Total: {total_committed})')

# Find duplicates
def find_duplicates(conn):
    cursor = conn.cursor()
    cursor.execute('SELECT md5 FROM images GROUP BY md5 HAVING COUNT(*) > 1')
    return [row[0] for row in cursor.fetchall()]

# Delete duplicates with safeguards
def delete_duplicates(duplicate_md5s, conn, dry_run=False):
    deleted_count = 0
    cursor = conn.cursor()
    with open(LOG_FILE, 'a') as log:
        log.write(f"DRY RUN: {dry_run}\n") 
        log.flush()
        for md5 in duplicate_md5s:
            cursor.execute('SELECT path, filename FROM images WHERE md5 = ?', (md5,))
            files = cursor.fetchall()

            if len(files) <= 1:
                continue

            files.sort(key=lambda x: len(x[1]))
            keep = files[0]
            to_delete = files[1:]

            keep_path = os.path.join(keep[0], keep[1])
            if not os.path.exists(keep_path):
                message = f'ERROR: MISSING KEEP FILE — POTENTIAL DATA LOSS — Skipping MD5 {md5}: {keep_path}'
                print(message)
                log.write(f"{message}\n")
                continue

            print("----")
            log.write("----\n")
            print(f"MD5: {md5}, Duplicates: {len(files) - 1}")
            log.write(f"MD5: {md5}, Duplicates: {len(files) - 1}\n")
            print(f"keep: {keep_path}")
            log.write(f"keep: {keep_path}\n")

            for path, filename in to_delete:
                full_path = os.path.join(path, filename)
                print(f"delete: {full_path}")
                log.write(f"delete: {full_path}\n")
                if not dry_run:
                    try:
                        os.remove(full_path)
                        deleted_count += 1
                        print(f'Deleted: {full_path}')
                        cursor.execute('DELETE FROM images WHERE path = ? AND filename = ?', (path, filename))
                        conn.commit()
                    except Exception as e:
                        print(f'Error deleting {full_path}: {e}')
                        log.write(f"Error deleting {full_path}: {e}\n")
    return deleted_count

# Main function
if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Find and delete duplicate image files')
    parser.add_argument('directory', help='Top level directory to scan')
    parser.add_argument('--dry-run', action='store_true', help='Perform a dry run without deleting files')
    args = parser.parse_args()

    conn = init_db()

    # Initialize log file early so it's visible and tailable
    with open(LOG_FILE, 'w') as log:
        log.write(f"Log initialized at {time.ctime()}")
        log.flush()
    print(f'Log file will be written to: {LOG_FILE}')
    scan_directory(args.directory, conn)
    duplicate_md5s = find_duplicates(conn)

    deleted_count = 0
    if not duplicate_md5s:
        print('No duplicates found')
    else:
        print(f'Duplicates logged to {LOG_FILE}')
        auto_delete = input('Delete all duplicates automatically? (y/n): ').strip().lower()

        if auto_delete == 'y':
            deleted_count = delete_duplicates(duplicate_md5s, conn, dry_run=args.dry_run)
        else:
            for md5 in duplicate_md5s:
                cursor = conn.cursor()
                cursor.execute('SELECT path, filename FROM images WHERE md5 = ?', (md5,))
                files = cursor.fetchall()
                print(f'MD5: {md5}, Files: {len(files)}')
                delete = input('Delete duplicates? (y/n/skip): ').strip().lower()
                if delete == 'y':
                    deleted_count += delete_duplicates([md5], conn, dry_run=args.dry_run)
                print(f'Remaining duplicate sets: {len(duplicate_md5s)}')

    conn.close()
    print(f'Deletion complete. {deleted_count} files deleted.')
    print(f'Log file saved to: {LOG_FILE}')
    if os.path.exists(DB_FILE):
        os.remove(DB_FILE)

