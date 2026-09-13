#!/usr/bin/env python3
import os
import re
import sys

def strip_comments(content):
    lines = content.split('\n')
    result = []
    in_block_comment = False
    in_string = False
    string_char = None
    in_template = False
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        
        # Keep shebang lines
        if stripped.startswith('#!'):
            result.append(line)
            continue
            
        # Skip if this line is entirely a block comment
        if in_block_comment:
            # Check if block comment ends
            idx = line.find('*/')
            if idx != -1:
                in_block_comment = False
                # Keep anything after */
                after = line[idx+2:].strip()
                if after:
                    result.append(after)
                else:
                    result.append('')
            else:
                result.append('')
            continue
        
        # Remove single-line block comments /* ... */
        # Be careful not to match URLs in strings
        processed = ''
        j = 0
        in_str = False
        str_char = None
        
        while j < len(line):
            char = line[j]
            
            # Handle string literals
            if not in_str and char in ('"', "'", '`'):
                in_str = True
                str_char = char
                processed += char
                j += 1
                continue
            
            if in_str:
                if char == '\\':
                    processed += char
                    if j + 1 < len(line):
                        processed += line[j+1]
                        j += 2
                    else:
                        j += 1
                    continue
                if char == str_char:
                    in_str = False
                    str_char = None
                processed += char
                j += 1
                continue
            
            # Check for block comment start
            if char == '/' and j + 1 < len(line) and line[j+1] == '*':
                # Find end of block comment
                end_idx = line.find('*/', j+2)
                if end_idx != -1:
                    # Single-line block comment, skip it
                    j = end_idx + 2
                    continue
                else:
                    # Multi-line block comment starts
                    in_block_comment = True
                    break
                continue
            
            # Check for line comment //
            if char == '/' and j + 1 < len(line) and line[j+1] == '/':
                # This is a line comment - skip the rest of the line
                break
            
            processed += char
            j += 1
        
        # Only add non-empty lines (to avoid leaving blank lines where comments were)
        if processed.strip():
            result.append(processed.rstrip())
        else:
            result.append('')
    
    # Remove consecutive blank lines (max 1)
    final = []
    prev_blank = False
    for line in result:
        is_blank = not line.strip()
        if is_blank and prev_blank:
            continue
        final.append(line)
        prev_blank = is_blank
    
    # Remove trailing blank lines
    while final and not final[-1].strip():
        final.pop()
    
    return '\n'.join(final) + '\n'

def process_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except:
        return False
    
    if not content:
        return False
    
    new_content = strip_comments(content)
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True
    return False

count = 0
for root, dirs, files in os.walk('src'):
    for fname in files:
        if fname.endswith('.ts'):
            fpath = os.path.join(root, fname)
            if process_file(fpath):
                count += 1
                print(f"  stripped: {fpath}")

print(f"\nDone. Processed {count} files.")
