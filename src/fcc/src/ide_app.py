from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from ide_analysis import FCCIDEAnalyzer, TYPE_TOKENS


PROJECT_ROOT = Path(__file__).resolve().parent.parent
INDENT_UNIT = "    "
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
    """Ventana principal del IDE.

    Entradas: eventos de usuario y archivos .f.
    Salida: editor con diagnosticos, sugerencias y artefactos.
    Uso: main() cuando fcc.py se ejecuta con --ide.
    """

    def __init__(self):
        """Entradas: ninguna. Salida: UI inicializada. Uso: main."""
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
        self.compiled_paths: dict[str, Path] = {}

        self._build_ui()
        self._configure_tags()
        self._insert_template()
        self._analyze_now()

    def _build_ui(self):
        """Entradas: estado de ventana. Salida: widgets creados. Uso: __init__."""
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        # Barra superior: acciones de archivo, analisis y compilacion.
        toolbar = ttk.Frame(self, padding=(8, 6))
        toolbar.grid(row=0, column=0, sticky="ew")

        ttk.Button(toolbar, text="Nuevo", command=self._new_file).pack(side="left", padx=(0, 6))
        ttk.Button(toolbar, text="Abrir", command=self._open_file).pack(side="left", padx=(0, 6))
        ttk.Button(toolbar, text="Guardar", command=self._save_file).pack(side="left", padx=(0, 6))
        ttk.Button(toolbar, text="Guardar como", command=self._save_as).pack(side="left", padx=(0, 12))
        ttk.Button(toolbar, text="Analizar", command=lambda: self._analyze_now(force_corrections=True)).pack(side="left", padx=(0, 6))
        ttk.Button(toolbar, text="Compilar", command=self._compile_current).pack(side="left", padx=(0, 12))
        self.asm_button = ttk.Button(toolbar, text="Ensamblador", command=self._show_assembly, state="disabled")
        self.asm_button.pack(side="left", padx=(0, 6))
        self.ir_button = ttk.Button(toolbar, text="IR", command=self._show_ir, state="disabled")
        self.ir_button.pack(side="left", padx=(0, 6))
        self.bin_button = ttk.Button(toolbar, text="Bin/Hex", command=self._show_binary, state="disabled")
        self.bin_button.pack(side="left", padx=(0, 12))

        self.status_var = tk.StringVar(value="Listo")
        ttk.Label(toolbar, textvariable=self.status_var).pack(side="right")

        self.editor_frame = ttk.Frame(self)
        self.editor_frame.grid(row=1, column=0, sticky="nsew")
        self.editor_frame.rowconfigure(0, weight=1)
        self.editor_frame.columnconfigure(1, weight=1)

        # Margen de numeros calculado con las lineas visibles del Text.
        self.line_numbers = tk.Canvas(self.editor_frame, width=48, highlightthickness=0, background="#f5f5f5")
        self.line_numbers.grid(row=0, column=0, sticky="ns")
        # Editor central; los tags se aplican por offsets absolutos.
        self.editor = tk.Text(
            self.editor_frame,
            wrap="none",
            undo=True,
            font=("Consolas", 12),
            padx=10,
            pady=8,
            insertwidth=2,
        )
        self.editor.grid(row=0, column=1, sticky="nsew")

        yscroll = ttk.Scrollbar(self.editor_frame, orient="vertical", command=self._scroll_editor)
        yscroll.grid(row=0, column=2, sticky="ns")
        xscroll = ttk.Scrollbar(self.editor_frame, orient="horizontal", command=self.editor.xview)
        xscroll.grid(row=1, column=1, sticky="ew")
        self.editor.configure(yscrollcommand=lambda first, last: self._on_editor_scroll(yscroll, first, last), xscrollcommand=xscroll.set)

        self.editor.bind("<<Modified>>", self._on_modified)
        self.editor.bind("<Configure>", lambda _event: self._update_line_numbers())
        self.editor.bind("<KeyRelease>", lambda _event: self._update_line_numbers())
        self.editor.bind("<ButtonRelease-1>", lambda _event: self._update_line_numbers())
        self.editor.bind("<MouseWheel>", lambda _event: self.after_idle(self._update_line_numbers))
        self.editor.bind("<Control-space>", self._show_suggestions)
        self.editor.bind("<Escape>", self._hide_suggestions)
        self.editor.bind("<Control-s>", lambda _event: self._save_file())
        self.editor.bind("<Return>", self._handle_return)
        self.editor.bind("<Up>", lambda _event: self._move_suggestion_selection(-1))
        self.editor.bind("<Down>", lambda _event: self._move_suggestion_selection(1))
        self.editor.bind("<KeyPress-parenleft>", lambda _event: self._insert_pair("(", ")"))
        self.editor.bind("<KeyPress-braceleft>", lambda _event: self._insert_pair("{", "}"))
        self.editor.bind("<KeyPress-bracketleft>", lambda _event: self._insert_pair("[", "]"))

        self.artifact_source_frame = ttk.Frame(self)
        self.artifact_source_frame.rowconfigure(1, weight=1)
        self.artifact_source_frame.columnconfigure(0, weight=1)

        artifact_source_header = ttk.Frame(self.artifact_source_frame, padding=(8, 6))
        artifact_source_header.grid(row=0, column=0, columnspan=2, sticky="ew")
        self.source_artifact_title_var = tk.StringVar(value="")
        ttk.Label(artifact_source_header, textvariable=self.source_artifact_title_var).pack(side="left")
        ttk.Button(artifact_source_header, text="Codigo .f", command=self._show_code_editor).pack(side="right")

        self.source_artifact_viewer = tk.Text(
            self.artifact_source_frame,
            wrap="none",
            font=("Consolas", 11),
            padx=10,
            pady=8,
        )
        self.source_artifact_viewer.grid(row=1, column=0, sticky="nsew")
        artifact_source_scroll_y = ttk.Scrollbar(self.artifact_source_frame, orient="vertical", command=self.source_artifact_viewer.yview)
        artifact_source_scroll_y.grid(row=1, column=1, sticky="ns")
        artifact_source_scroll_x = ttk.Scrollbar(self.artifact_source_frame, orient="horizontal", command=self.source_artifact_viewer.xview)
        artifact_source_scroll_x.grid(row=2, column=0, sticky="ew")
        self.source_artifact_viewer.configure(
            yscrollcommand=artifact_source_scroll_y.set,
            xscrollcommand=artifact_source_scroll_x.set,
            state="disabled",
        )

        # Panel inferior: alterna entre diagnosticos y artefactos generados.
        bottom = ttk.Frame(self, padding=(8, 4, 8, 8))
        bottom.grid(row=2, column=0, sticky="nsew")
        bottom.rowconfigure(0, weight=1)
        bottom.columnconfigure(0, weight=1)

        self.diagnostics_panel = ttk.Frame(bottom)
        self.diagnostics_panel.grid(row=0, column=0, sticky="nsew")
        self.diagnostics_panel.rowconfigure(0, weight=1)
        self.diagnostics_panel.columnconfigure(0, weight=1)

        self.diagnostics_tree = ttk.Treeview(
            self.diagnostics_panel,
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

        diag_scroll = ttk.Scrollbar(self.diagnostics_panel, orient="vertical", command=self.diagnostics_tree.yview)
        diag_scroll.grid(row=0, column=1, sticky="ns")
        self.diagnostics_tree.configure(yscrollcommand=diag_scroll.set)


    def _on_editor_scroll(self, scrollbar: ttk.Scrollbar, first: str, last: str):
        """Entradas: scroll visible. Salida: sincroniza barra/lineas. Uso: Text."""
        scrollbar.set(first, last)
        self._update_line_numbers()

    def _scroll_editor(self, *args):
        """Entradas: comando scrollbar. Salida: desplaza editor. Uso: yscroll."""
        self.editor.yview(*args)
        self._update_line_numbers()

    def _update_line_numbers(self):
        """Entradas: viewport del editor. Salida: numeros visibles. Uso: eventos Text."""
        self.line_numbers.delete("all")
        index = self.editor.index("@0,0")
        while True:
            dline = self.editor.dlineinfo(index)
            if dline is None:
                # Salida del bucle: no hay mas lineas visibles.
                break
            line_no = index.split(".")[0]
            y = dline[1]
            self.line_numbers.create_text(40, y, anchor="ne", text=line_no, fill="#6a6a6a", font=("Consolas", 10))
            index = self.editor.index(f"{index}+1line")

    def _configure_tags(self):
        """Entradas: editor. Salida: estilos de resaltado. Uso: __init__."""
        self.editor.tag_configure("keyword", foreground="#1f5fbf")
        self.editor.tag_configure("literal", foreground="#1f7a4d")
        self.editor.tag_configure("operator", foreground="#875f00")
        self.editor.tag_configure("error", foreground="#b00020", underline=True)
        self.editor.tag_configure("current_error", background="#ffe4e8")

    def _insert_template(self):
        """Entradas: editor vacio. Salida: vista inicial limpia. Uso: __init__/Nuevo."""
        # El IDE inicia en blanco; los snippets se insertan desde sugerencias.
        self._update_line_numbers()

    def _on_modified(self, _event=None):
        """Entradas: evento de edicion. Salida: agenda analisis. Uso: Text."""
        if not self.editor.edit_modified():
            # Tk dispara el evento aunque la marca ya este limpia.
            return
        self.editor.edit_modified(False)
        if self.applying_correction:
            return
        if self.pending_analysis is not None:
            self.after_cancel(self.pending_analysis)
        # Debounce corto: analiza errores sin abrir sugerencias automaticamente.
        self.pending_analysis = self.after(250, self._analyze_now)
        self._update_line_numbers()

    def _index_from_offset(self, offset: int) -> str:
        """Entradas: offset absoluto. Salida: indice Tk. Uso: tags/correcciones."""
        return f"1.0 + {max(offset, 0)} chars"

    def _offset_from_index(self, index: str) -> int:
        """Entradas: indice Tk. Salida: offset absoluto. Uso: analisis/cursor."""
        count = self.editor.count("1.0", index, "chars")
        return int(count[0]) if count else 0

    def _text(self) -> str:
        """Entradas: editor. Salida: codigo sin EOF Tk. Uso: analisis/guardado."""
        return self.editor.get("1.0", "end-1c")

    def _analyze_now(self, force_corrections: bool = False, show_suggestions: bool = False):
        """Entradas: flags de analisis. Salida: UI actualizada. Uso: editor/Analizar."""
        self.pending_analysis = None
        text = self._text()
        cursor_offset = self._offset_from_index("insert")
        # Analisis completo: lexer, pila LL(1), recuperacion y sugerencias.
        self.last_result = self.analyzer.analyze(text, cursor_offset)
        if self._auto_apply_corrections(force=force_corrections):
            # Si se edito automaticamente, se analiza de nuevo sobre texto final.
            self.last_result = self.analyzer.analyze(self._text(), self._offset_from_index("insert"))
        self._refresh_highlighting()
        self._refresh_diagnostics()
        self._refresh_suggestion_popup()
        self._update_line_numbers()

        errors = len(self.last_result.diagnostics)
        suggestions = len(self.last_result.suggestions)
        self.status_var.set(f"{errors} error(es), {suggestions} sugerencia(s)")
        if show_suggestions:
            self._show_suggestions_from_current_result()

    def _auto_apply_corrections(self, force: bool = False) -> bool:
        """Entradas: correcciones detectadas. Salida: True si edito. Uso: _analyze_now."""
        if self.last_result is None or not self.last_result.corrections:
            return False

        cursor_line = int(self.editor.index("insert").split(".")[0])
        selected = []
        for correction in self.last_result.corrections:
            correction_line = int(self.editor.index(self._index_from_offset(correction.start)).split(".")[0])
            # El ';' espera a que el cursor abandone la linea para no interrumpir escritura.
            if correction.title.startswith('Agregar ";"') and cursor_line > correction_line:
                selected.append(correction)
            elif correction.title.startswith("Eliminar cierre sobrante"):
                # Los cierres extra si se eliminan de inmediato: no dependen de contexto futuro.
                selected.append(correction)
            elif correction.title.startswith("Agregar ") and not correction.title.startswith('Agregar ";"'):
                # Llaves, parentesis y corchetes faltantes se completan en caliente.
                selected.append(correction)
            elif force and correction.title.startswith("Agregar "):
                # Analizar/guardar fuerza correcciones pendientes.
                selected.append(correction)

        if not selected:
            # Nada aplicable todavia: se espera mas contexto de escritura.
            return False

        grouped = []
        for correction in selected:
            if grouped and grouped[-1].start == correction.start and grouped[-1].end == correction.end:
                # Varias inserciones en el mismo punto se unen en una sola edicion.
                grouped[-1].replacement += correction.replacement
                grouped[-1].title += f" + {correction.title}"
                continue
            grouped.append(correction)

        grouped.sort(key=lambda item: item.start, reverse=True)
        self.applying_correction = True
        try:
            original_insert = self._offset_from_index("insert")
            for correction in grouped:
                # Reemplazos de atras hacia adelante preservan offsets previos.
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
        """Entradas: ultimo analisis. Salida: tags de color/error. Uso: _analyze_now."""
        for tag in ("keyword", "literal", "operator", "error", "current_error"):
            self.editor.tag_remove(tag, "1.0", "end")

        if self.last_result is None:
            return

        for token in self.last_result.tokens:
            start = self._index_from_offset(token.start)
            end = self._index_from_offset(token.end)
            if token.kind in KEYWORD_KINDS:
                # Palabras reservadas: color azul.
                self.editor.tag_add("keyword", start, end)
            elif token.kind.endswith("_LITERAL"):
                # Literales numericos/textuales: color verde.
                self.editor.tag_add("literal", start, end)
            elif token.kind not in {"IDENTIFIER", "MAIN", "EOF"} and token.kind not in TYPE_TOKENS:
                # Operadores y separadores quedan diferenciados del texto normal.
                self.editor.tag_add("operator", start, end)

        for diagnostic in self.last_result.diagnostics:
            # Subrayado rojo sobre el rango exacto del diagnostico.
            start = self._index_from_offset(diagnostic.start)
            end = self._index_from_offset(max(diagnostic.end, diagnostic.start + 1))
            self.editor.tag_add("error", start, end)

    def _refresh_diagnostics(self):
        """Entradas: ultimo analisis. Salida: tabla de errores. Uso: _analyze_now."""
        self.diagnostics_tree.delete(*self.diagnostics_tree.get_children())
        if self.last_result is None:
            return
        for index, diagnostic in enumerate(self.last_result.diagnostics):
            # El iid conserva la posicion para saltar al diagnostico con doble click.
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
        """Entradas: popup existente. Salida: lista actualizada. Uso: _analyze_now."""
        if self.suggestion_popup is None or self.last_result is None:
            return
        self._fill_suggestion_popup()

    def _show_suggestions(self, _event=None):
        """Entradas: Ctrl+Space. Salida: popup de sugerencias. Uso: binding."""
        self._analyze_now()
        if self.last_result is None or not self.last_result.suggestions:
            self._hide_suggestions()
            return "break"
        self._show_suggestions_from_current_result(require_prefix=False)
        return "break"

    def _show_suggestions_from_current_result(self, require_prefix: bool = True):
        """Entradas: resultado actual. Salida: popup posicionado. Uso: sugerencias."""
        if self.last_result is None or not self.last_result.suggestions:
            self._hide_suggestions()
            return
        cursor = self._offset_from_index("insert")
        text_before = self._text()[:cursor]
        if require_prefix and (not text_before or not (text_before[-1].isalnum() or text_before[-1] == "_")):
            # Sin prefijo solo se muestra cuando el usuario pidio Ctrl+Space.
            self._hide_suggestions()
            return
        if self.suggestion_popup is None:
            # Popup liviano, sin decorar, similar a Ctrl+Space de un editor.
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
        # El popup se ancla debajo del cursor.
        x, y, _width, height = bbox
        root_x = self.editor.winfo_rootx() + x
        root_y = self.editor.winfo_rooty() + y + height + 2
        self.suggestion_popup.geometry(f"+{root_x}+{root_y}")
        self.suggestion_popup.deiconify()
        self.suggestion_popup.lift()
        self.editor.focus_set()

    def _fill_suggestion_popup(self):
        """Entradas: sugerencias actuales. Salida: Listbox poblado. Uso: popup."""
        if self.suggestion_list is None or self.last_result is None:
            return
        self.suggestion_list.delete(0, "end")
        self.visible_suggestion_texts = []
        for suggestion in self.last_result.suggestions:
            label = suggestion.text.replace("\n", "\\n")
            if suggestion.detail:
                # Se muestra texto + razon, pero se inserta solo suggestion.text.
                label = f"{suggestion.text:<18} {suggestion.detail}"
                label = label.replace("\n", "\\n")
            self.visible_suggestion_texts.append(suggestion.text)
            self.suggestion_list.insert("end", label)
        if self.suggestion_list.size() > 0:
            # La primera sugerencia queda lista para Enter.
            self.suggestion_list.selection_set(0)

    def _hide_suggestions(self, _event=None):
        """Entradas: evento opcional. Salida: popup oculto. Uso: Escape/insertar."""
        if self.suggestion_popup is not None:
            self.suggestion_popup.withdraw()
        self.editor.focus_set()
        return "break"

    def _suggestions_visible(self) -> bool:
        """Entradas: estado popup. Salida: True si visible. Uso: flechas/Enter."""
        return bool(self.suggestion_popup is not None and self.suggestion_popup.winfo_viewable())

    def _move_suggestion_selection(self, direction: int):
        """Entradas: direccion -1/1. Salida: seleccion movida. Uso: flechas."""
        if not self._suggestions_visible() or self.suggestion_list is None:
            return None
        size = self.suggestion_list.size()
        if size == 0:
            return "break"

        selection = self.suggestion_list.curselection()
        current = selection[0] if selection else 0
        next_index = max(0, min(size - 1, current + direction))
        # El foco sigue en el editor; solo movemos la seleccion visual.
        self.suggestion_list.selection_clear(0, "end")
        self.suggestion_list.selection_set(next_index)
        self.suggestion_list.activate(next_index)
        self.suggestion_list.see(next_index)
        return "break"

    def _insert_suggestion(self, _event=None):
        """Entradas: sugerencia seleccionada. Salida: reemplaza prefijo. Uso: Enter/doble click."""
        if self.suggestion_list is None:
            return "break"
        selection = self.suggestion_list.curselection()
        if not selection:
            return "break"
        suggestion = self.visible_suggestion_texts[selection[0]]
        cursor = self._offset_from_index("insert")
        text_before = self._text()[:cursor]
        start_offset = cursor
        # Se reemplaza solo la palabra parcial antes del cursor.
        for pos in range(len(text_before) - 1, -1, -1):
            if not (text_before[pos].isalnum() or text_before[pos] == "_"):
                break
            start_offset = pos
        self.editor.delete(self._index_from_offset(start_offset), self._index_from_offset(cursor))
        self.editor.insert(self._index_from_offset(start_offset), suggestion)
        self._hide_suggestions()
        self._analyze_now()
        return "break"

    def _handle_return(self, _event=None):
        """Entradas: tecla Enter. Salida: salto indentado o sugerencia. Uso: editor."""
        if self._suggestions_visible():
            return self._insert_suggestion()

        current_line = self.editor.get("insert linestart", "insert")
        line_after_cursor = self.editor.get("insert", "insert lineend")
        base_indent = self._leading_whitespace(current_line)
        before = self.editor.get("insert -1c", "insert")
        after = self.editor.get("insert", "insert +1c")

        self.applying_correction = True
        try:
            if self._looks_like_function_header(current_line, line_after_cursor):
                # Firma sin llave: Enter crea el bloque de funcion completo.
                insert_index = self.editor.index("insert")
                self.editor.insert("insert", f"{{\n{base_indent}{INDENT_UNIT}\n{base_indent}}}")
                self.editor.mark_set("insert", f"{insert_index} + 1 line lineend")
            elif before == "{" and after == "}":
                # Enter entre llaves crea cuerpo indentado y deja el cierre alineado.
                insert_index = self.editor.index("insert")
                self.editor.insert("insert", f"\n{base_indent}{INDENT_UNIT}\n{base_indent}")
                self.editor.mark_set("insert", f"{insert_index} + 1 line lineend")
            else:
                self.editor.insert("insert", "\n" + base_indent)
            self.editor.see("insert")
            self.editor.edit_modified(True)
        finally:
            self.applying_correction = False
        self._on_modified()
        return "break"

    def _looks_like_function_header(self, before_cursor: str, after_cursor: str) -> bool:
        """Entradas: linea partida por cursor. Salida: True si falta bloque. Uso: Enter."""
        full_line = before_cursor + after_cursor
        stripped = full_line.strip()
        if "{" in stripped or not before_cursor.rstrip().endswith(")"):
            # Ya tiene bloque o la firma aun esta incompleta.
            return False
        if after_cursor.strip():
            # Hay texto despues del cursor; no se inserta bloque en medio.
            return False
        return stripped.startswith("func ") or stripped.startswith("@secure")

    def _leading_whitespace(self, text: str) -> str:
        """Entradas: linea. Salida: indentacion inicial. Uso: Enter/llaves."""
        index = 0
        while index < len(text) and text[index] in {" ", "\t"}:
            index += 1
        return text[:index]

    def _insert_pair(self, opener: str, closer: str):
        """Entradas: apertura/cierre. Salida: par insertado. Uso: bindings."""
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
                current_line = self.editor.get("insert linestart", "insert")
                base_indent = self._leading_whitespace(current_line)
                if opener == "{" and not current_line.strip():
                    # Bloque nuevo en linea vacia: conserva indentacion del entorno.
                    self.editor.insert(insert, f"{{\n{base_indent}{INDENT_UNIT}\n{base_indent}}}")
                    self.editor.mark_set("insert", f"{insert} + {len(base_indent) + len(INDENT_UNIT) + 2} chars")
                else:
                    self.editor.insert(insert, opener + closer)
                    self.editor.mark_set("insert", f"{insert} + 1 chars")
            self.editor.edit_modified(True)
        finally:
            self.applying_correction = False
        self._on_modified()
        return "break"

    def _goto_diagnostic(self, _event=None):
        """Entradas: doble click diagnostico. Salida: cursor en error. Uso: tabla."""
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
        """Entradas: accion Nuevo. Salida: editor reiniciado. Uso: toolbar."""
        self.current_file = None
        self._hide_suggestions()
        self.editor.delete("1.0", "end")
        self._insert_template()
        self._clear_compiled_outputs()
        self._analyze_now()

    def _open_file(self):
        """Entradas: accion Abrir. Salida: carga archivo .f. Uso: toolbar."""
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
        self._clear_compiled_outputs()
        self._analyze_now()

    def _save_file(self):
        """Entradas: archivo actual/editor. Salida: archivo escrito. Uso: toolbar/Ctrl+S."""
        if self.current_file is None:
            return self._save_as()
        self._analyze_now(force_corrections=True)
        self.current_file.write_text(self._text(), encoding="utf-8")
        self.status_var.set(f"Guardado: {self.current_file}")
        return "break"

    def _save_as(self):
        """Entradas: editor. Salida: nuevo archivo .f. Uso: Guardar como."""
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
        """Entradas: archivo actual. Salida: .ir/.asm/.bin/.hex O0. Uso: boton Compilar."""
        if self.current_file is None:
            result = self._save_as()
            if result == "break" and self.current_file is None:
                return
        self._analyze_now(force_corrections=True)
        self._save_file()
        # Primero se materializan IR y reporte; luego se genera bin/hex/asm.
        ir_command = [
            sys.executable,
            str(PROJECT_ROOT / "fcc.py"),
            str(self.current_file),
            "--emit-ir-files",
            "-O0",
        ]
        ir_completed = subprocess.run(ir_command, capture_output=True, text=True, cwd=str(PROJECT_ROOT))
        if ir_completed.returncode != 0:
            # No se continua si la IR base no pudo generarse.
            output = (ir_completed.stdout or "") + (ir_completed.stderr or "")
            messagebox.showerror("Compilacion FCC", output or "No se pudo generar la IR.")
            return

        command = [
            # -s escribe .asm; -O0 ya baja desde IR sin optimizaciones.
            sys.executable,
            str(PROJECT_ROOT / "fcc.py"),
            str(self.current_file),
            "-s",
            "-O0",
        ]
        completed = subprocess.run(command, capture_output=True, text=True, cwd=str(PROJECT_ROOT))
        output = (completed.stdout or "") + (completed.stderr or "")
        if completed.returncode == 0:
            self._remember_compiled_outputs()
            messagebox.showinfo("Compilacion FCC", output or "Compilacion completada.")
        else:
            self._clear_compiled_outputs()
            messagebox.showerror("Compilacion FCC", output or "La compilacion fallo.")

    def _remember_compiled_outputs(self):
        """Entradas: archivo actual. Salida: rutas de artefactos. Uso: post-compilacion."""
        source = self.current_file
        if source is None:
            return
        self.compiled_paths = {
            # Se guardan rutas derivadas para botones ASM/IR/BinHex.
            "asm": source.with_suffix(".asm"),
            "bin": source.with_suffix(".bin"),
            "hex": source.with_suffix(".hex"),
            "ir": source.with_suffix(".ir"),
            "blocks": source.with_suffix(".blocks"),
            "cfg_json": source.with_suffix(".cfg.json"),
            "cfg_dot": source.with_suffix(".cfg.dot"),
            "opt_ir": source.with_suffix(".opt.ir"),
            "opt_blocks": source.with_suffix(".opt.blocks"),
            "opt_cfg_json": source.with_suffix(".opt.cfg.json"),
            "opt_cfg_dot": source.with_suffix(".opt.cfg.dot"),
            "report": source.with_suffix(".opt.report"),
            "metrics_csv": source.with_suffix(".metrics.csv"),
            "metrics_table": source.with_suffix(".metrics.txt"),
        }
        self._set_output_buttons(True)

    def _clear_compiled_outputs(self):
        """Entradas: estado actual. Salida: botones deshabilitados. Uso: errores/nuevo."""
        self.compiled_paths = {}
        self._set_output_buttons(False)
        self._show_code_editor()

    def _set_output_buttons(self, enabled: bool):
        """Entradas: bandera. Salida: botones artefactos on/off. Uso: compilacion."""
        state = "normal" if enabled else "disabled"
        self.asm_button.configure(state=state)
        self.ir_button.configure(state=state)
        self.bin_button.configure(state=state)

    def _show_assembly(self):
        """Entradas: ruta .asm. Salida: ASM en area central. Uso: boton Ensamblador."""
        self._show_text_artifact("Ensamblador generado", [self.compiled_paths.get("asm")])

    def _show_ir(self):
        """Entradas: ruta .ir. Salida: IR en area central. Uso: boton IR."""
        self._show_text_artifact("Codigo intermedio generado", [self.compiled_paths.get("ir")])

    def _show_binary(self):
        """Entradas: rutas .bin/.hex. Salida: resumen/hex en area central. Uso: boton Bin/Hex."""
        bin_path = self.compiled_paths.get("bin")
        hex_path = self.compiled_paths.get("hex")
        sections = []
        if bin_path and bin_path.exists():
            sections.append(f"== {bin_path.name} ==\nRuta: {bin_path}\nTamano: {bin_path.stat().st_size} bytes\n")
        if hex_path and hex_path.exists():
            sections.append(f"== {hex_path.name} ==\n{hex_path.read_text(encoding='utf-8')}")
        if not sections:
            messagebox.showwarning("Bin/Hex", "No hay binario generado disponible.")
            return
        self._show_source_artifact("Binario y hexadecimal", "\n".join(sections))

    def _show_text_artifact(self, title: str, paths: list[Path | None]):
        """Entradas: titulo y rutas. Salida: contenido mostrado. Uso: botones artefactos."""
        sections = []
        for path in paths:
            if path is None or not path.exists():
                continue
            sections.append(f"== {path.name} ==\n{path.read_text(encoding='utf-8')}")
        if not sections:
            messagebox.showwarning(title, "No hay archivo generado disponible.")
            return
        self._show_source_artifact(title, "\n\n".join(sections))

    def _show_source_artifact(self, title: str, content: str):
        """Entradas: titulo/contenido. Salida: reemplaza editor por artefacto. Uso: botones."""
        self.source_artifact_title_var.set(title)
        self.source_artifact_viewer.configure(state="normal")
        self.source_artifact_viewer.delete("1.0", "end")
        self.source_artifact_viewer.insert("1.0", content)
        self.source_artifact_viewer.configure(state="disabled")
        self.editor_frame.grid_remove()
        self.artifact_source_frame.grid(row=1, column=0, sticky="nsew")

    def _show_code_editor(self):
        """Entradas: estado UI. Salida: vuelve al editor .f. Uso: boton Codigo .f."""
        self.artifact_source_frame.grid_remove()
        self.editor_frame.grid(row=1, column=0, sticky="nsew")
        self._update_line_numbers()
        self.editor.focus_set()


def main():
    """Entradas: ninguna. Salida: loop Tk activo. Uso: fcc.py --ide."""
    app = FCCIDE()
    app.mainloop()


if __name__ == "__main__":
    main()
