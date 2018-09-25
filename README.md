# Couchbase Operator Functional Test

This project uses kops to provision a fully functional Kubernetes cluster in AWS, install Couchbase Operator and run functional tests against the cluster.  The project is designed to run in a container so it does not interfere with your main development environment and cann be run in the background.

## Detail

This creates a 4 node Kubernetes cluster.  Nodes are distrubuted across subnets in different availability zones within a VPC as depicted in the diagram.

![Cluster Topology](https://raw.githubusercontent.com/spjmurray/couchbase-operator-ci/master/images/vpc.png)

Nodes are secured with an ephemeral SSH key.  All APIs are secured via TLS. Nodes are accessible via public DNS.

## Running

    docker run \
      --rm \
      --env DOCKER_API_KEY=${DOCKER_API_KEY} \
      --env AWS_REGION=us-east-1 \
      --env AWS_ACCESS_KEY=${AWS_ACCESS_KEY} \
      --env AWS_SECRET_KEY=${AWS_SECRET_KEY} \
      --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
      --mount type=bind,source=/home/simon/go/src/github.com/couchbase/couchbase-operator,target=/mnt/couchbase-operator,readonly \
      --group-add ${HOST_DOCKER_GID} \
      couchbase-operator-ci:0.0.1

### Recomended Options

<dl>
  <dt>--rm</dt>
  <dd>Clean the container up after exit</dd>

  <dt>--env</dt>
  <dd>Pass environment variables to the container.</dd>

  <dt>--mount</dt>
  <dd>The CI job needs to have access to docker and clone the repository so needs access to the local host file system.</dd>

  <dt>--group-add</dt>
  <dd>The container runs as non-root but needs to access the docker socket, so add the user to the host docker group.</dd>
</dl>

### Required Environment Variables

<dl>
  <dt>DOCKER_API_KEY</dt>
  <dd>API key associated with a docker account</dd>
</dl>

## Back Ends

Due to the plugable nature of the test framework we can support different cloud technologies.  Each has different configuration requirements via environment variables.

### aws

#### Required Environment Variables

<dl>
  <dt>AWS_REGION</dt>
  <dd>Which region to create the cluster in.  The backend will automatically poll availability zones and distribute the cluster across them</dd>

  <dt>AWS_ACCESS_KEY</dt>
  <dd>Your access key for AWS authentication </dd>

  <dt>AWS_SECRET_KEY</dt>
  <dd>Your secret key for AWS authentication</dd>
</dl>
