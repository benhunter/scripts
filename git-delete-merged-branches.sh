#!/bin/sh
git branch --merged | grep -v "^\(\* \)\?main$" > /tmp/merged-branches && nvim /tmp/merged-branches && xargs git branch -d </tmp/merged-branches

