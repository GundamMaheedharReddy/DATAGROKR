test:
	python -m pytest -q

lint:
	python -m flake8 app tests scripts

hooks:
	bash scripts/install_hooks.sh

simulate:
	bash scripts/simulate_gitflow.sh

clean:
	rm -rf .pytest_cache sandbox /tmp/gitflow-sandbox
	find . -name __pycache__ -type d -prune -exec rm -rf {} +

.PHONY: test lint hooks simulate clean
