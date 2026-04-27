.PHONY: dotfiles install-dfir install-remnux install-sift test update-dfir update-remnux update-sift

all:
	@echo "Select a target: dotfiles, install-sift, install-remnux, install-dfir, update-sift, update-remnux, update-dfir"

dotfiles:
	cp common/files/.bashrc ~/ && chmod 600 ~/.bashrc
	cp common/files/.vimrc ~/ && chmod 600 ~/.vimrc
	cp common/files/.bash_aliases ~/ && chmod 600 ~/.bash_aliases

install-sift:
	./sift/setup-sift.sh

install-remnux:
	./remnux/setup-remnux.sh

install-dfir:
	./dfir/setup-dfir.sh

update-sift:
	git pull
	./sift/update-sift.sh

update-remnux:
	git pull
	./remnux/update-remnux.sh

update-dfir:
	git pull
	./sift/update-sift.sh

test:
	shellcheck -f checkstyle common/bin/*.sh > checkstyle.out || true
	shellcheck -f checkstyle sift/*.sh >> checkstyle.out || true
	shellcheck -f checkstyle remnux/*.sh >> checkstyle.out || true
	shellcheck -f checkstyle dfir/*.sh >> checkstyle.out || true
