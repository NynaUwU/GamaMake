class_name Net
extends RefCounted
## Acesso ao autoload de rede ("Network", scripts/net/net.gd) de qualquer
## script: Net.i.online(), Net.i.is_host()... (é uma classe para funcionar
## também nos testes rodados com -s, onde o nome do autoload ainda não existe
## quando os scripts são compilados).

static var i: Node
