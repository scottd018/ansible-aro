.DEFAULT_GOAL := help

CLUSTER_NAME ?= ans-$(shell whoami)
RESOURCE_GROUP ?= ans-$(shell whoami)-rg
EXTRA_VARS ?= --extra-vars "azr_aro_cluster=$(CLUSTER_NAME) azr_resource_group=$(RESOURCE_GROUP)"

VIRTUALENV ?= "./virtualenv/"
ANSIBLE = $(VIRTUALENV)/bin/ansible-playbook $(EXTRA_VARS)

.PHONY: help
help:
	@echo GLHF

.PHONY: virtualenv
virtualenv:
	LC_ALL=en_US.UTF-8 python3 -m venv $(VIRTUALENV)
	. $(VIRTUALENV)/bin/activate
	pip install pip --upgrade
	LC_ALL=en_US.UTF-8 ./virtualenv/bin/pip3 install -r requirements/python.txt
	./virtualenv/bin/ansible-galaxy collection install azure.azcollection --force
	./virtualenv/bin/pip3 install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements-azure.txt
	./virtualenv/bin/ansible-galaxy collection install community.okd

#
# DOCKER IMAGE BUILDS
#
VERSION ?= latest
docker.image:
	docker build -t quay.io/mobb/ansible-aro:$(VERSION) .

docker.image.push:
	docker push quay.io/mobb/ansible-aro:$(VERSION)

docker.image.pull:
	docker pull quay.io/mobb/ansible-aro:$(VERSION)

#
# ANSIBLE PLAYBOOK RUNS
#
create:
	$(ANSIBLE) -v create-cluster.yaml

ARO_PULL_SECRET ?= $(HOME)/.azure/aro-pull-secret.txt
docker.create:
	docker run --rm \
		-v $(ARO_PULL_SECRET):/home/ansible/aro-pull-secret.txt \
		-v $(HOME)/.azure:/home/ansible/.azure \
	  	-ti quay.io/mobb/ansible-aro:$(VERSION) \
		$(ANSIBLE) -v -e azr_aro_pull_secret=/home/ansible/aro-pull-secret.txt \
			create-cluster.yaml

delete:
	$(ANSIBLE) -v delete-cluster.yaml

docker.delete:
	docker run --rm \
		-v $(ARO_PULL_SECRET):/home/ansible/aro-pull-secret.txt \
		-v $(HOME)/.azure:/home/ansible/.azure \
	  	-ti quay.io/mobb/ansible-aro:$(VERSION) \
		$(ANSIBLE) -v delete-cluster.yaml

create.private:
	$(ANSIBLE) -v create-cluster.yaml -i ./environment/private/hosts

delete.private:
	$(ANSIBLE) -v delete-cluster.yaml -i ./environment/private/hosts

create.mobb-infra-aro:
	$(ANSIBLE) -v create-cluster.yaml -i ../mobb-infra/aro/hosts

pull-secret:
	$(ANSIBLE) -v pull-secret.yaml

docker.pull-secret:
	docker run --rm \
		-v $(ARO_PULL_SECRET):/home/ansible/aro-pull-secret.txt \
		-v $(HOME)/.azure:/home/ansible/.azure \
	  	-ti quay.io/mobb/ansible-aro:$(VERSION) \
		$(ANSIBLE) -v pull-secret.yaml
