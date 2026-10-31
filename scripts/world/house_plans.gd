class_name HousePlans
extends RefCounted
## As 8 plantas prontas do térreo das casas com interior (4 a 7 cômodos).
## Coordenadas normalizadas do interior: u de 0 (esquerda) a 1 (direita),
## v de 0 (frente, onde fica a porta da rua no meio) a 1 (fundo).
##   walls: [u0, v0, u1, v1, [portas em fração do comprimento]] (sempre retas)
##   rooms: [nome, [u0, v0, u1, v1], [[móvel, parede, posição 0..1], ...]]
##          parede = back/front/left/right (encosta e vira para dentro) ou center.
##          "mesa" no centro ganha duas cadeiras.

const PLANS := [
	{"name": "corredor central", "walls": [
		[0.4, 0.0, 0.4, 1.0, [0.17, 0.52, 0.85]], [0.6, 0.0, 0.6, 1.0, [0.2, 0.52, 0.82]],
		[0.0, 0.35, 0.4, 0.35, []], [0.0, 0.7, 0.4, 0.7, []], [0.6, 0.4, 1.0, 0.4, []], [0.6, 0.65, 1.0, 0.65, []]],
	"rooms": [
		["sala", [0.0, 0.0, 0.4, 0.35], [["sofa", "left", 0.5], ["estante", "back", 0.4]]],
		["cozinha", [0.0, 0.35, 0.4, 0.7], [["fogao", "left", 0.25], ["balcao", "left", 0.75], ["mesa", "center", 0.0]]],
		["quarto", [0.0, 0.7, 0.4, 1.0], [["cama", "back", 0.35], ["armario", "left", 0.4]]],
		["corredor", [0.4, 0.0, 0.6, 1.0], []],
		["escritorio", [0.6, 0.0, 1.0, 0.4], [["mesa", "right", 0.5], ["estante", "back", 0.6]]],
		["banheiro", [0.6, 0.4, 1.0, 0.65], [["banheira", "right", 0.5], ["pia", "back", 0.3], ["privada", "front", 0.7]]],
		["quarto", [0.6, 0.65, 1.0, 1.0], [["cama", "back", 0.6], ["armario", "right", 0.4]]]]},
	{"name": "sala grande", "walls": [
		[0.0, 0.5, 1.0, 0.5, [0.17, 0.47, 0.8]], [0.35, 0.5, 0.35, 1.0, []], [0.6, 0.5, 0.6, 1.0, []]],
	"rooms": [
		["sala", [0.0, 0.0, 1.0, 0.5], [["sofa", "left", 0.5], ["mesa", "center", 0.0], ["estante", "right", 0.5], ["fogao", "front", 0.15]]],
		["cozinha", [0.0, 0.5, 0.35, 1.0], [["balcao", "left", 0.55], ["fogao", "back", 0.5]]],
		["banheiro", [0.35, 0.5, 0.6, 1.0], [["banheira", "back", 0.5], ["privada", "left", 0.45], ["pia", "right", 0.45]]],
		["quarto", [0.6, 0.5, 1.0, 1.0], [["cama", "back", 0.5], ["armario", "right", 0.45], ["comoda", "left", 0.55]]]]},
	{"name": "L com corredor", "walls": [
		[0.6, 0.0, 0.6, 0.45, []], [0.0, 0.45, 1.0, 0.45, [0.3, 0.8]], [0.0, 0.6, 1.0, 0.6, [0.25, 0.62, 0.87]],
		[0.5, 0.6, 0.5, 1.0, []], [0.75, 0.6, 0.75, 1.0, []]],
	"rooms": [
		["sala", [0.0, 0.0, 0.6, 0.45], [["sofa", "left", 0.5], ["estante", "back", 0.85], ["mesa", "center", 0.0]]],
		["cozinha", [0.6, 0.0, 1.0, 0.45], [["fogao", "right", 0.3], ["balcao", "right", 0.75]]],
		["corredor", [0.0, 0.45, 1.0, 0.6], []],
		["quarto", [0.0, 0.6, 0.5, 1.0], [["cama", "back", 0.4], ["armario", "left", 0.45]]],
		["banheiro", [0.5, 0.6, 0.75, 1.0], [["banheira", "back", 0.5], ["pia", "left", 0.4]]],
		["despensa", [0.75, 0.6, 1.0, 1.0], [["estante", "back", 0.5], ["comoda", "right", 0.4]]]]},
	{"name": "corredor transversal", "walls": [
		[0.62, 0.0, 0.62, 0.42, []], [0.0, 0.42, 1.0, 0.42, [0.3, 0.8]], [0.0, 0.58, 1.0, 0.58, [0.25, 0.64, 0.89]],
		[0.5, 0.58, 0.5, 1.0, []], [0.78, 0.58, 0.78, 1.0, []]],
	"rooms": [
		["sala", [0.0, 0.0, 0.62, 0.42], [["sofa", "left", 0.5], ["estante", "back", 0.85]]],
		["cozinha", [0.62, 0.0, 1.0, 0.42], [["fogao", "right", 0.3], ["mesa", "center", 0.0]]],
		["corredor", [0.0, 0.42, 1.0, 0.58], []],
		["quarto", [0.0, 0.58, 0.5, 1.0], [["cama", "back", 0.4], ["comoda", "left", 0.4]]],
		["quarto", [0.5, 0.58, 0.78, 1.0], [["cama", "back", 0.5]]],
		["banheiro", [0.78, 0.58, 1.0, 1.0], [["privada", "back", 0.5], ["pia", "right", 0.3]]]]},
	{"name": "casa comprida", "walls": [
		[0.0, 0.3, 1.0, 0.3, [0.75]], [0.0, 0.55, 1.0, 0.55, [0.2, 0.7]], [0.4, 0.55, 0.4, 1.0, []]],
	"rooms": [
		["sala", [0.0, 0.0, 1.0, 0.3], [["sofa", "left", 0.5], ["estante", "back", 0.3], ["comoda", "right", 0.5]]],
		["cozinha", [0.0, 0.3, 1.0, 0.55], [["fogao", "left", 0.5], ["balcao", "back", 0.45], ["mesa", "center", 0.0]]],
		["banheiro", [0.0, 0.55, 0.4, 1.0], [["banheira", "back", 0.5], ["privada", "left", 0.3], ["pia", "right", 0.6]]],
		["quarto", [0.4, 0.55, 1.0, 1.0], [["cama", "back", 0.4], ["armario", "right", 0.5]]]]},
	{"name": "estudio e oficina", "walls": [
		[0.4, 0.0, 0.4, 0.5, [0.6]], [0.0, 0.5, 1.0, 0.5, [0.2, 0.5, 0.8]], [0.4, 0.5, 0.4, 1.0, []], [0.6, 0.5, 0.6, 1.0, []]],
	"rooms": [
		["oficina", [0.0, 0.0, 0.4, 0.5], [["mesa", "left", 0.4], ["estante", "front", 0.3], ["armario", "back", 0.3]]],
		["sala", [0.4, 0.0, 1.0, 0.5], [["sofa", "right", 0.5], ["mesa", "center", 0.0]]],
		["cozinha", [0.0, 0.5, 0.4, 1.0], [["fogao", "back", 0.4], ["balcao", "left", 0.4]]],
		["banheiro", [0.4, 0.5, 0.6, 1.0], [["privada", "back", 0.5], ["pia", "left", 0.4]]],
		["quarto", [0.6, 0.5, 1.0, 1.0], [["cama", "back", 0.5], ["comoda", "right", 0.4]]]]},
	{"name": "tres quartos", "walls": [
		[0.62, 0.0, 0.62, 0.4, [0.5]], [0.0, 0.4, 1.0, 0.4, [0.3, 0.8]], [0.0, 0.55, 1.0, 0.55, [0.16, 0.41, 0.62, 0.87]],
		[0.33, 0.55, 0.33, 1.0, []], [0.5, 0.55, 0.5, 1.0, []], [0.75, 0.55, 0.75, 1.0, []]],
	"rooms": [
		["sala", [0.0, 0.0, 0.62, 0.4], [["sofa", "left", 0.5], ["mesa", "center", 0.0]]],
		["cozinha", [0.62, 0.0, 1.0, 0.4], [["fogao", "right", 0.3], ["balcao", "front", 0.6]]],
		["corredor", [0.0, 0.4, 1.0, 0.55], []],
		["quarto", [0.0, 0.55, 0.33, 1.0], [["cama", "back", 0.45], ["comoda", "left", 0.35]]],
		["banheiro", [0.33, 0.55, 0.5, 1.0], [["privada", "back", 0.5]]],
		["quarto", [0.5, 0.55, 0.75, 1.0], [["cama", "back", 0.5]]],
		["quarto", [0.75, 0.55, 1.0, 1.0], [["cama", "back", 0.5], ["armario", "right", 0.3]]]]},
	{"name": "esquina", "walls": [
		[0.7, 0.0, 0.7, 0.55, [0.5]], [0.0, 0.55, 1.0, 0.55, [0.2, 0.6, 0.88]], [0.45, 0.55, 0.45, 1.0, []], [0.75, 0.55, 0.75, 1.0, []]],
	"rooms": [
		["sala", [0.0, 0.0, 0.7, 0.55], [["sofa", "left", 0.5], ["mesa", "center", 0.0], ["estante", "back", 0.75]]],
		["escritorio", [0.7, 0.0, 1.0, 0.55], [["mesa", "right", 0.4], ["estante", "front", 0.5]]],
		["cozinha", [0.0, 0.55, 0.45, 1.0], [["fogao", "left", 0.5], ["balcao", "back", 0.5]]],
		["quarto", [0.45, 0.55, 0.75, 1.0], [["cama", "back", 0.5]]],
		["banheiro", [0.75, 0.55, 1.0, 1.0], [["banheira", "back", 0.5], ["pia", "right", 0.3]]]]},
]

## Profundidade de cada móvel encostado na parede (meio, para afastar).
const DEPTH := {"mesa": 0.8, "cadeira": 0.45, "cama": 1.95, "armario": 0.5, "estante": 0.35, "fogao": 0.6,
	"sofa": 0.8, "banheira": 0.75, "privada": 0.6, "pia": 0.45, "balcao": 0.6, "comoda": 0.45}
