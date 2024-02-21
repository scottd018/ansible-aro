#
# BUILD IMAGE
#
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3-1552 as build

ENV HOME=/home/ansible

# install required build packages
RUN microdnf --setopt=install_weak_deps=0 --nodocs -y install \
        bash \
        gcc \
        libffi-devel \
        git \
        gpgme-devel \
        libxml2-devel \
        libxslt-devel \
        curl-minimal \
        cargo \
        openssl-devel \
        python3-devel \
        cmake \
        gcc-c++ \
        unzip && \
    microdnf clean all

# copy content
COPY . ${HOME}

# add python dependencies
RUN python3 -m venv ${HOME}/virtualenv && \
    ${HOME}/virtualenv/bin/python3 -m pip install --upgrade pip && \
    ${HOME}/virtualenv/bin/pip3 install --no-cache-dir -r ${HOME}/requirements/python.txt

# add ansible collection dependencies
RUN ${HOME}/virtualenv/bin/ansible-galaxy collection install --force -r ${HOME}/requirements/ansible.yaml && \
    ${HOME}/virtualenv/bin/pip3 install --no-cache-dir -r ${HOME}/.ansible/collections/ansible_collections/azure/azcollection/requirements-azure.txt

#
# RUNTIME IMAGE
#
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3-1552

ENV HOME=/home/ansible

# install required runtime packages
        # unzip \
        # glibc \
RUN microdnf --setopt=install_weak_deps=0 --nodocs -y install \
        bash \
        openssl \
        shadow-utils \
        python3 && \
    microdnf clean all

# configure runtime user
RUN groupadd ansible --g 1000 && useradd -s /bin/bash -g ansible -u 1000 ansible -d ${HOME}
USER ansible:ansible

# copy content to container
COPY --chown=ansible:ansible . ${HOME}
COPY --chown=ansible:ansible --from=build ${HOME} ${HOME}

# set kubeconfig and ansible options
ENV KUBECONFIG=${HOME}/staging/.kube/config
ENV ANSIBLE_FORCE_COLOR=1

WORKDIR ${HOME}
