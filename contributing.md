# Hello potential and real Kansa contributors!

Thanks for your interest in improving Kansa. This doc is meant to 
serve as a rough guideline for potential contributors to the project.
With a hat tip to the Metasploit project, from which some of these
ideas came.

# Contributing to Kansa

## Code Contributions

* **Do** follow the [50/72 rule] 
(http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html) 
for Git Commit messages
* **Do** fork the main repo via github, click the fork button
* **Do** clone your forked repo to your local system using the 
`git clone` command followed by something like 
git@github.com:username/Kansa.git
* **Do** track the remote upstream branch, from your local repo
do this:
`git remote add upstream git@github.com:davehull/Kansa.git`
then do this: `git remote -v` and make sure you have origin 
tracking your fork and upstream tracking against the original
repo.
* **Do** create a [topic branch] from within your local clone of 
your fork from the command line interface in your local system, 
this may look like the following sequence of commands:
`git branch` are you on master? That's a good starting point.
If you're on master, you can make sure your master is up to date by
doing: `git pull upstream master --rebase`. In general, you want to
make any changes to your local repo using feature branches. So after
getting your local master up to date, create a new feature branch by
doing: `git checkout -b <featurename>`, which will create a new
branch. Once you're in that branch, you can start coding up your
feature or change. Once you are done, do the normal `git add`, and
`git commit` process, then when you go to `git push`, git will tell
you what to do, follow the prompt. Once you've pushed to your origin,
open your web browser and use the git web interface to open a PR
against master. There's no dev branch, that's for suckers. Kansa's
admins will merge your changes from master down to a release branch.

### Pull Requests

* **Do** target your pull request to the **master branch**. Not next, not
release.
* **Do** specify a descriptive title to make searching for your pull 
request easier.
* **Do** keep your pull requests small, fixes should be tightly coupled.
* **Don't** leave your pull request description blank.
* **Don't** abandon your pull request. Being responsive helps us land your 
code faster.

#### Coding Style
* **Do** error on the side of verbosity rather than compactness, avoid 
aliases.
* **Do** fix bugs in (your) existing code, before writing anything new.
You aren't expected to fix other people's bugs, but you can if you want.

#### New Modules
* **Do** make your module return Powershell objects.
* **Do** allow your modules to return error messages, unless you've 
written code to handle them specifically. In general, if something 
goes wrong, user's want to know about it.
* **Do** try to avoid XML as an output, it greatly [complicates
analysis and is slow.] (http://www.joelonsoftware.com/articles/fog0000000319.html)

#### Analysis Scripts
* **Nothing here yet**

#### Issues
* **Do** follow the convention of titling new issues based on where the issue is
* "Kansa Core: Issue description" -- the issue is in Kansa.ps1
* "Kansa Module: <ModuleName> issue description" -- the issue is in ModuleName
* "Kansa Analysis: <AnalysisScript> issue description" -- issue is in AnalysisScript

**Thank you** for your interest in Kansa and for reading to this point in the doc.
You're well on your way to making awesome contributions to the project!