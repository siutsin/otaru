.PHONY: main maintenance upgrade-cluster nuke-cluster rebuild-cluster restart-all

main:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/main.yaml

maintenance:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/maintenance.yaml

upgrade-cluster:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/upgrade-cluster.yaml

nuke-cluster:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/uninstall-cluster.yaml

rebuild-cluster:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/rebuild-cluster.yaml

restart-all:
	kubectl get namespaces -o custom-columns=':metadata.name' --no-headers | xargs -n2 -I {} kubectl rollout restart deployments,statefulsets,daemonsets -n {}
