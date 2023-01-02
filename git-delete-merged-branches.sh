#!/bin/sh
git branch --merged >/tmp/merged-branches && nvim /tmp/merged-branches && xargs git branch -d </tmp/merged-branches

