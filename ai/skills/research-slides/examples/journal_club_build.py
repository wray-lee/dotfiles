"""Build a seven-slide demo journal-club deck with placeholder figures.

Usage::

    python journal_club_build.py path/to/demo.pptx

The deck follows the journal-club skeleton: title, background schematic,
one result with figure plus side text, two figures with a caption below,
a discussion schematic, a text-only summary, and one backup.  Placeholder
figures are drawn with matplotlib at 300 dpi and at the print size their
crop would have, so the magnification checks in ``jc_kit.fig`` are real.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Circle, FancyArrowPatch, Rectangle  # noqa: E402

KIT = Path(__file__).resolve().parents[1] / "kit"
sys.path.insert(0, str(KIT))

import jc_kit as kit  # noqa: E402

matplotlib.rcParams.update({
    "font.family": "Arial",
    "font.size": 8,
    "axes.edgecolor": "#" + kit.INK,
    "axes.labelcolor": "#" + kit.INK,
    "xtick.color": "#" + kit.INK,
    "ytick.color": "#" + kit.INK,
    "axes.linewidth": 0.8,
})


def bar_figure(out: Path, w: float, h: float, title: str) -> Path:
    """A one-panel stand-in for a published figure."""
    fig, ax = plt.subplots(figsize=(w, h), dpi=300)
    fig.subplots_adjust(left=max(0.16, 0.44 / w), right=0.96,
                        bottom=max(0.24, 0.30 / h), top=0.80)
    labels = ["song", "vibration"]
    values = [0.31, 0.74]
    ax.bar(labels, values, width=0.55,
           color=["#" + kit.ACCENT, "#" + kit.ORANGE])
    ax.errorbar(labels, values, yerr=[0.04, 0.07], fmt="none",
                ecolor="#" + kit.INK, elinewidth=0.8, capsize=2)
    ax.set_ylabel("interval (s)")
    ax.set_title(title, fontsize=9)
    ax.spines[["top", "right"]].set_visible(False)
    fig.savefig(out, dpi=300)
    plt.close(fig)
    return out


def schematic(out: Path, w: float, h: float, discussion: bool) -> Path:
    """A drawn schematic at exactly its final slide size."""
    fig, ax = plt.subplots(figsize=(w, h), dpi=300)
    ax.set_xlim(0, w)
    ax.set_ylim(0, h)
    ax.axis("off")
    if not discussion:
        ax.add_patch(Circle((2.0, h * 0.58), 0.55, fc="#E8EEF5",
                            ec="#" + kit.INK, lw=1.2))
        ax.text(2.0, h * 0.58, "male", ha="center", va="center", fontsize=11)
        ax.add_patch(Circle((5.9, h * 0.58), 0.55, fc="#F5EDE4",
                            ec="#" + kit.INK, lw=1.2))
        ax.text(5.9, h * 0.58, "female", ha="center", va="center",
                fontsize=11)
        ax.add_patch(FancyArrowPatch((1.6, h * 0.78), (1.2, h * 0.95),
                                     arrowstyle="-|>", mutation_scale=12,
                                     color="#" + kit.ACCENT, lw=2))
        ax.text(0.25, h * 0.90, "song (air)", fontsize=10,
                color="#" + kit.ACCENT)
        ax.add_patch(FancyArrowPatch((2.3, h * 0.30), (2.3, h * 0.08),
                                     arrowstyle="-|>", mutation_scale=12,
                                     color="#" + kit.ORANGE, lw=2))
        ax.text(2.55, h * 0.10, "vibration (floor)", fontsize=10,
                color="#" + kit.ORANGE)
        ax.plot([0.4, 8.0], [h * 0.06, h * 0.06], color="#" + kit.INK,
                lw=1)
    else:
        boxes = [("P1a", 0.7, 3.5, "#2B6CB0"), ("pC2l", 0.7, 1.3, "#2B6CB0"),
                 ("song DN", 3.4, 4.0, "#1A1A1A"),
                 ("vibration DN?", 3.4, 1.2, "#DD6B20")]
        for label, x, y, col in boxes:
            ax.add_patch(Rectangle((x, y), 1.6, 0.8, fc="white",
                                   ec=col, lw=2))
            ax.text(x + 0.8, y + 0.4, label, ha="center", va="center",
                    fontsize=10, color=col)
        ax.add_patch(FancyArrowPatch((2.3, 4.1), (3.4, 4.3),
                                     arrowstyle="-|>", mutation_scale=12,
                                     color="#" + kit.INK, lw=1.5))
        ax.add_patch(FancyArrowPatch((2.3, 1.7), (3.4, 1.6),
                                     arrowstyle="-|>", mutation_scale=12,
                                     color="#" + kit.ORANGE, lw=1.5,
                                     linestyle="--"))
        ax.add_patch(Rectangle((5.3, 0.7), 0.1, 4.2, fc="#" + kit.MUTED))
    fig.savefig(out, dpi=300)
    plt.close(fig)
    return out


def build(out: Path, work: Path) -> None:
    fig_side = bar_figure(work / "fig_side.png", 2.6, 1.9, "demo")
    fig_a = bar_figure(work / "fig_a.png", 1.8, 1.3, "a")
    fig_b = bar_figure(work / "fig_b.png", 1.4, 1.0, "b")
    fig_backup = bar_figure(work / "fig_backup.png", 2.0, 1.2, "stats")
    sch_bg = schematic(work / "sch_background.png", 8.2, 4.7, False)
    sch_dis = schematic(work / "sch_discussion.png", 5.6, 5.3, True)

    prs = kit.new_deck()

    s = kit.slide_title(
        prs,
        "JOURNAL CLUB  ·  DEMO ET AL., 2026",
        "A toy circuit for two courtship signals",
        "Ada Demo, Bo Example & Cy Placeholder",
        "Journal of Examples 1:1 (2026)  ·  doi:10.0000/demo",
    )
    kit.notes(
        s, "一个回路，两种信号",
        "A single small circuit can produce two courtship signals. The paper "
        "asks how one brain switches between an airborne song and a "
        "substrate-borne vibration. It answers with anatomy, optogenetics "
        "and a rate model. I will follow that order. We start with the "
        "behaviour.",
        "一个小回路就能产生两种求偶信号。文章问的是一个大脑如何在空气传播的歌声"
        "与地面传播的振动之间切换。它用解剖、光遗传和速率模型来回答。我按这个顺序讲。"
        "先从行为开始。",
    )

    s = kit.slide_schematic_text(
        prs, "BACKGROUND", "A courting male has two signal channels",
        sch_bg, "Schematic; facts from Demo et al., 2026",
        "Song travels through the air and is heard with the antennae. "
        "Vibration travels through the floor and is felt with the legs.",
        schem_x=0.18, schem_y=1.42, schem_w=8.2, schem_h=4.7,
        text_x=8.53, text_y=2.21, text_w=4.25, text_h=3.8,
    )
    kit.notes(
        s, "空气与地面两条通道",
        "The male sends song through air and vibration through the floor. "
        "Song is made by one wing and sensed by the antennae; vibration "
        "passes through the legs and is sensed by leg mechanosensors. Both "
        "change female behaviour. So what was known about the brain?",
        "雄性把歌声送进空气，把振动送进地面。歌声由一只翅膀产生，由触角感知；"
        "振动经腿传递，由腿上的机械感受器感知。两者都会改变雌性的行为。"
        "那么，关于大脑已经知道什么？",
    )

    s = kit.slide_fig_side(
        prs, "RESULTS", "The song pathway was mapped; vibration was not",
        fig_side, "Demo et al., 2026, Fig. 1b",
        "The song pathway was traced from central neurons to descending "
        "neurons. No vibration neuron was known.",
    )
    kit.notes(
        s, "歌声通路已知，振动通路未知",
        "The song pathway was already mapped; the vibration pathway was "
        "not. Central song neurons connect to descending neurons that relay "
        "to the wing circuit. For vibration, no such chain was known. This "
        "is the gap the paper fills.",
        "歌声通路此前已经画出来了，振动通路却没有。中央歌声神经元连接到把信号"
        "传给翅膀回路的下行神经元。振动则没有已知的链条。这就是文章要补的空白。",
    )

    s = kit.slide_two_figs_caption(
        prs, "RESULTS", "The two signals are alternatives",
        fig_a, "Demo et al., 2026, Fig. 1h",
        fig_b, "Demo et al., 2026, Fig. 1i",
        "Males switch between song and vibration, and the choice is "
        "predicted by whether the pair stands still.",
    )
    kit.notes(
        s, "两种信号互为替代",
        "The two signals are alternatives, not a fixed sequence. Males "
        "switch between them, and the switch is predicted by the pair's "
        "movement: vibration needs a stationary pair. The next question is "
        "which neurons drive each output.",
        "两种信号是替代关系，不是固定顺序。雄性在两者之间切换，而切换可以由"
        "一对果蝇是否静止来预测：振动需要双方停住。下一个问题是，哪些神经元驱动"
        "各自的输出。",
    )

    s = kit.slide_schematic_text(
        prs, "DISCUSSION", "Where the claims stop",
        sch_dis, "Layout after Demo et al., 2026, Fig. 6a",
        "Orange parts are inferred. The vibration descending neuron and "
        "the inhibitory cells are unidentified; only activation was used "
        "to map P1a and pC2l.",
    )
    kit.notes(
        s, "结论止于何处",
        "Two nodes are inferred, not shown. The vibration descending neuron "
        "and the inhibitory cells are unidentified. Only activation, not "
        "blockade, was used to map P1a and pC2l. These limits do not "
        "overturn the model, but they bound it.",
        "有两个节点是推断的，并没有被直接展示：振动下行神经元和抑制性细胞都还"
        "没有鉴定。P1a 与 pC2l 的映射只用了激活，没有用阻断。这些限制不推翻模型，"
        "但划出了它的边界。",
    )

    s = kit.slide_summary(
        prs, "CONCLUSION", "Summary",
        [
            "Courting males use two largely exclusive signals with "
            "different statistics.",
            "Signal choice is predictable from the pair's movement.",
            "P1a and pC2l drive both outputs through separate descending "
            "pathways.",
            "A rate model with recurrence and mutual inhibition reproduces "
            "the switch.",
        ],
        credit="Figures adapted from Demo et al., 2026, CC BY 4.0.",
    )
    kit.notes(
        s, "四点结论",
        "Four claims survive the evidence. The signals are exclusive and "
        "differ in statistics; choice follows movement; two central cell "
        "types drive both outputs through separate pathways; and a small "
        "rate model reproduces the dynamics. I will take questions.",
        "有四条结论站得住：两种信号基本互斥且统计不同；选择跟随运动状态；"
        "两类中央细胞通过独立通路驱动两种输出；一个小型速率模型复现了动力学。"
        "接下来提问。",
    )

    s = kit.slide_backup(
        prs, "BACKUP · SIGNAL STATISTICS", "Signal statistics in full",
        fig_backup, "Demo et al., 2026, Fig. 1f–h",
        "Pulse interval 35 ms; vibration interval 160 ms (medians).\n"
        "Vibration trains last about 2.8 s; song bouts about 0.6 s.\n"
        "Overlap between the two signals is near zero.",
        tag="B1", bullets=True,
    )
    kit.notes(
        s, "完整统计量",
        "These are the numbers behind the summary. The median pulse "
        "interval is 35 ms and the median vibration interval is 160 ms. "
        "Vibration trains last about 2.8 s, song bouts about 0.6 s, and "
        "the two rarely overlap.",
        "这些是摘要背后的数字。脉冲间隔中位数是 35 毫秒，振动间隔中位数是 160 毫秒。"
        "振动串约 2.8 秒，歌声段约 0.6 秒，两者很少重叠。",
    )

    report = kit.self_check(prs)
    prs.save(str(out))
    print(f"saved {out} ({report['slides']} slides)")


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python journal_club_build.py output.pptx")
        return 2
    out = Path(argv[0]).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="jc_example_") as tmp:
        build(out, Path(tmp))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
