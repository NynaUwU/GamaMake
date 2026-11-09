#!/usr/bin/env python3
"""Catálogo do jogo em PDF: receitas por estação, construções e máquinas (custo,
requisitos, força e energia), plantas, animais, bichos da água, onde achar as
coisas, combustíveis, eras/conquistas e a lista de itens com ícones.

Uso:
  OUT=catalog.json godot --headless --path . --script tests/export_catalog.gd
  python3 tools/catalog_pdf.py catalog.json docs/catalogo.pdf
"""
import json
import os
import sys
from datetime import date

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (KeepTogether, PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table,
                                TableStyle)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "icons")
FONT_DIR = "/usr/share/fonts/truetype/dejavu"
pdfmetrics.registerFont(TTFont("DejaVu", os.path.join(FONT_DIR, "DejaVuSans.ttf")))
pdfmetrics.registerFont(TTFont("DejaVu-Bold", os.path.join(FONT_DIR, "DejaVuSans-Bold.ttf")))
pdfmetrics.registerFontFamily("DejaVu", normal="DejaVu", bold="DejaVu-Bold")

INK = colors.HexColor("#22201c")
ACCENT = colors.HexColor("#8a5a12")
HEAD_BG = colors.HexColor("#e9e1cf")
ROW_ALT = colors.HexColor("#f7f3ea")
GRID = colors.HexColor("#c9bfa8")

S = {
    "title": ParagraphStyle("title", fontName="DejaVu-Bold", fontSize=26, leading=32, alignment=TA_CENTER, textColor=INK),
    "sub": ParagraphStyle("sub", fontName="DejaVu", fontSize=11, leading=15, alignment=TA_CENTER, textColor=colors.HexColor("#5a554c")),
    "h1": ParagraphStyle("h1", fontName="DejaVu-Bold", fontSize=17, leading=22, spaceBefore=6, spaceAfter=6, textColor=ACCENT),
    "h2": ParagraphStyle("h2", fontName="DejaVu-Bold", fontSize=12, leading=16, spaceBefore=8, spaceAfter=3, textColor=INK),
    "body": ParagraphStyle("body", fontName="DejaVu", fontSize=8.5, leading=11.5, textColor=INK),
    "small": ParagraphStyle("small", fontName="DejaVu", fontSize=7.5, leading=10, textColor=colors.HexColor("#5a554c")),
    "cell": ParagraphStyle("cell", fontName="DejaVu", fontSize=7.8, leading=10.5, textColor=INK),
    "cellb": ParagraphStyle("cellb", fontName="DejaVu-Bold", fontSize=7.8, leading=10.5, textColor=INK),
    "th": ParagraphStyle("th", fontName="DejaVu-Bold", fontSize=7.8, leading=10, textColor=INK),
}

BEHAVIOR = {"prey": "foge de quem chega perto", "defend": "revida quando apanha", "hunter": "caça em matilha",
            "territorial": "ataca quem chega perto", "farm": "criação (fica manso com a comida)", "bird": "pássaro (voa quando assusta)"}
BIOMES = {"plains": "Planície", "winter": "Neve", "mountain": "Montanha", "desert": "Deserto"}
PRODUCTS = {"galinha": "ovo (6 min)", "vaca": "leite (5 min)", "ovelha": "lã (10 min)"}
KIND_NAMES = {"weapon": "arma", "tool": "ferramenta", "material": "material", "food": "comida", "seed": "semente", "armor": "roupa/armadura",
              "placeable": "colocável", "book": "manual"}


