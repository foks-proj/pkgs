.PHONY: foks-archive-keyring

foks-archive-keyring:
	sh -x scripts/build-deb.sh

.PHONY: debian-repo

debian-repo:
	bash -x scripts/make-debian-repo.bash
