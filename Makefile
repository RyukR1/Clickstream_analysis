# Auto-detect local Java if not in environment
JAVA_HOME ?= $(firstword $(wildcard $(HOME)/.local/share/jvm/temurin-17 /usr/lib/jvm/java-17-openjdk-amd64 /usr/lib/jvm/default-java))
ifneq ($(JAVA_HOME),)
export JAVA_HOME
export PATH := $(JAVA_HOME)/bin:$(PATH)
endif

PYTHON ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,python3)
ROWS ?= 200000
DAYS ?= 7
DATA ?= data
export PYTHONPATH := src

.PHONY: setup generate etl quality report demo test lint benchmark benckmark clean

setup:
	$(PYTHON) -m pip install -e ".[dev]"

generate:
	$(PYTHON) -m clickstream.generate --out $(DATA)/raw/access.log --rows $(ROWS) --days $(DAYS)

etl:
	$(PYTHON) -m clickstream.transform --input $(DATA)/raw --output $(DATA)/curated \
		--quarantine $(DATA)/quarantine --metrics $(DATA)/metrics.json

quality:
	$(PYTHON) -m clickstream.quality --metrics $(DATA)/metrics.json --curated $(DATA)/curated \
		--report $(DATA)/quality.json

report:
	$(PYTHON) -m clickstream.report --curated $(DATA)/curated --sql sql/analytics.sql \
		--out results/analysis_results.txt

demo: generate etl quality report

test:
	$(PYTHON) -m pytest -q

lint:
	ruff check .
	shellcheck *.sh

benchmark:
	$(PYTHON) -m clickstream.benchmark --rows $(ROWS) --out docs/benchmark.md

benckmark: benchmark

clean:
	rm -rf $(DATA) results .pytest_cache
