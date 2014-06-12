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
* **Do** create a [topic branch] 
(http://git-scm.com/book/en/Git-Branching-Branching-Workflows#Topic-Branches) 
to work on instead of working directly on `master`.

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
* **Do** try to make your module return Powershell objects.
* **Do** specify an # OUTPUT directive on line one of your module.
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