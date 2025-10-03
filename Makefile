KS_VERSION ?= $(shell cat .kubespray-version)
INV ?= inventory/f5-bnk-cluster
KS_DIR ?= .deps/kubespray

all: doca dpu cluster bnk bnk-gateway-class

.PHONY: doca
doca:
	source .venv/bin/activate && \
	ansible-playbook -i $(INV)/hosts.yaml extra_playbooks/install-doca.yml -b

.PHONY: dpu
dpu:
	@read -s -p "Bluefield-3 DPU set user ubuntu password (at least 12 characters): " pw; \
	export DPU_UBUNTU_PASSWORD=$$pw; \
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/image-dpu.yml -b # -vv --check

.PHONY: cluster
cluster:
	./scripts/run-playbook.sh

.PHONY: sriov
sriov:
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/sriov.yml

.PHONY: local-path-provisioner
local-path-provisioner:
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/local-path-provisioner.yml

.PHONY: nfs-csi
nfs-csi:
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
	  extra_playbooks/nfs-csi.yml

.PHONY: nfs-storageclass
nfs-storageclass:
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/nfs-storageclass.yml

.PHONY: cert-manager
cert-manager:
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/cert-manager.yml

.PHONY: grafana
grafana:
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/grafana.yml

.PHONY: bnk
bnk: sriov local-path-provisioner nfs-csi nfs-storageclass cert-manager grafana bnk
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/bnk.yml

.PHONY: bnk-gateway-class
bnk-gateway-class:
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/bnk-gateway-class.yml

.PHONY: clean-bnk
clean-bnk:
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/clean-bnk.yml

.PHONY: clean-all
clean-all:
	./scripts/run-playbook.sh -p reset.yml
