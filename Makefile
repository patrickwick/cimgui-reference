DEPENDENCIES_DIR=dependencies

all: run

.PHONY: run
run: src/glfw3.zig src/cimgui.zig
	zig build run

.PHONY: build
build: src/glfw3.zig src/cimgui.zig
	zig build

.PHONY: clean
clean:
	rm -f src/glfw3.zig
	rm -f src/cimgui.zig
	rm -rf build_cimgui
	rm -rf ./zig-out
	rm -rf ./.zig-cache

###############################################################################
# Dependencies.
###############################################################################
# cimgui bindings with embedded GLFW and OpenGL3 backend from source.
src/cimgui.zig: src/glfw3.zig ${DEPENDENCIES_DIR}/cimgui
	@echo "Build libcimgui.a with GLFW3 and OpenGL3 backend features"
	cmake \
		-S . \
		-B build_cimgui \
		-D CIMGUI_DEFINE_ENUMS_AND_STRUCTS=1
	cmake \
		--build build_cimgui \
		--parallel
	# Add cimgui.h into cimgui_impl.h, so both reside in a single binding file.
	echo "#include \"cimgui.h\"" \
		| cat - ${DEPENDENCIES_DIR}/cimgui/cimgui_impl.h \
		> ${DEPENDENCIES_DIR}/cimgui/cimgui_impl_combined.h
	zig translate-c \
		-D CIMGUI_DEFINE_ENUMS_AND_STRUCTS=1 \
		-D CIMGUI_USE_GLFW=1 \
		-D CIMGUI_USE_OPENGL3=1 \
		-D IMGUI_IMPL_OPENGL_LOADER_GL3W=1 \
		-lc \
		-I${DEPENDENCIES_DIR}/cimgui \
		${DEPENDENCIES_DIR}/cimgui/cimgui_impl_combined.h \
		> src/cimgui.zig

# Uses docking_inter branch to support window docking features.
${DEPENDENCIES_DIR}/cimgui:
	@echo "Clone cimgui"
	git clone \
		https://github.com/cimgui/cimgui.git \
		--recursive \
		--branch docking_inter \
		--depth 1 \
		${DEPENDENCIES_DIR}/cimgui

# GLFW3 from source.
src/glfw3.zig: ${DEPENDENCIES_DIR}/glfw3
	@echo "Build GLFW3"
	cmake \
		-S ${DEPENDENCIES_DIR}/glfw3 \
		-B ${DEPENDENCIES_DIR}/glfw3/build \
		-D GLFW_BUILD_WAYLAND=1 \
		-D GLFW_BUILD_X11=0 \
		-D BUILD_SHARED_LIBS=0
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
