package main

import (
	"flag"
	"fmt"
	"github.com/rcrowley/go-metrics"
	"github.com/rcrowley/go-tigertonic"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path"
	"time"
)

var (
	cert   = flag.String("cert", "", "certificate pathname")
	key    = flag.String("key", "", "private key pathname")
	listen = flag.String("listen", ":80", "listen address")

	mux  *tigertonic.TrieServeMux
	hMux tigertonic.HostServeMux
)

func init() {
	flag.Usage = usage
	log.SetFlags(log.Ltime | log.Lmicroseconds | log.Lshortfile)
	mux = tigertonic.NewTrieServeMux()
	mux.HandleNamespace(
		"",
		tigertonic.Timed(
			tigertonic.First(
				http.HandlerFunc(tryHTML),
				http.FileServer(http.Dir("var/www")),
			),
			"rcrowley.org",
			nil,
		),
	)
	mux.Handle(
		"GET",
		"/metrics.json",
		tigertonic.Timed(
			tigertonic.Marshaled(metricsJSON),
			"GET-metrics-json",
			nil,
		),
	)
	mux.Handle(
		"GET",
		"/pinboard.xml",
		tigertonic.Timed(
			http.HandlerFunc(pinboardXML),
			"GET-pinboard-xml",
			nil,
		),
	)
	hMux = tigertonic.NewHostServeMux()
	hMux.Handle(
		"arch.rcrowley.org",
		tigertonic.Timed(
			http.FileServer(http.Dir("var/www/arch")),
			"arch.rcrowley.org",
			nil,
		),
	)
	hMux.Handle(
		"packages.devstructure.com",
		tigertonic.Timed(
			http.FileServer(http.Dir("var/cache/freight")),
			"packages.devstructure.com",
			nil,
		),
	)
	hMux.Handle(
		"packages.rcrowley.org",
		tigertonic.Timed(
			http.FileServer(http.Dir("var/cache/freight")),
			"packages.rcrowley.org",
			nil,
		),
	)
	hMux.Handle("rcrowley.org", mux)
	hMux.Handle("127.0.0.1:48879", mux) // For development convenience.
}

func main() {
	flag.Parse()
	server := tigertonic.NewServer(*listen, tigertonic.ApacheLogged(hMux))
	server.WriteTimeout = time.Hour
	var err error
	if "" != *cert && "" != *key {
		err = server.ListenAndServeTLS(*cert, *key)
	} else {
		err = server.ListenAndServe()
	}
	if nil != err {
		log.Fatalln(err)
	}
}

func metricsJSON(*url.URL, http.Header, interface{}) (int, http.Header, metrics.Registry, error) {
	return http.StatusOK, nil, metrics.DefaultRegistry, nil
}

func pinboardXML(w http.ResponseWriter, r *http.Request) {
	res, err := http.Get("http://feeds.pinboard.in/rss/u:rcrowley")
	if nil != err {
		goto Error
	}
	defer res.Body.Close()
	if _, err := io.Copy(w, res.Body); nil != err {
		goto Error
	}
	return
Error:
	w.Header().Set("Content-Type", "text/xml; charset=utf-8")
	w.WriteHeader(http.StatusInternalServerError)
	w.Write([]byte("<?xml version=\"1.0\"?>\n<xml/>\n"))
}

func tryHTML(w http.ResponseWriter, r *http.Request) {
	pathname := path.Clean(path.Join(
		"var/www",
		fmt.Sprintf("%s.html", r.URL.Path),
	))
	if _, err := os.Stat(pathname); nil != err {
		return
	}
	http.ServeFile(w, r, pathname)
}

func usage() {
	fmt.Fprintln(
		os.Stderr,
		"Usage: www [-cert=<cert>] [-key=<key>] [-listen=<listen>]",
	)
	flag.PrintDefaults()
}
