KS_VERSION ?= $(shell cat .kubespray-version)
INV ?= inventory/f5-bnk-cluster
KS_DIR ?= .deps/kubespray

all: doca dpu

.PHONY: doca
doca:
	source .venv/bin/activate && \
	ansible-playbook -i $(INV)/hosts.yaml extra_playbooks/install_doca.yml -b

.PHONY: dpu
dpu:
	@read -s -p "Bluefield-3 DPU set user ubuntu password (at least 12 characters): " pw; \
	export DPU_UBUNTU_PASSWORD=$$pw; \
	ansible-playbook -i inventory/f5-bnk-cluster/hosts.yaml \
		extra_playbooks/image_dpu.yml -b # -vv --check

.PHONY: cluster
cluster:
	./scripts/run-playbook.sh

.PHONY: clean-all
clean-all:
	./scripts/run-playbook.sh -p reset.yml
