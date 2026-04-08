# generic-template-repository

Template repository that has some basic github actions for checking commits and an example release/build task. 

# Create a DevOps ticket

- Create a DevOps ticket to request the new repo with an explaination of what it will be used for.
- Ping @chrisfinix  to approve the new repo.

# Setup your repo. 
Before getting started update your repository settings and protect your main branch.

## Update Features Settings

- Disable Wikis
- Disable Issues
- Disable Projects

## Update Pull Requests Settings

Majority of team's gitflows is to only allow rebase merging.

- Disable "Allow merge commits"
- Disable "Allow squash merging"
- Enable "Automatically delete head branches"

## Create a branch protection rule for main

- Under Code and Automation -> Branches
- Select "Add classic branch protection rule"
- Branch name "main"
- Enable Require a pull request before merging
- Enable Require approvals
- Enable Require status checks to pass before merging
- Search for "pr-commits" in the status check search bar and select "pr-commits / Validate PR Commit Messages"
- Enable Do not allow bypassing the above settings

## Code best practices
- If you're going to use jooq, make sure you add a [commit](https://github.com/finix-payments/processing/pull/8987/commits/f98a479b4e03329c79a89679540e452f35292ca7) similar to this to block the use the .asterisk() method. 

## Cleanup this readme
Test that everything is working by creating a pull request to delete the setup steps from this readme and verify checks are running, and all the settings are correct. 
