#!/usr/bin/env python3
# Truncate analyzed_screen.dart to 832 lines

path = r'D:\coding\youtube Down\youtube_downloder\lib\screens\analyzed_screen.dart'

# Read the file
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f'Total lines before: {len(lines)}')

# Write only the first 832 lines
with open(path, 'w', encoding='utf-8') as out:
    out.writelines(lines[:832])

print('Done, kept 832 lines')

# Verify
with open(path, 'r', encoding='utf-8') as f:
    verify_lines = f.readlines()

print(f'Total lines after: {len(verify_lines)}')
