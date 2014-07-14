assets/site:
	mkdir -p assets/site && echo 'Hello World' > assets/site/index.html

assets: assets/site

build: assets
	docker build -t amirkdv/apache_app .

build_no_cache: assets
	docker build --no-cache -t amirkdv/apache_app .

start:
	docker run --name ct_apache_app --publish 8001:80 --rm amirkdv/apache_app

.PHONY: start build build_no_cache
