#!/bin/sh
# Compila a extensão C++ do terreno em voxels para Windows (MinGW) e Linux e põe os
# binários em bin/ junto com bin/apio_voxel.gdextension. Precisa de: git, scons, g++ e
# mingw-w64. O godot-cpp (oficial, versão fixa) é baixado em native/godot-cpp na primeira vez.
set -e
cd "$(dirname "$0")"
GODOT_CPP_TAG=godot-4.5-stable
if [ ! -d godot-cpp ]; then
	git clone --depth 1 -b "$GODOT_CPP_TAG" https://github.com/godotengine/godot-cpp godot-cpp
fi
JOBS=$(nproc 2>/dev/null || echo 4)
for target in template_debug template_release; do
	scons platform=windows use_mingw=yes target=$target -j"$JOBS"
	scons platform=linux target=$target -j"$JOBS"
done
mkdir -p ../bin
cp apio_voxel.gdextension.in ../bin/apio_voxel.gdextension
echo "Pronto: binários em bin/"
