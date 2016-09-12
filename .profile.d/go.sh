if [ -d "/usr/local/go" ]
then export GOROOT="/usr/local/go" PATH="/usr/local/go/bin:$PATH"
elif [ -d "/usr/go" ]
then export GOROOT="/usr/go" PATH="/usr/go/bin:$PATH"
fi
export GOPATH="$HOME"
