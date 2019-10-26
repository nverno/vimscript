#!/usr/bin/env python
#
# Dump vim keywords as lisp assoc list
# 
# modified from:
# https://bitbucket.org/birkenfeld/pygments-main/src/default/scripts/get_vimkw.py
import re

VIM_VERSION = "80"

r_line = re.compile(r"^(syn keyword vimCommand contained|syn keyword vimOption "
                    r"contained|syn keyword vimAutoEvent contained)\s+(.*)")
r_item = re.compile(r"(\w+)(?:\[(\w+)\])?")

def getkw(input, output):
    out = open(output, 'w')
    output_info = {'command': [], 'option': [], 'auto': []}

    with open(input, 'r') as f:
        for line in f:
            m = r_line.match(line)
            if m:
                # decide which output gets mapped to d
                if 'vimCommand' in m.group(1):
                    d = output_info['command']
                elif 'AutoEvent' in m.group(1):
                    d = output_info['auto']
                else:
                    d = output_info['option']

                # Extract all the shortened versions
                for i in r_item.finditer(m.group(2)):
                    d.append((i.group(1), "%s%s" % (i.group(1), i.group(2) or '')))

    output_info['option'].append(("nnoremap","nnoremap"))
    output_info['option'].append(("inoremap","inoremap"))
    output_info['option'].append(("vnoremap","vnoremap"))

    print("(", file=out)
    for key, keywordlist in output_info.items():
        keywordlist.sort()
        print("(", key, file=out)
        for a, b in keywordlist:
            print(f'("{a}" "{b}")', file=out)
        print(")", file=out)
    print(")", file=out)
    
    out.close()

def is_keyword(w, keywords):
    for i in range(len(w), 0, -1):
        if w[:i] in keywords:
            return keywords[w[:i]][:len(w)] == w
    return False

if __name__ == "__main__":
    getkw("/usr/share/vim/vim%s/syntax/vim.vim" % VIM_VERSION, "vim_builtins.txt")
