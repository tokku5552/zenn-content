up:
	docker compose up -d
build:
	docker compose build --no-cache --force-rm
remake:
	@make destroy
	@make up
stop:
	docker compose stop
down:
	docker compose down --remove-orphans
restart:
	@make down
	@make up
destroy:
	docker compose down --rmi all --volumes --remove-orphans
destroy-volumes:
	docker compose down --volumes --remove-orphans
ps:
	docker compose ps
logs:
	docker compose logs
logs-watch:
	docker compose logs --follow
log-node-container-zenn:
	docker compose logs node-container-zenn
log-node-container-zenn-watch:
	docker compose logs --follow node-container-zenn
bash:
	docker compose exec node-container-zenn bash
new-article:
	docker compose exec node-container-zenn bash -c 'npx zenn new:article'	
preview:
	docker compose exec node-container-zenn bash -c 'npx zenn preview'