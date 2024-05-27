BUILD_DIR = build
SOURCE_DIR = examples

SOURCES = $(wildcard ${SOURCE_DIR}/*.zig)
# Remove "interface.zig" from the list of sources
SOURCES := $(filter-out ${SOURCE_DIR}/interface.zig,${SOURCES})
TARGETS = $(patsubst ${SOURCE_DIR}/%.zig,${BUILD_DIR}/%.wasm,${SOURCES})

all: $(TARGETS)

clean:
	rm -r ${BUILD_DIR}

.PHONY: clean all

${BUILD_DIR}/%.wasm ${BUILD_DIR}/%.wasm.o: ${SOURCE_DIR}/%.zig ${SOURCE_DIR}/interface.zig
	mkdir -p $(dir $@)
	zig build-exe -fno-entry -target wasm32-freestanding $< -rdynamic -O ReleaseSafe
	# Move the generated file to the build directory
	# Wish I knew how to just build it in the build directory in the first place
	mv $(notdir $@) $@
	mv $(notdir $@).o $@.o
