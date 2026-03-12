#!/bin/bash

cd ~/projects/mess_cafe_automation_v1

git add .
git commit -m "Daily backup commit $(date)"
git push
