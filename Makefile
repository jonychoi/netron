
.PHONY: test

build: clean lint build_python build_electron

publish: clean lint publish_electron publish_python publish_web publish_cask publish_winget

install:
	@[ -d node_modules ] || npm install

clean:
	rm -rf ./dist
	rm -rf ./node_modules
	rm -rf ./package-lock.json

reset: clean
	rm -rf ./third_party

update: install
	@./tools/armnn sync schema
	@./tools/bigdl sync schema
	@./tools/caffe sync schema
	@./tools/cntk sync schema
	@./tools/coreml sync schema
	@./tools/dnn schema
	@./tools/mnn sync schema
	# @./tools/onnx sync install schema metadata
	@./tools/paddle sync schema
	@./tools/pytorch sync install schema metadata
	@./tools/sklearn sync install metadata
	@./tools/tf sync install schema metadata
	@./tools/uff schema

build_python: install
	python -m pip install --user wheel
	python ./setup.py build --version bdist_wheel

build_electron: install
	CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --mac --publish never
	npx electron-builder --win --publish never
	npx electron-builder --linux appimage --publish never
	npx electron-builder --linux snap --publish never

lint: install
	npx eslint source/*.js test/*.js publish/*.js tools/*.js

test: install
	node ./test/models.js

start: install
	npx electron .

publish_python: build_python
	python -m pip install --user twine
	python -m twine upload --non-interactive --skip-existing --verbose dist/dist/*

publish_electron: install
	npx electron-builder --mac --publish always
	npx electron-builder --win --publish always
	npx electron-builder --linux appimage --publish always
	npx electron-builder --linux snap --publish always

build_web:
	mkdir -p ./dist/web
	rm -rf ./dist/web/*
	cp -R ./source/*.html ./dist/web
	cp -R ./source/*.css ./dist/web
	cp -R ./source/*.js ./dist/web
	cp -R ./source/*.json ./dist/web
	cp -R ./source/*.ico ./dist/web
	cp -R ./source/*.png ./dist/web
	cp -R ./node_modules/d3/dist/d3.min.js ./dist/web
	cp -R ./node_modules/dagre/dist/dagre.min.js ./dist/web
	cp -R ./node_modules/pako/dist/pako.min.js ./dist/web
	rm -rf ./dist/web/electron.* ./dist/web/app.js
	sed -i "s/0\.0\.0/$$(grep '"version":' package.json -m1 | cut -d\" -f4)/g" ./dist/web/index.html

publish_web: build_web
	rm -rf ./dist/release
	git clone --depth=1 https://x-access-token:$(GITHUB_TOKEN)@github.com/$(GITHUB_USER)/netron.git --branch release ./dist/release 2>&1 > /dev/null
	cp -R ./dist/web/* ./dist/release
	git -C ./dist/release add --all
	git -C ./dist/release commit --amend --no-edit
	git -C ./dist/release push --force origin release

publish_cask:
	curl -s -H "Authorization: token $(GITHUB_TOKEN)" https://api.github.com/repos/Homebrew/homebrew-cask/forks -d '' 2>&1 > /dev/null
	rm -rf ./dist/homebrew-cask
	sleep 4
	git clone --depth=2 https://x-access-token:$(GITHUB_TOKEN)@github.com/$(GITHUB_USER)/homebrew-cask.git ./dist/homebrew-cask
	node ./publish/cask.js ./package.json ./dist/homebrew-cask/Casks/netron.rb
	git -C ./dist/homebrew-cask add --all
	git -C ./dist/homebrew-cask commit -m "Update $$(node -pe "require('./package.json').productName") to $$(node -pe "require('./package.json').version")"
	git -C ./dist/homebrew-cask push
	curl -H "Authorization: token $(GITHUB_TOKEN)" https://api.github.com/repos/Homebrew/homebrew-cask/pulls -d "{\"title\":\"Update $$(node -pe "require('./package.json').name") to $$(node -pe "require('./package.json').version")\",\"base\":\"master\",\"head\":\"$(GITHUB_USER):master\",\"body\":\"\"}" 2>&1 > /dev/null
	rm -rf ./dist/homebrew-cask
	sleep 4
	curl -s -H "Authorization: token $(GITHUB_TOKEN)" -X "DELETE" https://api.github.com/repos/$(GITHUB_USER)/homebrew-cask # 2>&1 > /dev/null

publish_winget:
	curl -s -H "Authorization: token $(GITHUB_TOKEN)" https://api.github.com/repos/microsoft/winget-pkgs/forks -d '' 2>&1 > /dev/null
	rm -rf ./dist/winget-pkgs
	sleep 4
	git clone --depth=2 https://x-access-token:$(GITHUB_TOKEN)@github.com/$(GITHUB_USER)/winget-pkgs.git ./dist/winget-pkgs
	node ./publish/winget.js ./package.json ./dist/winget-pkgs/manifests
	git -C ./dist/winget-pkgs add --all
	git -C ./dist/winget-pkgs commit -m "Update $$(node -pe "require('./package.json').name") to $$(node -pe "require('./package.json').version")"
	git -C ./dist/winget-pkgs push
	curl -H "Authorization: token $(GITHUB_TOKEN)" https://api.github.com/repos/microsoft/winget-pkgs/pulls -d "{\"title\":\"Update $$(node -pe "require('./package.json').productName") to $$(node -pe "require('./package.json').version")\",\"base\":\"master\",\"head\":\"$(GITHUB_USER):master\",\"body\":\"\"}" 2>&1 > /dev/null
	rm -rf ./dist/winget-pkgs
	sleep 4
	curl -s -H "Authorization: token $(GITHUB_TOKEN)" -X "DELETE" https://api.github.com/repos/$(GITHUB_USER)/winget-pkgs # 2>&1 > /dev/null

version:
	node ./publish/version.js ./package.json
	git add ./package.json
	git commit -m "Update to $$(node -pe "require('./package.json').version")"
	git tag v$$(node -pe "require('./package.json').version")
	git push --force
	git push --tags
	git tag -d v$$(node -pe "require('./package.json').version")

pull:
	git tag -d $$(git tag -l)
	git pull --prune --rebase
