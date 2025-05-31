# This is based on ./dependencies/cimgui/backend_test/example_glfw_opengl3/CMakeLists.txt
# But honestly, the cimgui cmake code is pretty bad.
project(cimgui_glfw)
cmake_minimum_required(VERSION 3.11)

set(CMAKE_CXX_STANDARD 11)
set(GLFW3_DIR "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/glfw3")
set(CIMGUI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/cimgui")

add_library(cimgui STATIC)

target_sources(cimgui
	PRIVATE
		${CIMGUI_DIR}/cimgui.cpp 

		${CIMGUI_DIR}/imgui/imgui.cpp 
		${CIMGUI_DIR}/imgui/imgui_draw.cpp 
		${CIMGUI_DIR}/imgui/imgui_demo.cpp 
		${CIMGUI_DIR}/imgui/imgui_widgets.cpp
		${CIMGUI_DIR}/imgui/imgui_tables.cpp

		${CIMGUI_DIR}/imgui/backends/imgui_impl_opengl3.cpp
		${CIMGUI_DIR}/imgui/backends/imgui_impl_glfw.cpp
)

target_include_directories(cimgui
	PRIVATE
		${CIMGUI_DIR}
		${CIMGUI_DIR}/imgui

		${GLFW3_DIR}/include
)

target_compile_definitions(cimgui
	PRIVATE
		"IMGUI_IMPL_API=extern \"C\" "
		"IMGUI_USER_CONFIG=\"${CIMGUI_DIR}/cimconfig.h\""
		"IMGUI_DISABLE_OBSOLETE_FUNCTIONS=1"
		IMGUI_IMPL_OPENGL_LOADER_GL3W
		CIMGUI_USE_OPENGL3
		CIMGUI_USE_GLFW
		CIMGUI_DEFINE_ENUMS_AND_STRUCTS=1
)

target_link_directories(cimgui
	PUBLIC
		${GLFW3_DIR}/build/src
)

target_link_libraries(cimgui
	PUBLIC
		gl
		glfw3
)
