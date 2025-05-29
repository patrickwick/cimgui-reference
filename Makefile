DEPENDENCIES_DIR=dependencies

all: run

.PHONY: run
run: src/glfw3.zig src/cimgui.zig
	zig build run

.PHONY: build
build: src/glfw3.zig src/cimgui.zig
	zig build

###############################################################################
# Dependencies.
###############################################################################
# cimgui bindings with embedded GLFW and OpenGL3 backend from source.
src/cimgui.zig: ${DEPENDENCIES_DIR}/cimgui
	@echo "Build libcimgui.a with GLFW3 and OpenGL3 backend features"
	cmake \
		-S ${DEPENDENCIES_DIR}/cimgui/backend_test/example_glfw_opengl3 \
		-B ${DEPENDENCIES_DIR}/cimgui/backend_test/example_glfw_opengl3/build \
		-DSTATIC_BUILD=ON \
		-DCIMGUI_DEFINE_ENUMS_AND_STRUCTS=1
	cmake \
		--build ${DEPENDENCIES_DIR}/cimgui/backend_test/example_glfw_opengl3/build \
		--parallel
	# Add cimgui.h into cimgui_impl.h, so both reside in a single binding file.
	echo "#include \"cimgui.h\"" \
		| cat - ${DEPENDENCIES_DIR}/cimgui/generator/output/cimgui_impl.h \
		> ${DEPENDENCIES_DIR}/cimgui/cimgui_impl_combined.h
	zig translate-c \
		-DCIMGUI_DEFINE_ENUMS_AND_STRUCTS=1 \
		-DCIMGUI_USE_GLFW=1 \
		-DCIMGUI_USE_OPENGL3=1 \
		-DIMGUI_IMPL_OPENGL_LOADER_GL3W=1 \
		-lc \
		-I${DEPENDENCIES_DIR}/cimgui \
		${DEPENDENCIES_DIR}/cimgui/cimgui_impl_combined.h \
		> src/cimgui.zig

${DEPENDENCIES_DIR}/cimgui:
	@echo "Clone cimgui"
	git clone \
		https://github.com/cimgui/cimgui.git \
		--recursive \
		--branch 1.91.8 \
		--depth 1 \
		${DEPENDENCIES_DIR}/cimgui

# GLFW3 from source.
src/glfw3.zig: ${DEPENDENCIES_DIR}/glfw3
	@echo "Build GLFW3"
	cmake \
		-S ${DEPENDENCIES_DIR}/glfw3 \
		-B ${DEPENDENCIES_DIR}/glfw3/build
	cmake \
		--build ${DEPENDENCIES_DIR}/glfw3/build \
		--parallel
	zig translate-c \
		-lc \
		-I${DEPENDENCIES_DIR}/glfw3/include \
		${DEPENDENCIES_DIR}/glfw3/include/GLFW/glfw3.h \
		> src/glfw3.zig

${DEPENDENCIES_DIR}/glfw3:
	@echo "Clone GLFW3"
	git clone \
		https://github.com/glfw/glfw.git \
		--recursive \
		--branch 3.3-stable \
		--depth 1 \
		${DEPENDENCIES_DIR}/glfw3
