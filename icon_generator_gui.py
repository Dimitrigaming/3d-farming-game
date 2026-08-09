#!/usr/bin/env python3
"""
icon_generator_gui.py — GUI tool for generating placeholder item icons
for the 3d-farming-game project.

Renders bold, centered, auto-wrapped text on a solid colored square at a
high supersample resolution, then downsamples with LANCZOS filtering to
produce crisp 36x36 PNGs. All icons from one run are saved flat into a
single folder you choose when you click "Generate Icons" — no category
subfolders.

Requires: Pillow  (pip install pillow)
Run with: python icon_generator_gui.py
"""

import json
import re
import tkinter as tk
from pathlib import Path
from tkinter import ttk, filedialog, messagebox, colorchooser

from PIL import Image, ImageDraw, ImageFont, ImageTk

RENDER_SIZE = 512
ICON_SIZE = 36

WINDOWS_BOLD_FONT_CANDIDATES = [
    r"C:\Windows\Fonts\segoeuib.ttf",   # Segoe UI Bold
    r"C:\Windows\Fonts\arialbd.ttf",    # Arial Bold
]

_font_cache = {}


# ---------------------------------------------------------------------------
# Core rendering logic (same approach as the CLI batch script)
# ---------------------------------------------------------------------------

def resolve_default_font_path():
    for candidate in WINDOWS_BOLD_FONT_CANDIDATES:
        if Path(candidate).exists():
            return candidate
    return None


def load_font(font_path, size):
    key = (font_path, size)
    if key in _font_cache:
        return _font_cache[key]
    if font_path:
        font = ImageFont.truetype(font_path, size)
    else:
        try:
            font = ImageFont.load_default(size=size)
        except TypeError:
            font = ImageFont.load_default()
    _font_cache[key] = font
    return font


