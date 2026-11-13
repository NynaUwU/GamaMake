# Extensão C++ do APIO: terreno em voxels (branch `terreno-voxel`)

Blocos de 0,4 m (o quadradinho da parede) guardados em seções de 16×16×16 (6,4 m), como
os chunks do Minecraft: o que não tem superfície (só ar, só pedra) não ganha malha. A
superfície é desenhada com rampas (Surface Nets, faces retas), não com cubos.

- `src/voxel_core.*`: C++ puro (sem Godot): ruído 3D, geração (chão a partir das alturas do
  TerrainWorld, cavernas em túnel e salão, veios de minério, rocha-mãe a 60 m abaixo do mar)
  e malha. Dá para compilar e medir sozinho: `test/bench.cpp`.
- `src/apio_voxel.*`, `src/register_types.cpp`: a classe `ApioVoxel` para o GDScript (godot-cpp).
- `scripts/world/voxel_ref.gd`: o mesmo algoritmo em GDScript (confere o C++ e serve de
  reserva); `tests/test_voxel_ref.gd` compara os dois bloco a bloco.

## Compilar (Windows e Linux)

    native/build.sh

Precisa de git, scons, g++ e mingw-w64. Baixa o godot-cpp oficial (tag `godot-4.5-stable`,
funciona no Godot 4.7) em `native/godot-cpp` (fora do git), compila
`bin/libapio_voxel.{windows,linux}.template_{debug,release}.x86_64.{dll,so}` e copia
`bin/apio_voxel.gdextension`. Sem os binários o jogo usa a versão GDScript (bem mais lenta).

## Medir sem o Godot

    g++ -O2 -std=c++17 -Inative/src native/src/voxel_core.cpp native/test/bench.cpp -o bench && ./bench
