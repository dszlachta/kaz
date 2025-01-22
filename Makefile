build:
	zvm run master build-lib

test:
	zvm run master build test --summary all

docs:
	zvm run master build docs
