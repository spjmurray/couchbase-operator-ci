FROM ubuntu:bionic

# Set some default variables
ENV user couchbase-operator-ci
ENV kops_version 1.9.1
ENV kube_version 1.10.0
ENV glide_version 0.13.1

# Install packages if we can
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    ansible \
    awscli \
    docker.io \
    git \
    golang \
    make \
    python \
    python-boto3 \
    python-configparser \
    python-pip \
    python-testtools \
  && apt-get clean

# Install modern versions of python dependencies
RUN pip install kubernetes==6.0.0

# Install glide, kubectl and kops
RUN wget -q -O- https://github.com/Masterminds/glide/releases/download/v${glide_version}/glide-v${glide_version}-linux-amd64.tar.gz | tar -xzf - -C /tmp \
  && cp /tmp/linux-amd64/glide /usr/local/bin \
  && wget -q -O /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${kube_version}/bin/linux/amd64/kubectl \
  && chmod +x /usr/local/bin/kubectl \
  && wget -q -O /usr/local/bin/kops https://github.com/kubernetes/kops/releases/download/${kops_version}/kops-linux-amd64 \
  && chmod +x /usr/local/bin/kops

# Install tco
RUN git clone http://github.com/spjmurray/tco \
  && cd tco \
  && make install

# Add a user to run under
RUN useradd -m -s /bin/bash ${user}
USER ${user}

# Add the test script
COPY ci /usr/local/bin/

# Run the script
CMD ["/usr/local/bin/ci"]
