"""Prototipo de IDE grafico para archivos FCC .f."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from ide_analysis import FCCIDEAnalyzer, TYPE_TOKENS


PROJECT_ROOT = Path(__file__).resolve().parent.parent
KEYWORD_KINDS = {
    "FUNC",
    "RET",
    "VOID",
    "INT",
    "FLOAT",
    "BOOL",
    "CHAR",
    "IF",
    "ELIF",
    "ELSE",
    "FOR",
    "WHILE",
    "VAULT",
    "TRUE",
    "FALSE",
    "TRAIGASE",
    "MAIN",
    "CONTINUE",
    "BREAK",
    "SECURE",
}


class FCCIDE(tk.Tk):
    """Ventana principal del prototipo de IDE."""

    def __init__(self):
        super().__init__()
        self.title("FCC IDE - Prototipo")
        self.geometry("1180x760")
        self.minsize(900, 560)

        self.analyzer = FCCIDEAnalyzer()
        self.current_file: Path | None = None
        self.pending_analysis: str | None = None
        self.last_result = None
        self.applying_correction = False
        self.suggestion_popup: tk.Toplevel | None = None
        self.suggestion_list: tk.Listbox | None = None
        self.visible_suggestion_texts: list[str] = []

        self._build_ui()
        self._configure_tags()
        self._insert_template()
        self._analyze_now()

    def _build_ui(self):
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        toolbar = ttk.Frame(self, padding=(8, 6))
        toolbar.grid(row=0, column=0, sticky="ew")

        ttk.Button(toolbar, text="Nuevo", command=self._new_file).pack(side="left", padx=(0, 6))
        ttk.Button(toolbar, text="Abrir", command=self._open_file).pack(side="left", padx=(0, 6))
        ttk.Button(toolbar, text="Guardar", command=self._save_file).pack(side="left", padx=(0, 6))
        ttk.Button(toolbar, text="Guardar como", command=self._save_as).pack(side="left", padx=(0, 12))
        ttk.Button(toolbar, text="Analizar", command=lambda: self._analyze_now(force_corrections=True)).pack(side="left", padx=(0, 6))
        ttk.Button(toolbar, text="Compilar", command=self._compile_current).pack(side="left", padx=(0, 12))

        self.status_var = tk.StringVar(value="Listo")
        ttk.Label(toolbar, textvariable=self.status_var).pack(side="right")

        editor_frame = ttk.Frame(self)
        editor_frame.grid(row=1, column=0, sticky="nsew")
        editor_frame.rowconfigure(0, weight=1)
        editor_frame.columnconfigure(0, weight=1)

        self.editor = tk.Text(
            editor_frame,
            wrap="none",
            undo=True,
            font=("Consolas", 12),
            padx=10,
            pady=8,
            insertwidth=2,
        )
        self.editor.grid(row=0, column=0, sticky="nsew")

        yscroll = ttk.Scrollbar(editor_frame, orient="vertical", command=self.editor.yview)
        yscroll.grid(row=0, column=1, sticky="ns")
        xscroll = ttk.Scrollbar(editor_frame, orient="horizontal", command=self.editor.xview)
        xscroll.grid(row=1, column=0, sticky="ew")
        self.editor.configure(yscrollcommand=yscroll.set, xscrollcommand=xscroll.set)

        self.editor.bind("<<Modified>>", self._on_modified)
        self.editor.bind("<Control-space>", self._show_suggestions)
        self.editor.bind("<Escape>", self._hide_suggestions)
        self.editor.bind("<Control-s>", lambda _event: self._save_file())
        self.editor.bind("<KeyPress-parenleft>", lambda _event: self._insert_pair("(", ")"))
        self.editor.bind("<KeyPress-braceleft>", lambda _event: self._insert_pair("{", "}"))
        self.editor.bind("<KeyPress-bracketleft>", lambda _event: self._insert_pair("[", "]"))

        bottom = ttk.Frame(self, padding=(8, 4, 8, 8))
        bottom.grid(row=2, column=0, sticky="nsew")
        bottom.rowconfigure(0, weight=1)
        bottom.columnconfigure(0, weight=1)

        self.diagnostics_tree = ttk.Treeview(
            bottom,
            columns=("linea", "columna", "mensaje"),
            show="headings",
            height=8,
        )
        self.diagnostics_tree.heading("linea", text="Linea")
        self.diagnostics_tree.heading("columna", text="Columna")
        self.diagnostics_tree.heading("mensaje", text="Descripcion")
        self.diagnostics_tree.column("linea", width=70, anchor="center")
        self.diagnostics_tree.column("columna", width=80, anchor="center")
        self.diagnostics_tree.column("mensaje", width=900, anchor="w")
        self.diagnostics_tree.grid(row=0, column=0, sticky="nsew")
        self.diagnostics_tree.bind("<Double-Button-1>", self._goto_diagnostic)

        diag_scroll = ttk.Scrollbar(bottom, orient="vertical", command=self.diagnostics_tree.yview)
        diag_scroll.grid(row=0, column=1, sticky="ns")
        self.diagnostics_tree.configure(yscrollcommand=diag_scroll.set)

    def _configure_tags(self):
        self.editor.tag_configure("keyword", foreground="#1f5fbf")
        self.editor.tag_configure("literal", foreground="#1f7a4d")
        self.editor.tag_configure("operator", foreground="#875f00")
        self.editor.tag_configure("error", foreground="#b00020", underline=True)
        self.editor.tag_configure("current_error", background="#ffe4e8")

    def _insert_template(self):
        self.editor.insert(
            "1.0",
            "func void main(){\n"
            "    int x = 0;\n"
            "    ret;\n"
            "}\n",
        )

    def _on_modified(self, _event=None):
        if not self.editor.edit_modified():
            return
        self.editor.edit_modified(False)
        if self.applying_correction:
            return
        if self.pending_analysis is not None:
            self.after_cancel(self.pending_analysis)
        self.pending_analysis = self.after(250, lambda: self._analyze_now(show_suggestions=True))

    def _index_from_offset(self, offset: int) -> str:
        return f"1.0 + {max(offset, 0)} chars"

    def _offset_from_index(self, index: str) -> int:
        count = self.editor.count("1.0", index, "chars")
        return int(count[0]) if count else 0

    def _text(self) -> str:
        return self.editor.get("1.0", "end-1c")

    def _analyze_now(self, force_corrections: bool = False, show_suggestions: bool = False):
        self.pending_analysis = None
        text = self._text()
        cursor_offset = self._offset_from_index("insert")
        self.last_result = self.analyzer.analyze(text, cursor_offset)
        if self._auto_apply_corrections(force=force_corrections):
            self.last_result = self.analyzer.analyze(self._text(), self._offset_from_index("insert"))
        self._refresh_highlighting()
        self._refresh_diagnostics()
        self._refresh_suggestion_popup()

        errors = len(self.last_result.diagnostics)
        suggestions = len(self.last_result.suggestions)
        self.status_var.set(f"{errors} error(es), {suggestions} sugerencia(s)")
        if show_suggestions:
            self._show_suggestions_from_current_result()

    def _auto_apply_corrections(self, force: bool = False) -> bool:
        if self.last_result is None or not self.last_result.corrections:
            return False

        cursor_line = int(self.editor.index("insert").split(".")[0])
        selected = []
        for correction in self.last_result.corrections:
            correction_line = int(self.editor.index(self._index_from_offset(correction.start)).split(".")[0])
            if correction.title.startswith('Agregar ";"') and cursor_line > correction_line:
                selected.append(correction)
            elif correction.title.startswith("Eliminar cierre sobrante"):
                selected.append(correction)
            elif correction.title.startswith("Agregar ") and not correction.title.startswith('Agregar ";"'):
                selected.append(correction)
            elif force and correction.title.startswith("Agregar "):
                selected.append(correction)

        if not selected:
            return False

        grouped = []
        for correction in selected:
            if grouped and grouped[-1].start == correction.start and grouped[-1].end == correction.end:
                grouped[-1].replacement += correction.replacement
                grouped[-1].title += f" + {correction.title}"
                continue
            grouped.append(correction)

        grouped.sort(key=lambda item: item.start, reverse=True)
        self.applying_correction = True
        try:
            original_insert = self._offset_from_index("insert")
            for correction in grouped:
                self.editor.delete(self._index_from_offset(correction.start), self._index_from_offset(correction.end))
                self.editor.insert(self._index_from_offset(correction.start), correction.replacement)
                if correction.start <= original_insert:
                    original_insert += len(correction.replacement) - (correction.end - correction.start)
            self.editor.mark_set("insert", self._index_from_offset(max(original_insert, 0)))
            self.editor.edit_modified(False)
        finally:
            self.applying_correction = False
        return True

    def _refresh_highlighting(self):
        for tag in ("keyword", "literal", "operator", "error", "current_error"):
            self.editor.tag_remove(tag, "1.0", "end")

        if self.last_result is None:
            return

        for token in self.last_result.tokens:
            start = self._index_from_offset(token.start)
            end = self._index_from_offset(token.end)
            if token.kind in KEYWORD_KINDS:
                self.editor.tag_add("keyword", start, end)
            elif token.kind.endswith("_LITERAL"):
                self.editor.tag_add("literal", start, end)
            elif token.kind not in {"IDENTIFIER", "MAIN", "EOF"} and token.kind not in TYPE_TOKENS:
                self.editor.tag_add("operator", start, end)

        for diagnostic in self.last_result.diagnostics:
            start = self._index_from_offset(diagnostic.start)
            end = self._index_from_offset(max(diagnostic.end, diagnostic.start + 1))
            self.editor.tag_add("error", start, end)

    def _refresh_diagnostics(self):
        self.diagnostics_tree.delete(*self.diagnostics_tree.get_children())
        if self.last_result is None:
            return
        for index, diagnostic in enumerate(self.last_result.diagnostics):
            self.diagnostics_tree.insert(
                "",
                "end",
                iid=str(index),
                values=(
                    diagnostic.line,
                    diagnostic.column + 1,
                    diagnostic.message,
                ),
            )

    def _refresh_suggestion_popup(self):
        if self.suggestion_popup is None or self.last_result is None:
            return
        self._fill_suggestion_popup()

    def _show_suggestions(self, _event=None):
        self._analyze_now()
        if self.last_result is None or not self.last_result.suggestions:
            self._hide_suggestions()
            return "break"
        self._show_suggestions_from_current_result(require_prefix=False)
        return "break"

    def _show_suggestions_from_current_result(self, require_prefix: bool = True):
        if self.last_result is None or not self.last_result.suggestions:
            self._hide_suggestions()
            return
        cursor = self._offset_from_index("insert")
        text_before = self._text()[:cursor]
        if require_prefix and (not text_before or not (text_before[-1].isalnum() or text_before[-1] == "_")):
            self._hide_suggestions()
            return
        if self.suggestion_popup is None:
            self.suggestion_popup = tk.Toplevel(self)
            self.suggestion_popup.withdraw()
            self.suggestion_popup.overrideredirect(True)
            self.suggestion_list = tk.Listbox(
                self.suggestion_popup,
                height=8,
                width=42,
                font=("Consolas", 10),
                activestyle="dotbox",
            )
            self.suggestion_list.pack(fill="both", expand=True)
            self.suggestion_list.bind("<Double-Button-1>", self._insert_suggestion)
            self.suggestion_list.bind("<Return>", self._insert_suggestion)
            self.suggestion_list.bind("<Escape>", self._hide_suggestions)

        self._fill_suggestion_popup()
        bbox = self.editor.bbox("insert")
        if bbox is None:
            self._hide_suggestions()
            return
        x, y, _width, height = bbox
        root_x = self.editor.winfo_rootx() + x
        root_y = self.editor.winfo_rooty() + y + height + 2
        self.suggestion_popup.geometry(f"+{root_x}+{root_y}")
        self.suggestion_popup.deiconify()
        self.suggestion_popup.lift()
        self.editor.focus_set()

    def _fill_suggestion_popup(self):
        if self.suggestion_list is None or self.last_result is None:
            return
        self.suggestion_list.delete(0, "end")
        self.visible_suggestion_texts = []
        for suggestion in self.last_result.suggestions:
            label = suggestion.text.replace("\n", "\\n")
            if suggestion.detail:
                label = f"{suggestion.text:<18} {suggestion.detail}"
                label = label.replace("\n", "\\n")
            self.visible_suggestion_texts.append(suggestion.text)
            self.suggestion_list.insert("end", label)
        if self.suggestion_list.size() > 0:
            self.suggestion_list.selection_set(0)

    def _hide_suggestions(self, _event=None):
        if self.suggestion_popup is not None:
            self.suggestion_popup.withdraw()
        self.editor.focus_set()
        return "break"

    def _insert_suggestion(self, _event=None):
        if self.suggestion_list is None:
            return "break"
        selection = self.suggestion_list.curselection()
        if not selection:
            return "break"
        suggestion = self.visible_suggestion_texts[selection[0]]
        cursor = self._offset_from_index("insert")
        text_before = self._text()[:cursor]
        start_offset = cursor
        for pos in range(len(text_before) - 1, -1, -1):
            if not (text_before[pos].isalnum() or text_before[pos] == "_"):
                break
            start_offset = pos
        self.editor.delete(self._index_from_offset(start_offset), self._index_from_offset(cursor))
        self.editor.insert(self._index_from_offset(start_offset), suggestion)
        self._hide_suggestions()
        self._analyze_now()
        return "break"

    def _insert_pair(self, opener: str, closer: str):
        self.applying_correction = True
        try:
            if self.editor.tag_ranges("sel"):
                start = self.editor.index("sel.first")
                end = self.editor.index("sel.last")
                selected = self.editor.get(start, end)
                self.editor.delete(start, end)
                self.editor.insert(start, opener + selected + closer)
                self.editor.mark_set("insert", f"{start} + {len(opener + selected + closer)} chars")
            else:
                insert = self.editor.index("insert")
                self.editor.insert(insert, opener + closer)
                self.editor.mark_set("insert", f"{insert} + 1 chars")
            self.editor.edit_modified(True)
        finally:
            self.applying_correction = False
        self._on_modified()
        return "break"

    def _goto_diagnostic(self, _event=None):
        selection = self.diagnostics_tree.selection()
        if not selection or self.last_result is None:
            return
        diagnostic = self.last_result.diagnostics[int(selection[0])]
        start = self._index_from_offset(diagnostic.start)
        end = self._index_from_offset(max(diagnostic.end, diagnostic.start + 1))
        self.editor.tag_remove("current_error", "1.0", "end")
        self.editor.tag_add("current_error", start, end)
        self.editor.mark_set("insert", start)
        self.editor.see(start)
        self.editor.focus_set()

    def _new_file(self):
        self.current_file = None
        self._hide_suggestions()
        self.editor.delete("1.0", "end")
        self._insert_template()
        self._analyze_now()

    def _open_file(self):
        path = filedialog.askopenfilename(
            title="Abrir archivo FCC",
            filetypes=[("FCC", "*.f"), ("Todos", "*.*")],
            initialdir=PROJECT_ROOT,
        )
        if not path:
            return
        self._hide_suggestions()
        self.current_file = Path(path)
        self.editor.delete("1.0", "end")
        self.editor.insert("1.0", self.current_file.read_text(encoding="utf-8"))
        self._analyze_now()

    def _save_file(self):
        if self.current_file is None:
            return self._save_as()
        self._analyze_now(force_corrections=True)
        self.current_file.write_text(self._text(), encoding="utf-8")
        self.status_var.set(f"Guardado: {self.current_file}")
        return "break"

    def _save_as(self):
        path = filedialog.asksaveasfilename(
            title="Guardar archivo FCC",
            defaultextension=".f",
            filetypes=[("FCC", "*.f"), ("Todos", "*.*")],
            initialdir=PROJECT_ROOT,
        )
        if not path:
            return "break"
        self.current_file = Path(path)
        self._save_file()
        return "break"

    def _compile_current(self):
        if self.current_file is None:
            result = self._save_as()
            if result == "break" and self.current_file is None:
                return
        self._analyze_now(force_corrections=True)
        self._save_file()
        command = [sys.executable, str(PROJECT_ROOT / "fcc.py"), str(self.current_file), "-c", "-s"]
        completed = subprocess.run(command, capture_output=True, text=True, cwd=str(PROJECT_ROOT))
        output = (completed.stdout or "") + (completed.stderr or "")
        if completed.returncode == 0:
            messagebox.showinfo("Compilacion FCC", output or "Compilacion completada.")
        else:
            messagebox.showerror("Compilacion FCC", output or "La compilacion fallo.")


def main():
    app = FCCIDE()
    app.mainloop()


if __name__ == "__main__":
    main()
