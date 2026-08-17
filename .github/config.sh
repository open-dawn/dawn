#! /bin/bash
echo "~ Preparing git local config"
git config --local commit.template .github/.gitmessage
git config --local pull.rebase true
git config --local commit.gpgsign true
