.PHONY: all
all:
	docker build . -t spjmurray/couchbase-operator-ci:0.0.1
