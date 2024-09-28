.PHONY: main
main:
	ansible-playbook -i ansible/inventory.yaml ansible/playbooks/main.yaml

.PHONY: maintenance
maintenance:
	ansible-playbook -i ansible/inventory.yaml ansible/playbooks/maintenance.yaml

.PHONY: upgrade-cluster
upgrade-cluster:
	ansible-playbook -i ansible/inventory.yaml ansible/playbooks/upgrade-cluster.yaml

.PHONY: nuke-cluster
nuke-cluster:
	ansible-playbook -i ansible/inventory.yaml ansible/playbooks/nuke-cluster.yaml

.PHONY: build-cluster
build-cluster:
	ansible-playbook -i ansible/inventory.yaml ansible/playbooks/build-cluster.yaml

.PHONY: restart-all
restart-all:
	ansible-playbook -i ansible/inventory.yaml ansible/playbooks/restart-all.yaml

.PHONY: generate-atlantis-yaml
generate-atlantis-yaml:
	bash hack/generate-atlantis-yaml.sh
