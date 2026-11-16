"""Build a six-slide demo progress-report deck with placeholder figures.

Usage::

    python progress_build.py path/to/demo.pptx

The deck follows the house skeleton: title, one-question opener,
background with a cited figure, framework schematic, one results slide
with an assertion title and a single caption sentence, and a summary
text page.  Placeholder figures are drawn with matplotlib into a
temporary folder at the print size they will occupy on the slide, at
300 dpi, so the magnification checks in ``deck_kit.fig`` are meaningful.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import FancyBboxPatch  # noqa: E402

KIT = Path(__file__).resolve().parents[1] / "kit"
sys.path.insert(0, str(KIT))

import deck_kit as kit  # noqa: E402

matplotlib.rcParams.update({
    "font.family": "Arial",
    "font.size": 7,
    "axes.edgecolor": "#" + kit.INK,
    "axes.labelcolor": "#" + kit.INK,
    "xtick.color": "#" + kit.INK,
    "ytick.color": "#" + kit.INK,
    "axes.linewidth": 0.8,
})


# --------------------------------------------------------------- figures
def literature_figure(out: Path) -> Path:
    """A two-panel stand-in for a published figure, 3.2 x 2.05 in."""
    fig, (a, b) = plt.subplots(1, 2, figsize=(3.2, 2.05), dpi=300)
    fig.subplots_adjust(left=0.14, right=0.97, bottom=0.20, top=0.86,
                        wspace=0.45)

    labels = ["cue A", "cue B", "A + B"]
    values = [0.42, 0.45, 0.71]
    a.bar(labels, values, color=["#" + kit.ACCENT, "#" + kit.WIND, "#" + kit.INK],
          width=0.62)
    a.errorbar(labels, values, yerr=[0.05, 0.06, 0.05], fmt="none",
               ecolor="#" + kit.INK, elinewidth=0.8, capsize=2)
    a.set_ylim(0, 0.95)
    a.set_ylabel("response probability")
    a.set_title("A  Behaviour", fontsize=7, pad=3)
    a.tick_params(axis="x", labelsize=6)

    x = [0, 40, 80, 120, 160]
    b.plot(x, [0.0, 0.08, 0.30, 0.72, 1.0], color="#" + kit.ACCENT, lw=1.4)
    b.plot(x, [0.0, 0.05, 0.18, 0.46, 1.0], color="#" + kit.MUTED, lw=1.4,
           ls="--")
    b.set_xlabel("time (ms)")
    b.set_ylabel("cumulative fraction")
    b.set_title("B  Time course", fontsize=7, pad=3)
    b.set_yticks([0, 0.5, 1.0])

    path = out / "literature_panel.png"
    fig.savefig(path, dpi=300)
    plt.close(fig)
    return path


def schematic_figure(out: Path) -> Path:
    """A framework schematic drawn at final size, 8.6 x 3.2 in."""
    w, h = 8.6, 3.2
    fig = plt.figure(figsize=(w, h), dpi=300)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, w)
    ax.set_ylim(0, h)
    ax.set_aspect("equal")
    ax.axis("off")

    def box(x: float, y: float, bw: float, bh: float, label: str,
            sub: str, color: str) -> None:
        ax.add_patch(FancyBboxPatch(
            (x, y), bw, bh, boxstyle="round,pad=0,rounding_size=0.12",
            linewidth=1.5, edgecolor="#" + color, facecolor="#F3F5F7"))
        ax.text(x + bw / 2, y + bh / 2 + (0.30 if sub else 0),
                label, ha="center", va="center", fontsize=22,
                color="#" + kit.INK)
        if sub:
            ax.text(x + bw / 2, y + bh / 2 - 0.30, sub, ha="center",
                    va="center", fontsize=16, color="#" + kit.MUTED)

    box(0.30, 1.85, 1.95, 0.85, "looming", "", kit.ACCENT)
    box(0.30, 0.50, 1.95, 0.85, "wind", "", kit.WIND)
    box(3.35, 0.65, 2.35, 1.90, "decision unit", "how they combine", kit.INK)
    box(6.45, 1.15, 1.80, 0.90, "escape", "", kit.INK)

    arrow = dict(arrowstyle="-|>", color="#" + kit.INK, lw=1.5,
                 mutation_scale=14, shrinkA=0, shrinkB=0)
    ax.annotate("", xy=(3.35, 2.10), xytext=(2.25, 2.28), arrowprops=arrow)
    ax.annotate("", xy=(3.35, 1.20), xytext=(2.25, 0.93), arrowprops=arrow)
    ax.annotate("", xy=(6.45, 1.60), xytext=(5.70, 1.60), arrowprops=arrow)

    path = out / "framework.png"
    fig.savefig(path, dpi=300)
    plt.close(fig)
    return path


def results_figure(out: Path) -> Path:
    """A results stand-in, 3.4 x 1.8 in, wider than tall."""
    fig, ax = plt.subplots(figsize=(3.4, 1.8), dpi=300)
    fig.subplots_adjust(left=0.13, right=0.98, bottom=0.22, top=0.90)

    soa = [-300, -150, 0, 150, 300]
    delta = [1, -4, -3, -27, -2]
    sem = [6, 7, 8, 8, 7]
    ax.axhline(0, color="#" + kit.MUTED, lw=0.8, ls=":")
    ax.errorbar(soa, delta, yerr=sem, color="#" + kit.INK, lw=1.4,
                marker="o", ms=3, capsize=2)
    ax.set_xticks(soa)
    ax.set_xlabel("cue B lead (ms)")
    ax.set_ylabel("latency change (ms)")

    path = out / "result_panel.png"
    fig.savefig(path, dpi=300)
    plt.close(fig)
    return path


# ----------------------------------------------------------------- deck
def build(out_path: Path, figs: Path) -> None:
    kit.set_figures(figs)
    prs = kit.new_deck()

    # 1  title
    s = kit.blank(prs)
    kit.text(s, 0.9, 1.25, 11.6, 0.35, "PROGRESS REPORT  ·  DEMO",
             size=14, color=kit.ACCENT, bold=True)
    kit.text(s, 0.9, 1.70, 11.6, 1.05, "Two cues, one decision", size=44,
             bold=True)
    kit.text(s, 0.9, 2.90, 11.6, 0.80,
             "A worked example of the house slide style", size=24)
    kit.text(s, 0.9, 4.05, 11.6, 0.55, "Example project  ·  October 2026",
             size=20)
    kit.foot(s)
    kit.notes(
        s,
        "示例：这套模板长什么样",
        "This deck is a worked example of the house slide style. It walks "
        "through the six-slide skeleton I use for progress reports: one "
        "question, a cited background, a framework, one result, and a "
        "summary. I will start with the single question that frames the "
        "whole talk.",
        "这份幻灯是 house style 的示例。它走一遍进度报告常用的六页骨架：一个"
        "问题、有引用的背景、一个框架、一个结果和总结。先从贯穿整个报告的"
        "那个问题开始。",
    )

    # 2  one-question opener
    s = kit.blank(prs)
    kit.header(s, "THE QUESTION", "One question for this talk")
    kit.text(s, 0.9, 2.25, 11.5, 2.30,
             "Does a second cue change the decision itself, or only make the "
             "same decision faster?", size=40, bold=True)
    kit.text(s, 0.9, 5.55, 11.5, 0.45,
             "Everything that follows is in service of this one question.",
             size=20, color=kit.MUTED)
    kit.foot(s)
    kit.notes(
        s,
        "一个问题：第二个线索改变决策吗",
        "The whole report turns on one question: does a second cue change "
        "the decision itself, or only make the same decision faster? That "
        "distinction decides what I have to measure. To make the question "
        "testable, I first need a definition.",
        "整个报告只围绕一个问题：第二个线索是改变了决策本身，还是只是让同一个"
        "决策更快？这个区分决定了我要测什么。要让它可检验，先要有一个定义。",
    )

    # 3  background with a cited figure
    s = kit.blank(prs)
    kit.header(s, "BACKGROUND", "Faster is not the same as integrated")
    kit.fig(s, "literature_panel.png", 0.55, 1.35, 7.9, 4.75,
            "Example et al., 2025")
    kit.body(s, 8.25, 1.45, 4.55, 4.4,
             ["Two cues can speed up a response without being combined.",
              "The published panels show the effect; the open question is "
              "what produces it."],
             size=22)
    kit.foot(s)
    kit.notes(
        s,
        "两个线索不等于整合",
        "Two cues together are not automatically integration. The published "
        "work shows that a second cue changes the response, but a change in "
        "speed alone is also what a simple race predicts. That definition "
        "fixes what I have to measure.",
        "两个线索一起出现，并不自动等于整合。已发表的工作显示第二个线索会改变"
        "反应，但速度变化本身也符合简单 race 的预测。这个定义决定了我要测什么。",
    )

    # 4  framework
    s = kit.blank(prs)
    kit.header(s, "PURPOSE & FRAMEWORK", "One decision unit, two input routes")
    kit.schem(s, "framework.png", 2.37, 1.55)
    kit.body(s, 1.15, 5.05, 11.0, 0.95,
             "Both senses feed the same decision unit; the question is how "
             "that unit combines them.", size=22, align="center")
    kit.foot(s)
    kit.notes(
        s,
        "一个决策单元承接两路输入",
        "The framework is one decision unit fed by both senses. Each input "
        "has its own route into the unit, and the routes can differ. The "
        "rest of the deck asks what that unit does with the two inputs.",
        "框架是一个决策单元，由两种感觉共同输入。每路输入进入单元的方式可以不同，"
        "后面的报告就是问这个单元如何处理两路输入。",
    )

    # 5  results: assertion title, figure, one caption sentence
    s = kit.blank(prs)
    kit.header(s, "RESULTS", "The second cue helps only when it leads")
    kit.fig(s, "result_panel.png", 2.37, 1.30, 9.0, 4.55)
    kit.body(s, 1.15, 5.98, 11.0, 0.40,
             "Latency change against the lead of the second cue.",
             size=20, align="center")
    kit.foot(s)
    kit.notes(
        s,
        "只有领先的线索才有效",
        "The second cue only helps when it leads the first. When the two "
        "arrive together, the response is no faster than the single-cue "
        "baseline. That pattern is what the next experiment has to confirm.",
        "第二个线索只有在先到时才有帮助。两者同时到达时，反应并不比单线索基线更"
        "快。这个模式正是下一个实验要确认的。",
    )

    # 6  summary text page
    s = kit.blank(prs)
    kit.header(s, "SUMMARY", "Summary")
    kit.body(s, 0.9, 1.55, 11.6, 3.40,
             ["The question is decision-level, not just latency.",
              "The framework is one decision unit with two input routes.",
              "The first data support an effect only when one cue leads."],
             size=24, bullet=True, space=12)
    kit.text(s, 0.9, 4.55, 11.6, 0.45, "Questions for the group",
             size=24, bold=True)
    kit.body(s, 0.9, 5.15, 11.6, 0.90,
             ["Is the race bound the right null for this design?",
              "Which control would separate the two routes?"],
             size=20, bullet=True, space=4)
    kit.foot(s)
    kit.notes(
        s,
        "总结三点，请教两个问题",
        "Three points. The question is decision-level, the framework is one "
        "decision unit with two input routes, and the first data support an "
        "effect only when one cue leads. I would like the group's view on "
        "the race null and on the control that would separate the routes.",
        "三点。问题在决策层面；框架是一个决策单元加两路输入；首批数据只在某一"
        "线索领先时支持效应。想请教大家：race 零模型是否合适，以及哪个对照能"
        "分开这两条通路。",
    )

    kit.self_check(prs)
    prs.save(str(out_path))
    print(f"saved {out_path}")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: python progress_build.py out/demo.pptx")
    out_path = Path(sys.argv[1]).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        figs = Path(tmp)
        literature_figure(figs)
        results_figure(figs)
        schematic_figure(figs)
        build(out_path, figs)


if __name__ == "__main__":
    main()
