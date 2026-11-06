APP_NAME = Currency Converter
BIN_NAME = CurrencyConverter

.PHONY: build app run clean icon

build:
	MACOSX_DEPLOYMENT_TARGET=14.0 swift build -c release --product $(BIN_NAME)

icon:
	bash Scripts/make_icon.sh

app: build
	bash Scripts/package_app.sh

run: app
	open "dist/$(APP_NAME).app"

clean:
	rm -rf .build dist
