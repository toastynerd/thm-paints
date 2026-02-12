run: stop build
	docker run -d -p 5000:80 thm-paints:latest

build:
	docker build -t thm-paints:latest .

stop:
	@CONTAINER_ID=$$(docker ps -q --filter ancestor=thm-paints:latest); \
	if [ -n "$$CONTAINER_ID" ]; then \
		docker stop $$CONTAINER_ID; \
	fi
