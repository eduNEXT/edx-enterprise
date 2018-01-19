.DEFAULT_GOAL := help

NODE_BIN := ./node_modules/.bin

ALL_PLATFORMS := ficus ginkgo hawthorn master
TARGET_PLATFORM := master

define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[\.a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -rf {} +
	find . -name '*~' -exec rm -f {} +
	coverage erase
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

clean.static: ## remove all ignored generated static files
	rm -rf enterprise/assets/
	rm -rf enterprise/static/enterprise/bundles/*.js

static: ## rather all static assets for production
	$(NODE_BIN)/webpack --config webpack.config.js --display-error-details --progress --optimize-minimize
	python manage.py collectstatic --noinput
	# TODO: Add the compression app for manage.py settings.
	#python manage.py compress -v3 --force

static.dev: ## gather all static assets for a development environment
	$(NODE_BIN)/webpack --config webpack.config.js --display-error-details --progress

static.watch: ## watch for static asset changes for a development environment
	$(NODE_BIN)/webpack --config webpack.config.js --display-error-details --progress --watch

compile_translations: ## compile translation files, outputting .po files for each supported language
	./manage.py compilemessages

dummy_translations: ## generate dummy translation (.po) files
	cd enterprise && i18n_tool dummy

extract_translations: ## extract strings to be translated, outputting .mo files
	rm -rf docs/_build
	./manage.py makemessages -l en -v1 -d django
	./manage.py makemessages -l en -v1 -d djangojs -i "node_modules/*"

fake_translations: extract_translations dummy_translations compile_translations ## generate and compile dummy translation files

pull_translations: ## pull translations from Transifex
	tx pull -a

push_translations: ## push source translation files (.po) from Transifex
	tx push -s

coverage: clean ## generate and view HTML coverage report
	py.test --cov-report html
	$(BROWSER) htmlcov/index.html

docs: ## generate Sphinx HTML documentation, including API docs
	tox -e docs
	$(BROWSER) docs/_build/html/index.html

upgrade: ## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -q pip-tools
	pip-compile --upgrade -o requirements/dev.txt requirements/base.in requirements/test-$(TARGET_PLATFORM).in requirements/dev.in requirements/quality.in
	pip-compile --upgrade -o requirements/doc.txt requirements/base.in requirements/test-$(TARGET_PLATFORM).in requirements/doc.in
	pip-compile --upgrade -o requirements/quality.txt requirements/base.in requirements/test-$(TARGET_PLATFORM).in requirements/dev.in requirements/quality.in requirements/doc.in requirements/test.in
	pip-compile --upgrade -o requirements/travis.txt requirements/travis.in
	pip-compile --upgrade -o requirements/js_test.txt requirements/js_test.in
	pip-compile --upgrade -o requirements/test.txt requirements/base.in requirements/test-$(TARGET_PLATFORM).in requirements/test.in

	for platform in $(ALL_PLATFORMS) ; do \
		pip-compile --upgrade -o requirements/test-$$platform.txt requirements/base.in requirements/test-$$platform.in requirements/test.in ; \
	done

requirements.js: ## install JS requirements for local development
	npm install

requirements: requirements.js ## install development environment requirements
	pip install -qr requirements/dev.txt --exists-action w
	pip-sync requirements/base.txt requirements/dev.txt requirements/private.* requirements/test.txt

jshint: ## run Javascript linting
	@[ -x ./node_modules/jshint/bin/jshint ] || npm install jshint --save-dev
	./node_modules/jshint/bin/jshint enterprise
	./node_modules/jshint/bin/jshint spec

test: clean ## run tests in the current virtualenv
	pip install -qr requirements/test.txt --exists-action w
	py.test

diff_cover: test
	diff-cover coverage.xml

test-all: clean jshint static ## run tests on every supported Python/Django combination
	tox
	tox -e quality
	tox -e jasmine

validate: test ## run tests and quality checks
	tox -e quality

isort: ## call isort on packages/files that are checked in quality tests
	isort --recursive tests test_utils enterprise consent integrated_channels manage.py setup.py

.PHONY: clean clean.static compile_translations coverage docs dummy_translations extract_translations \
	fake_translations help pull_translations push_translations requirements test test-all upgrade validate isort \
	static static.dev static.watch
