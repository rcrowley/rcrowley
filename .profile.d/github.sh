# Create a new gh-pages branch.
alias make-gh-pages="git symbolic-ref HEAD refs/heads/gh-pages && rm .git/index && git clean -fdx"
