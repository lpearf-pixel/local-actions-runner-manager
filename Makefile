SHELL := /bin/bash
RUNNERCTL := bash ./runnerctl
NAME ?=
REPO ?=

.PHONY: help setup sync create start stop restart logs status list start-all stop-all clean doctor remove

help:
	@echo "Local Actions Runner Manager"
	@echo
	@echo "Commands that do not require chmod:"
	@echo "  make setup"
	@echo "  make sync"
	@echo "  make create NAME=chan-shuo REPO=lpearf-pixel/chan-shuo"
	@echo "  make start NAME=chan-shuo"
	@echo "  make stop NAME=chan-shuo"
	@echo "  make restart NAME=chan-shuo"
	@echo "  make logs NAME=chan-shuo"
	@echo "  make status [NAME=chan-shuo]"
	@echo "  make list"
	@echo "  make start-all"
	@echo "  make stop-all"
	@echo "  make clean [NAME=chan-shuo]"
	@echo "  make doctor NAME=chan-shuo"
	@echo "  make remove NAME=chan-shuo"

setup:
	@$(RUNNERCTL) setup

sync:
	@$(RUNNERCTL) sync

create:
	@test -n "$(NAME)" || (echo "ERROR: NAME is required" >&2; exit 1)
	@test -n "$(REPO)" || (echo "ERROR: REPO is required" >&2; exit 1)
	@$(RUNNERCTL) create "$(NAME)" "$(REPO)"

start:
	@test -n "$(NAME)" || (echo "ERROR: NAME is required" >&2; exit 1)
	@$(RUNNERCTL) start "$(NAME)"

stop:
	@test -n "$(NAME)" || (echo "ERROR: NAME is required" >&2; exit 1)
	@$(RUNNERCTL) stop "$(NAME)"

restart:
	@test -n "$(NAME)" || (echo "ERROR: NAME is required" >&2; exit 1)
	@$(RUNNERCTL) restart "$(NAME)"

logs:
	@test -n "$(NAME)" || (echo "ERROR: NAME is required" >&2; exit 1)
	@$(RUNNERCTL) logs "$(NAME)"

status:
	@if [ -n "$(NAME)" ]; then \
		$(RUNNERCTL) status "$(NAME)"; \
	else \
		$(RUNNERCTL) status; \
	fi

list:
	@$(RUNNERCTL) list

start-all:
	@$(RUNNERCTL) start-all

stop-all:
	@$(RUNNERCTL) stop-all

clean:
	@if [ -n "$(NAME)" ]; then \
		$(RUNNERCTL) clean "$(NAME)"; \
	else \
		$(RUNNERCTL) clean; \
	fi

doctor:
	@test -n "$(NAME)" || (echo "ERROR: NAME is required" >&2; exit 1)
	@$(RUNNERCTL) doctor "$(NAME)"

remove:
	@test -n "$(NAME)" || (echo "ERROR: NAME is required" >&2; exit 1)
	@$(RUNNERCTL) remove "$(NAME)"
