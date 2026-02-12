run: build
	docker run -d -p 5000:80 thm-paints:latest

build:
	docker build -t thm-paints:latest .

stop:
	docker stop $$(docker ps -q --filter ancestor=thm-paints:latest)