def esc(text):
    return str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class Catalog:
    def __init__(self, data):
        self.d = data
        self.items = data["items"]
        self.sections = data["sections"]
        self.section_name = {s[0]: s[1] for s in self.sections}
        self.entries = {}  # place kind -> entrada do martelo
        for tab, entries in data["build"].items():
            for e in entries:
                if e.get("place"):
                    self.entries.setdefault(e["place"], dict(e, tab=tab))

    # --- Peças ------------------------------------------------------------------
    def name(self, item_id):
        return self.items.get(item_id, {}).get("name", item_id)

    def icon(self, item_id, size=11):
        path = os.path.join(ICONS, item_id + ".png")
        if os.path.exists(path):
            return '<img src="%s" width="%d" height="%d" valign="%d"/>' % (path, size, size, -2 if size <= 12 else -4)
        return ""

    def item(self, item_id, amount=1, size=11):
        qty = "%d " % amount if amount and amount != 1 else ""
        return "%s %s%s" % (self.icon(item_id, size), qty, esc(self.name(item_id)))

    def cost(self, cost, size=11):
        return " &nbsp; ".join(self.item(k, v, size) for k, v in cost.items()) or "—"

    def p(self, text, style="cell"):
        return Paragraph(text, S[style])

    def table(self, header, rows, widths, repeat=1):
        data = [[self.p(h, "th") for h in header]] + rows
        t = Table(data, colWidths=widths, repeatRows=repeat)
        style = [("GRID", (0, 0), (-1, -1), 0.4, GRID), ("BACKGROUND", (0, 0), (-1, 0), HEAD_BG),
                 ("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("TOPPADDING", (0, 0), (-1, -1), 2.5),
                 ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5), ("LEFTPADDING", (0, 0), (-1, -1), 4),
                 ("RIGHTPADDING", (0, 0), (-1, -1), 4)]
        for r in range(2, len(data), 2):
            style.append(("BACKGROUND", (0, r), (-1, r), ROW_ALT))
        t.setStyle(TableStyle(style))
        return t

    def unlock_text(self, station):
        sec = next(s for s in self.sections if s[0] == station)
        if not sec[2]:
            return "Disponível desde o começo."
        parts = []
        for kind in sec[2]:
            e = self.entries.get(kind)
            if e:
                parts.append("construa <b>%s</b> (aba %s): %s%s" % (esc(e["name"]), esc(e["tab"]), self.cost(e["cost"]),
                             " · precisa do <b>%s</b>" % esc(self.manual_title(e["manual"])) if e.get("manual") else ""))
        return "Aparece no diário depois que você " + "; ".join(parts) + "."

    def manual_title(self, manual):
        return self.d["manuals"].get(manual, {}).get("title", manual) if manual else ""

    # --- Capítulos ----------------------------------------------------------------
    def cover(self, story):
        story.append(Spacer(1, 5 * cm))
        story.append(Paragraph("Catálogo do jogo", S["title"]))
        story.append(Spacer(1, 0.4 * cm))
        story.append(Paragraph("Receitas · construções e máquinas · plantas · animais · onde achar · itens", S["sub"]))
        story.append(Spacer(1, 1.2 * cm))
        build_count = sum(len(v) for v in self.d["build"].values())
        counts = [["Itens", len(self.items)], ["Receitas", len(self.d["recipes"])], ["Estações de receita", len(self.sections)],
                  ["Construções no martelo", build_count], ["Culturas", len(self.d["crops"])], ["Animais", len(self.d["animals"])],
                  ["Bichos da água", len(self.d["creatures"])], ["Eras", len(self.d["eras"])], ["Conquistas", len(self.d["achievements"])]]
        t = Table([[self.p(a, "cellb"), self.p(str(b))] for a, b in counts], colWidths=[6 * cm, 3 * cm])
        t.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), 0.4, GRID), ("BACKGROUND", (0, 0), (0, -1), HEAD_BG)]))
        story.append(t)
        story.append(Spacer(1, 1.5 * cm))
        story.append(Paragraph("Gerado dos dados do próprio jogo em %s (tests/export_catalog.gd + tools/catalog_pdf.py)." % date.today().strftime("%d/%m/%Y"), S["sub"]))
        story.append(PageBreak())

    def eras(self, story):
        story.append(Paragraph("Eras e conquistas", S["h1"]))
        story.append(Paragraph("As eras são o guia de objetivos (não travam nada). Completar todas as conquistas marcadas como "
                               "<b>chave</b> de uma era abre a próxima. Tecla J abre o diário.", S["body"]))
        for idx, era in enumerate(self.d["eras"]):
            rows = []
            for aid, a in self.d["achievements"].items():
                if a["era"] == idx:
                    rows.append([self.p("<b>%s</b>" % esc(a["title"])), self.p(esc(a["how"])), self.p("chave" if a.get("key") else "")])
            story.append(KeepTogether([Paragraph("Era %d · %s" % (idx, esc(era["name"])), S["h2"]),
                                       Paragraph(esc(era["desc"]), S["small"]), Spacer(1, 3),
                                       self.table(["Conquista", "Como", ""], rows, [4.2 * cm, 11.3 * cm, 1.5 * cm])]))
        story.append(Paragraph("Manuais", S["h2"]))
        rows = [[self.p(self.item(mid, 1, 13)), self.p(str(m["era"])), self.p(esc(m["unlocks"]))] for mid, m in self.d["manuals"].items()]
        story.append(self.table(["Manual", "Era", "Libera"], rows, [4.5 * cm, 1.2 * cm, 11.3 * cm]))
        story.append(PageBreak())

    def recipes(self, story):
        story.append(Paragraph("Receitas por estação", S["h1"]))
        story.append(Paragraph("Produto ← ingredientes. No diário, cada estação aparece depois de construída; receita cujo ingrediente só "
                               "sai de uma máquina que você ainda não tem fica escondida. Receitas de manual só depois de ler o manual.",
                               S["body"]))
        by_station = {}
        for r in self.d["recipes"]:
            by_station.setdefault(r["station"], []).append(r)
        for sec in self.sections:
            rows = []
            for r in by_station.get(sec[0], []):
                note = esc(r["note"]) if r["note"] else ""
                if r.get("manual"):
                    note = (note + "<br/>" if note else "") + "<b>%s</b>" % esc(self.manual_title(r["manual"]))
                rows.append([self.p(self.item(r["out"], r["amount"], 13)), self.p(self.cost(r["cost"])), self.p(note)])
            if not rows:
                continue
            story.append(Paragraph(esc(sec[1]), S["h2"]))
            story.append(Paragraph(self.unlock_text(sec[0]), S["small"]))
            story.append(Spacer(1, 3))
            story.append(self.table(["Produto", "Ingredientes", "Precisa / obs."], rows, [5 * cm, 7.3 * cm, 4.7 * cm]))
        story.append(PageBreak())

    def machine_info(self, kind):
        info = []
        power, el = self.d["power"], self.d["electric"]
        if kind in power["output"]:
            info.append("gera força %g no eixo" % power["output"][kind])
        if kind in power["demand"]:
            info.append("usa força %g" % power["demand"][kind])
        if kind in el["demand"]:
            info.append("%g W%s" % (el["demand"][kind], " (só 110 V)" if kind in el["only_110"] else ""))
        if kind in el["converters"]:
            c = el["converters"][kind]
            info.append("%d V → %d V, até %g W (%d%%)" % (c["in"], c["out"], c["max"], round(c["eff"] * 100)))
        if kind == "dynamo":
            info.append("gera %g W (12 ou 110 V)" % el["dynamo"])
        if kind == "solar_panel":
            info.append("até %g W em 12 V" % el["solar"])
        if kind == "battery":
            info.append("12 V, %d células de %g Wh" % (el["cells"], el["cell_cap"]))
        if kind == "battery_bank":
            info.append("110 V, %d células em série" % el["bank_cells"])
        made = sorted({self.name(r["out"]) for r in self.d["recipes"] if any(kind in s[2] for s in self.sections if s[0] == r["station"])})
        if made:
            info.append("faz: " + ", ".join(made[:14]) + ("…" if len(made) > 14 else ""))
        return "<br/>".join(esc(x) for x in info)

    def build(self, story):
        story.append(Paragraph("Construções e máquinas (martelo)", S["h1"]))
        story.append(Paragraph("Custo, o que a peça faz e o que precisa para funcionar (força no eixo, energia elétrica, manual). "
                               "Força = rede de eixos (roda d'água, moinho de vento, motor a vapor, motor elétrico).", S["body"]))
        for tab, entries in self.d["build"].items():
            rows = []
            for e in entries:
                name = "<b>%s</b>" % esc(e["name"])
                if e.get("manual"):
                    name += "<br/><font size=6.5>precisa: %s</font>" % esc(self.manual_title(e["manual"]))
                rows.append([self.p(name), self.p(self.cost(e["cost"])), self.p(esc(e["desc"])), self.p(self.machine_info(e.get("place", "")))])
            story.append(Paragraph("Aba %s" % esc(tab), S["h2"]))
            story.append(self.table(["Nome", "Custo", "Descrição", "Funcionamento"], rows, [3.2 * cm, 3.9 * cm, 6.4 * cm, 3.5 * cm]))
        story.append(PageBreak())

    def uses_of(self, item_id):
        uses = []
        for r in self.d["recipes"]:
            if item_id in r["cost"]:
                uses.append("%s (%s)" % (self.name(r["out"]), self.section_name.get(r["station"], r["station"])))
        seen, out = set(), []
        for u in uses:
            if u not in seen:
                seen.add(u)
                out.append(u)
        return out

    def plants(self, story):
        story.append(Paragraph("Plantas", S["h1"]))
        story.append(Paragraph("Plante a semente num pote, floreira, canteiro ou na terra cavada pela pá. Cresce de dia; à noite a 20%. "
                               "Carneiro hidráulico e aspersor aceleram 50%; adubo dobra 3 colheitas.", S["body"]))
        rows = []
        for cid, c in self.d["crops"].items():
            uses = self.uses_of(c["food"])
            rows.append([self.p(self.item(c["food"], 1, 13)), self.p(self.item(c["seed"])), self.p("%.1f dias" % c["days"]),
                         self.p("%d–%d" % tuple(c["yield"])), self.p("%d–%d" % tuple(c["seeds"])),
                         self.p(esc(", ".join(uses[:10]) + ("…" if len(uses) > 10 else "")))])
        story.append(self.table(["Cultura", "Semente", "Tempo", "Colhe", "Sementes", "Usos"], rows,
                                [3 * cm, 3.4 * cm, 1.6 * cm, 1.3 * cm, 1.6 * cm, 6.1 * cm]))
        story.append(Paragraph("Árvores", S["h2"]))
        res = self.d["resources"]
        rows = [[self.p("<b>Árvore</b>"), self.p(self.cost({r[0]: r[2] for r in res["arvore"]})), self.p("muda: plante no chão ou na floreira")],
                [self.p("<b>Árvore frutífera</b>"), self.p(self.cost({r[0]: r[2] for r in res["arvore_fruta"]})), self.p("dá frutas no galho")]]
        story.append(self.table(["Árvore", "Dá (máximo)", "Obs."], rows, [4 * cm, 7 * cm, 6 * cm]))
        story.append(PageBreak())

    def animals(self, story):
        story.append(Paragraph("Animais", S["h1"]))
        spawn = {}
        for biome, rows in self.d["animal_spawn"].items():
            for row in rows:
                if row[0]:
                    spawn.setdefault(row[0], []).append(BIOMES.get(biome, biome))
        rows = []
        for aid, a in self.d["animals"].items():
            drops = " &nbsp; ".join("%s %s–%s" % (self.item(d[0]), d[1], d[2]) if d[1] != d[2] else self.item(d[0], d[1]) for d in a["drops"])
            food = " ".join(self.icon(f) for f in a.get("food", [])) or "—"
            extra = BEHAVIOR.get(a["type"], a["type"])
            if a.get("bite"):
                extra += "; mordida %g" % a["bite"]
            rows.append([self.p("<b>%s</b>" % esc(self.d["animal_names"].get(aid, aid))), self.p(esc(extra)), self.p("%g" % a["hp"]),
                         self.p(drops), self.p(food), self.p(esc(PRODUCTS.get(aid, "—"))), self.p(esc(", ".join(spawn.get(aid, [])) or "—"))])
        story.append(self.table(["Animal", "Comportamento", "Vida", "Drops", "Come", "Produto (manso)", "Onde"], rows,
                                [2 * cm, 3.4 * cm, 1 * cm, 4.6 * cm, 2.3 * cm, 2 * cm, 1.7 * cm]))
        story.append(Paragraph("Criação: segure a comida e aperte [E] perto do bicho para amansar. Manso come no cocho, bebe no bebedouro, "
                               "dá produtos e, alimentado e com água, tem filhotes.", S["small"]))
        story.append(Paragraph("Bichos da água (pesca e lança)", S["h2"]))
        rows = []
        for cid in self.d["creatures"]:
            uses = self.uses_of(cid)
            rows.append([self.p(self.item(cid, 1, 13)), self.p(esc(", ".join(uses)))])
        story.append(self.table(["Bicho", "Vira"], rows, [4.5 * cm, 12.5 * cm]))
        story.append(PageBreak())

    def where(self, story):
        story.append(Paragraph("Onde achar", S["h1"]))
        names = {"casa": "Armário/baú de casa", "caixote": "Caixote de rua", "airdrop": "Airdrop (onda noturna)", "ruina": "Escombros / ruína"}
        rows = []
        for table, entries in self.d["loot"].items():
            text = " &nbsp; ".join("%s <font size=6.5>(%d%%)</font>" % (self.item(e[0]), round(e[1] * 100)) for e in entries)
            rows.append([self.p("<b>%s</b>" % esc(names.get(table, table))), self.p(text)])
        story.append(Paragraph("Saque (chance de cada linha; cada baú sorteia 2 a 4 linhas)", S["h2"]))
        story.append(self.table(["Onde", "Itens"], rows, [3.5 * cm, 13.5 * cm]))
        rows = []
        res_names = {"arvore": "Árvore", "arvore_fruta": "Árvore frutífera", "rocha": "Rocha", "ferro": "Veio de ferro",
                     "cobre": "Veio de cobre", "estanho": "Veio de estanho", "carvao": "Veio de carvão"}
        for res, entries in self.d["resources"].items():
            text = " &nbsp; ".join("%s %d–%d" % (self.item(e[0]), e[1], e[2]) for e in entries)
            label = res_names.get(res, "Móvel: " + res.split("_", 1)[-1] if res.startswith("movel_") else res)
            rows.append([self.p("<b>%s</b>" % esc(label)), self.p(text)])
        story.append(Paragraph("Recursos do mapa e móveis desmontados", S["h2"]))
        story.append(self.table(["Recurso", "Dá"], rows, [3.5 * cm, 13.5 * cm]))
        story.append(Spacer(1, 4))
        story.append(Paragraph("<b>Caixote inicial:</b> " + self.cost({e[0]: e[1] for e in self.d["start"]}), S["body"]))
        story.append(Paragraph("Combustíveis", S["h2"]))
        rows = [[self.p("Fornalhas (segundos de fogo)"), self.p(self.cost({k: int(v) for k, v in self.d["fuel_furnace"].items()}))],
                [self.p("Fogueira, forno, assador (segundos)"), self.p(self.cost({k: int(v) for k, v in self.d["fuel_fire"].items()}))],
                [self.p("Maçarico (soldas por unidade)"), self.p(self.cost(self.d["torch_fuel"]))]]
        story.append(self.table(["Onde queima", "Combustível e quanto dura"], rows, [5 * cm, 12 * cm]))
        story.append(PageBreak())

    def all_items(self, story):
        story.append(Paragraph("Todos os itens", S["h1"]))
        rows = []
        for iid in sorted(self.items, key=lambda k: self.items[k]["name"].lower()):
            it = self.items[iid]
            stats = []
            if it["durability"]:
                stats.append("dura %d usos" % it["durability"])
            if it["armor"]:
                stats.append("proteção %d%%" % round(it["armor"] * 100))
            if it["damage"]:
                stats.append("dano %s" % it["damage"])
            if it["heal"]:
                stats.append("cura %s" % it["heal"])
            if it["warm"]:
                stats.append("aquece %g" % it["warm"])
            rows.append([self.p(self.icon(iid, 16)), self.p("<b>%s</b><br/><font size=6.5 color='#7a7466'>%s</font>" % (esc(it["name"]), iid)),
                         self.p(esc(KIND_NAMES.get(it["kind"], it["kind"]))), self.p(str(it["stack"])), self.p(esc(", ".join(stats))),
                         self.p(esc(it["desc"]))])
        story.append(self.table(["", "Item", "Tipo", "Pilha", "Números", "Descrição"], rows,
                                [0.8 * cm, 3.2 * cm, 1.8 * cm, 1 * cm, 2.6 * cm, 7.6 * cm]))


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("DejaVu", 7.5)
    canvas.setFillColor(colors.HexColor("#7a7466"))
    canvas.drawString(1.5 * cm, 1 * cm, "Catálogo do jogo")
    canvas.drawRightString(A4[0] - 1.5 * cm, 1 * cm, "página %d" % doc.page)
    canvas.restoreState()


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "catalog.json"
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "docs", "catalogo.pdf")
    with open(src, encoding="utf-8") as f:
        data = json.load(f)
    cat = Catalog(data)
    doc = SimpleDocTemplate(out, pagesize=A4, leftMargin=1.5 * cm, rightMargin=1.5 * cm, topMargin=1.4 * cm, bottomMargin=1.6 * cm,
                            title="Catálogo do jogo", author="GamaMake")
    story = []
    cat.cover(story)
    cat.recipes(story)
    cat.build(story)
    cat.plants(story)
    cat.animals(story)
    cat.where(story)
    cat.eras(story)
    cat.all_items(story)
    doc.build(story, onFirstPage=lambda c, d: None, onLaterPages=footer)
    print("PDF:", out)


if __name__ == "__main__":
    main()
