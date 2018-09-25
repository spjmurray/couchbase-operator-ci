.PHONY: all
all:
	docker build . -t couchbase-operator-ci:0.0.1
