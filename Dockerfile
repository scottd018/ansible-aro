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
        python3-pip \
        cmake \
        gcc-c++ \
        unzip && \
    microdnf clean all

# copy content
COPY . ${HOME}

# add python dependencies
RUN python3 -m pip install --upgrade pip && \
        pip3 install --no-cache-dir -r ${HOME}/requirements/python.txt

# add ansible collection dependencies
RUN ansible-galaxy collection install --force -r ${HOME}/requirements/ansible.yaml && \
        pip3 install --no-cache-dir -r ${HOME}/.ansible/collections/ansible_collections/azure/azcollection/requirements-azure.txt

#
# SYSTEM IMAGE
#   NOTE: this layer lets us configure the system here and copy into a micro install for runtime
#
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.3-1552 as system
ENV HOME=/home/ansible
ENV MICRODNF_OPTS="--config=/etc/dnf/dnf.conf \
    --setopt=install_weak_deps=0 \
    --setopt=cachedir=/var/cache/microdnf \
    --setopt=reposdir=/etc/yum.repos.d \
    --setopt=varsdir=/etc/dnf \
    --releasever=9 \
    --installroot=${HOME}/system \
    --nodocs \
    --noplugins \
    --best \
    --refresh"

# install packages to system root
RUN mkdir -p ${HOME}/system
RUN microdnf -y install ${MICRODNF_OPTS} \
        bash \
        openssl \
        shadow-utils \
        python3 && \
    microdnf clean all ${MICRODNF_OPTS}

# configure runtime user
RUN chroot ${HOME}/system \
        /bin/bash -c "groupadd ansible -g 1000 && useradd -s /bin/bash -g ansible -u 1000 ansible -d ${HOME}"

# remove packages that are not needed at runtime
RUN microdnf -y remove ${MICRODNF_OPTS} \
        shadow-utils && \
    microdnf clean all ${MICRODNF_OPTS}

#
# RUNTIME IMAGE
#
FROM registry.access.redhat.com/ubi9/ubi-micro:9.3-13
ENV HOME=/home/ansible

# copy content to container
COPY --from=system ${HOME}/system /
COPY --chown=ansible:ansible --from=build ${HOME} ${HOME}
COPY --from=build /usr/local/lib/python3.9 /usr/local/lib/python3.9
COPY --from=build /usr/local/lib64/python3.9 /usr/local/lib64/python3.9
COPY --from=build /usr/local/bin /usr/local/bin

# set kubeconfig and ansible options
ENV KUBECONFIG=${HOME}/staging/.kube/config
ENV ANSIBLE_FORCE_COLOR=1

WORKDIR ${HOME}
