# Couchbase Operator Functional Test

This project uses Terraform and Puppet to provision a fully functional Kubernetes cluster in AWS, install Couchbase Operator and run functional tests against the cluster.  The project is self contained in that it requires no packages above and beyond those installed by default on an Ubuntu image, which makes it well suited to operation in Jenkins as a CI job.

## Detail

This creates a 4 node Kubernetes cluster with a Flannel VXLAN overlay network.  Nodes are distrubuted across subnets in different availability zones within a VPC as depicted in the diagram.

![Cluster Topology](https://raw.githubusercontent.com/spjmurray/couchbase-operator-ci/master/images/vpc.png)

Nodes are secured with an ephemeral SSH key.  All APIs are secured via TLS (Docker uses ephemeral certificates, Kubernetes generates its own).  Nodes are accessible via public DNS which is presented via Terraform outputs.