def slugify(text):
    s = text.strip().lower()
    s = re.sub(r"\s+", "_", s)
    s = re.sub(r"[^a-z0-9_]", "", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s or "item"


def text_size(draw, text, font):
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    return right - left, bottom - top


def wrap_to_lines(draw, text, font, max_width):
    hard_lines = text.split("\n")
    if len(hard_lines) >= 2:
        return hard_lines[:2]
    words = text.split()
    if not words:
        return [text]
    w, _ = text_size(draw, text, font)
    if w <= max_width or len(words) == 1:
        return [text]
    best_split, best_diff = None, None
    for i in range(1, len(words)):
        line1, line2 = " ".join(words[:i]), " ".join(words[i:])
        w1, _ = text_size(draw, line1, font)
        w2, _ = text_size(draw, line2, font)
        diff = abs(w1 - w2)
        if best_diff is None or diff < best_diff:
            best_diff, best_split = diff, i
    return [" ".join(words[:best_split]), " ".join(words[best_split:])]


def fit_text(draw, text, font_path, box_size, padding_ratio=0.12,
             max_font_size=200, min_font_size=14, step=4):
    padding = int(box_size * padding_ratio)
    max_w = box_size - 2 * padding
    max_h = box_size - 2 * padding
    last_attempt = None
    for size in range(max_font_size, min_font_size - 1, -step):
        font = load_font(font_path, size)
        lines = wrap_to_lines(draw, text, font, max_w)
        line_heights = [text_size(draw, line, font)[1] for line in lines]
        line_widths = [text_size(draw, line, font)[0] for line in lines]
        total_h = sum(line_heights) + (len(lines) - 1) * int(size * 0.25)
        total_w = max(line_widths) if line_widths else 0
        last_attempt = (font, lines, line_heights)
        if total_w <= max_w and total_h <= max_h:
            return font, lines, line_heights
    return last_attempt


def render_icon(text, bg_color, text_color, font_path,
                 render_size=RENDER_SIZE, icon_size=ICON_SIZE):
    img = Image.new("RGB", (render_size, render_size), bg_color)
    draw = ImageDraw.Draw(img)
    font, lines, line_heights = fit_text(draw, text, font_path, render_size)
    line_gap = int(font.size * 0.25) if hasattr(font, "size") else 8
    total_h = sum(line_heights) + line_gap * (len(lines) - 1)
    y = (render_size - total_h) / 2
    for line, lh in zip(lines, line_heights):
        w, _ = text_size(draw, line, font)
        x = (render_size - w) / 2
        draw.text((x, y), line, font=font, fill=text_color)
        y += lh + line_gap
    return img.resize((icon_size, icon_size), Image.LANCZOS)


# ---------------------------------------------------------------------------
# GUI
# ---------------------------------------------------------------------------

class IconGeneratorApp:
    def __init__(self, root):
        self.root = root
        root.title("Icon Generator")
        root.geometry("560x560")
        root.minsize(480, 440)

        self.font_path = resolve_default_font_path()  # None -> built-in fallback
        self.filename_dirty = False  # tracks whether user hand-edited the filename field

        self._build_widgets()

    # -- layout -------------------------------------------------------

    def _build_widgets(self):
        pad = {"padx": 8, "pady": 4}

        top = ttk.Frame(self.root)
        top.pack(fill="x", **pad)

        # BG color
        ttk.Label(top, text="BG color").grid(row=0, column=0, sticky="w")
        self.bg_var = tk.StringVar(value="#4a4a4a")
        bg_entry = ttk.Entry(top, textvariable=self.bg_var, width=12)
        bg_entry.grid(row=0, column=1, sticky="w", padx=(4, 4))
        self.bg_swatch = tk.Canvas(top, width=22, height=22, highlightthickness=1,
                                    highlightbackground="#888")
        self.bg_swatch.grid(row=0, column=2, sticky="w")
        self.bg_swatch.bind("<Button-1>", lambda e: self._pick_color(self.bg_var))
        self.bg_var.trace_add("write", lambda *a: self._update_swatch(self.bg_swatch, self.bg_var))

        # Font color
        ttk.Label(top, text="Font color").grid(row=1, column=0, sticky="w")
        self.fg_var = tk.StringVar(value="#ffffff")
        fg_entry = ttk.Entry(top, textvariable=self.fg_var, width=12)
        fg_entry.grid(row=1, column=1, sticky="w", padx=(4, 4))
        self.fg_swatch = tk.Canvas(top, width=22, height=22, highlightthickness=1,
                                    highlightbackground="#888")
        self.fg_swatch.grid(row=1, column=2, sticky="w")
        self.fg_swatch.bind("<Button-1>", lambda e: self._pick_color(self.fg_var))
        self.fg_var.trace_add("write", lambda *a: self._update_swatch(self.fg_swatch, self.fg_var))

        # Font path
        ttk.Label(top, text="Font Path").grid(row=2, column=0, sticky="w")
        self.font_label_var = tk.StringVar(value=self._font_display())
        ttk.Button(top, text="Browse font file…", command=self._browse_font).grid(
            row=2, column=1, columnspan=2, sticky="w", padx=(4, 4))
        ttk.Label(top, textvariable=self.font_label_var, foreground="#555").grid(
            row=3, column=0, columnspan=3, sticky="w", padx=(0, 0))

        self._update_swatch(self.bg_swatch, self.bg_var)
        self._update_swatch(self.fg_swatch, self.fg_var)

        # -- Items section --
        items_frame = ttk.LabelFrame(self.root, text="Items")
        items_frame.pack(fill="both", expand=True, **pad)

        example_row = ttk.Frame(items_frame)
        example_row.pack(fill="x", padx=6, pady=(6, 2))
        ttk.Button(example_row, text="Generate Example Batch JSON…",
                   command=self._generate_example_json).pack(fill="x")

        entry_row = ttk.Frame(items_frame)
        entry_row.pack(fill="x", padx=6, pady=(2, 2))

        ttk.Label(entry_row, text="text").grid(row=0, column=0, sticky="w")
        self.text_var = tk.StringVar()
        text_entry = ttk.Entry(entry_row, textvariable=self.text_var)
        text_entry.grid(row=0, column=1, sticky="ew", padx=4)
        text_entry.bind("<Return>", lambda e: self._add_item())
        text_entry.bind("<KeyRelease>", self._on_text_changed)

        ttk.Button(entry_row, text="Add", command=self._add_item).grid(row=0, column=2, padx=(4, 0))
        ttk.Button(entry_row, text="Load Batch JSON…", command=self._load_batch_json).grid(
            row=0, column=3, padx=(4, 0))

        ttk.Label(entry_row, text="file name").grid(row=1, column=0, sticky="w")
        self.filename_var = tk.StringVar()
        filename_entry = ttk.Entry(entry_row, textvariable=self.filename_var)
        filename_entry.grid(row=1, column=1, sticky="ew", padx=4, pady=(4, 0))
        filename_entry.bind("<KeyRelease>", lambda e: setattr(self, "filename_dirty", True))

        entry_row.columnconfigure(1, weight=1)

        # Item list
        list_frame = ttk.Frame(items_frame)
        list_frame.pack(fill="both", expand=True, padx=6, pady=(6, 6))

        columns = ("text", "filename")
        self.tree = ttk.Treeview(list_frame, columns=columns, show="headings", height=10)
        self.tree.heading("text", text="Text")
        self.tree.heading("filename", text="File name")
        self.tree.column("text", width=250)
        self.tree.column("filename", width=200)
        self.tree.pack(side="left", fill="both", expand=True)

        scrollbar = ttk.Scrollbar(list_frame, orient="vertical", command=self.tree.yview)
        scrollbar.pack(side="left", fill="y")
        self.tree.configure(yscrollcommand=scrollbar.set)

        list_btns = ttk.Frame(items_frame)
        list_btns.pack(fill="x", padx=6, pady=(0, 6))
        ttk.Button(list_btns, text="Remove Selected", command=self._remove_selected).pack(side="left")
        ttk.Button(list_btns, text="Clear All", command=self._clear_all).pack(side="left", padx=(6, 0))
        self.count_label = ttk.Label(list_btns, text="0 items")
        self.count_label.pack(side="right")

        # Generate button
        gen_frame = ttk.Frame(self.root)
        gen_frame.pack(fill="x", **pad)
        ttk.Button(gen_frame, text="Generate Icons", command=self._generate).pack(fill="x", ipady=6)

        self.status_var = tk.StringVar(value="")
        ttk.Label(self.root, textvariable=self.status_var, foreground="#555").pack(
            fill="x", padx=8, pady=(0, 6))

    # -- helpers --------------------------------------------------------

    def _font_display(self):
        return f"Custom: {self.font_path}" if self.font_path else "Default (Segoe UI Bold / Arial Bold)"

    def _update_swatch(self, canvas, var):
        color = var.get().strip()
        try:
            canvas.configure(bg=color)
        except tk.TclError:
            pass  # invalid/incomplete hex while typing; ignore until valid

    def _pick_color(self, var):
        initial = var.get().strip() or "#ffffff"
        try:
            rgb, hex_color = colorchooser.askcolor(color=initial)
        except tk.TclError:
            rgb, hex_color = colorchooser.askcolor()
        if hex_color:
            var.set(hex_color)

    def _browse_font(self):
        path = filedialog.askopenfilename(
            title="Choose a font file",
            filetypes=[("Font files", "*.ttf *.otf"), ("All files", "*.*")],
        )
        if path:
            self.font_path = path
            self.font_label_var.set(self._font_display())

    def _on_text_changed(self, event=None):
        if not self.filename_dirty:
            self.filename_var.set(slugify(self.text_var.get()))

    def _add_item(self):
        text = self.text_var.get().strip()
        if not text:
            return
        filename = self.filename_var.get().strip() or slugify(text)
        self.tree.insert("", "end", values=(text, filename))
        self.text_var.set("")
        self.filename_var.set("")
        self.filename_dirty = False
        self._update_count()

    def _remove_selected(self):
        for item in self.tree.selection():
            self.tree.delete(item)
        self._update_count()

    def _clear_all(self):
        for item in self.tree.get_children():
            self.tree.delete(item)
        self._update_count()

    def _update_count(self):
        self.count_label.configure(text=f"{len(self.tree.get_children())} items")

    def _generate_example_json(self):
        path = filedialog.asksaveasfilename(
            title="Save example batch JSON",
            defaultextension=".json",
            initialfile="example_batch.json",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")],
        )
        if not path:
            return

        example = {
            "_note": (
                "\"defaults\" is optional and applies to the whole batch. "
                "Each item needs at least \"text\". \"filename\" is optional "
                "and auto-generated from text (e.g. 'Wood Planks' -> 'wood_planks') "
                "if you leave it out. Add as many items as you want to the list."
            ),
            "defaults": {
                "bg_color": "#4a4a4a",
                "text_color": "#ffffff",
                "font_path": None,
            },
            "items": [
                {"text": "Wood Planks"},
                {"text": "Rusty Sickle", "filename": "rusty_sickle_v2"},
            ],
        }

        try:
            Path(path).write_text(json.dumps(example, indent=2), encoding="utf-8")
        except Exception as e:
            messagebox.showerror("Save failed", f"Could not write that file:\n{e}")
            return

        self.status_var.set(f"Example JSON saved to {path}")
        messagebox.showinfo(
            "Example saved",
            f"Saved an example batch file to:\n{path}\n\n"
            "Open it in a text editor, duplicate an entry in \"items\" for each "
            "row you want, then use \"Load Batch JSON…\" to import it.",
        )

    def _load_batch_json(self):
        path = filedialog.askopenfilename(
            title="Load batch JSON",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")],
        )
        if not path:
            return
        try:
            data = json.loads(Path(path).read_text(encoding="utf-8"))
        except Exception as e:
            messagebox.showerror("Load failed", f"Could not read that JSON file:\n{e}")
            return

        # Optional global settings in the file update the top fields.
        defaults = data.get("defaults", data)  # tolerate flat or {"defaults": {...}} shape
        if isinstance(defaults, dict):
            if defaults.get("bg_color"):
                self.bg_var.set(defaults["bg_color"])
            if defaults.get("text_color"):
                self.fg_var.set(defaults["text_color"])
            if defaults.get("font_path"):
                self.font_path = defaults["font_path"]
                self.font_label_var.set(self._font_display())

        items = data.get("items", [])
        added = 0
        for item in items:
            text = (item.get("text") or "").strip()
            if not text:
                continue
            filename = (item.get("filename") or item.get("item_id") or slugify(text)).strip()
            self.tree.insert("", "end", values=(text, filename))
            added += 1
        self._update_count()
        self.status_var.set(f"Loaded {added} item(s) from {Path(path).name}")

    def _generate(self):
        rows = self.tree.get_children()
        if not rows:
            messagebox.showinfo("Nothing to generate", "Add at least one item first.")
            return

        bg_color = self.bg_var.get().strip() or "#4a4a4a"
        text_color = self.fg_var.get().strip() or "#ffffff"

        out_dir = filedialog.askdirectory(title="Choose a folder to save icons into")
        if not out_dir:
            return
        out_dir = Path(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)

        ok, failed = 0, []
        for row in rows:
            text, filename = self.tree.item(row, "values")
            try:
                icon = render_icon(text, bg_color, text_color, self.font_path)
                out_path = out_dir / f"{filename}.png"
                icon.save(out_path)
                ok += 1
            except Exception as e:
                failed.append(f"{filename}: {e}")

        msg = f"Generated {ok} icon(s) into:\n{out_dir}"
        if failed:
            msg += "\n\nFailed:\n" + "\n".join(failed)
        self.status_var.set(f"Done — {ok} icon(s) saved to {out_dir}")
        messagebox.showinfo("Generate Icons", msg)


def main():
    root = tk.Tk()
    IconGeneratorApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
