.PHONY: maintenance upgrade-cluster nuke-cluster rebuild-cluster restart-all

maintenance:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/maintainence.yaml

upgrade-cluster:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/upgrade-cluster.yaml

nuke-cluster:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/k3s/uninstall.yaml

rebuild-cluster:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/k3s/install.yaml

restart-all:
	kubectl get namespaces -o custom-columns=':metadata.name' --no-headers | xargs -n2 -I {} kubectl rollout restart deployments,statefulsets,daemonsets -n {}
