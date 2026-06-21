.PHONY: relay-install relay-run relay-plugin ios-build

relay-install:
	pip install -r relay/requirements.txt

relay-run:
	python3 relay/mosshy_relay.py

relay-plugin:
	herdr plugin link relay/

ios-build:
	cd mosshy-ios && swift build
