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
	kubectl get namespaces -o custom-columns=':metadata.name' --no-headers | xargs -n2 -I {} kubectl rollout restart deployments,statefulsets,daemonsets -n {}

.PHONY: fix-arp
fix-arp:
	ansible-playbook -i ansible/inventory.yaml ansible/playbooks/fix-arp.yaml
