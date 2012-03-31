#!/bin/sh

pandoc -s -S --highlight-style=espresso -f markdown -t html5 -o readme.html readme.md
pandoc -s -S --highlight-style=espresso -f markdown -t epub -o readme.epub readme.md
