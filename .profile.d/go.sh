export GOPATH="$HOME"
if [ -d "/usr/go" ]
then export GOROOT="/usr/go"
elif [ -d "/usr/lib/go" ]
then export GOROOT="/usr/lib/go"
fi
if [ -d "/usr/go/bin" ]
then export PATH="$PATH:/usr/go/bin"
fi
