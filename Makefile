S_VERSION ?= $(shell cat .kubespray-version)
INV ?= inventory/2node-static-ip
#INV ?= inventory/f5-bnk-cluster
KS_DIR ?= .deps/kubespray
SHELL := /bin/bash

VENV ?= .venv
PLAYBOOKS ?= extra_playbooks

ANSIBLE_PLAYBOOK := $(VENV)/bin/ansible-playbook

# Helper macro: $(call ap,<playbook>,<extra args>)
define ap
	$(ANSIBLE_PLAYBOOK) -i $(INV)/hosts.yaml $(PLAYBOOKS)/$(1) $(2)
endef

all: cluster nvidia-gpu-operator bnk cne-instance

.PHONY: doca
doca:
	$(call ap,install-doca.yml,-b)

.PHONY: dpu
dpu:
	@read -p "Bluefield-3 DPU set user ubuntu password (at least 12 characters): " pw; \
	export DPU_UBUNTU_PASSWORD=$$pw; \
	$(call ap,image-dpu.yml,-b) # -vv --check

.PHONY: cluster
cluster:
	./scripts/run-playbook.sh
	./scripts/kubeconfig.sh

.PHONY: sriov
sriov:
	$(call ap,sriov.yml,)

.PHONY: local-path-provisioner
local-path-provisioner:
	$(call ap,local-path-provisioner.yml,)

.PHONY: nfs-csi
nfs-csi:
	$(call ap,nfs-csi.yml,)

.PHONY: nfs-storageclass
nfs-storageclass:
	$(call ap,nfs-storageclass.yml,)

.PHONY: cert-manager
cert-manager:
	$(call ap,cert-manager.yml,)

.PHONY: grafana
grafana:
	$(call ap,grafana.yml,)

.PHONY: bnk
bnk: sriov local-path-provisioner nfs-csi nfs-storageclass cert-manager grafana
	$(call ap,bnk.yml,)

.PHONY: cne-instance
cne-instance:
	$(call ap,cne-instance.yml,)

.PHONY: nvidia-gpu-operator
nvidia-gpu-operator:
	helm repo add nvidia https://nvidia.github.io/gpu-operator --force-update
	helm repo update
	helm upgrade --install --namespace gpu-operator --create-namespace \
		gpu-operator nvidia/gpu-operator

.PHONY: clean
clean:
	@echo "removing bnk gateway class ..."
	$(call ap,clean-bnk.yml,)

.PHONY: clean-all
clean-all:
	./scripts/run-playbook.sh -p reset.yml
