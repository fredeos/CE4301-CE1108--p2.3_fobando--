"""Resolucion recursiva de imports para programas FCC multiarchivo."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

from ast_nodes import ImportNode, ProgramNode
from parser_driver import parse_and_build_ast


@dataclass
class ImportResolutionError(Exception):
    """Representa un fallo al ubicar o expandir imports."""

    message: str


@dataclass
class ResolvedProgram:
    """Agrupa el AST consolidado y la lista de archivos cargados."""

    program: ProgramNode
    loaded_files: List[Path]


def resolve_program_ast(input_path: Path, include_dirs: Optional[List[Path]] = None) -> ResolvedProgram:
    """Carga el archivo principal, expande imports y devuelve un AST unificado."""

    include_dirs = [path.resolve() for path in (include_dirs or [])]

    loaded_files: List[Path] = []
    resolved_files: set[Path] = set()
    visiting_stack: List[Path] = []

    def visit(path: Path) -> List:
        """Recorre un archivo y devuelve sus declaraciones ya expandidas."""

        resolved_path = path.resolve()

        if resolved_path in resolved_files:
            return []

        if resolved_path in visiting_stack:
            cycle = " -> ".join(str(item.name) for item in [*visiting_stack, resolved_path])
            raise ImportResolutionError(f'Error [import] ciclo de imports detectado: {cycle}.')

        visiting_stack.append(resolved_path)

        # Cada archivo importado se parsea por separado antes de fusionarlo.
        _, _, ast = parse_and_build_ast(resolved_path)
        declarations = []
        loaded_files.append(resolved_path)

        for decl in ast.declarations:
            if isinstance(decl, ImportNode):
                import_target = _resolve_import_path(
                    decl.path,
                    resolved_path.parent,
                    include_dirs,
                )
                if import_target is None:
                    raise ImportResolutionError(
                        f'Error [import] en linea {decl.line}: no se encontro el archivo importado "{decl.path}".'
                    )
                declarations.extend(visit(import_target))
            else:
                declarations.append(decl)

        visiting_stack.pop()
        resolved_files.add(resolved_path)
        return declarations

    final_declarations = visit(input_path)
    return ResolvedProgram(
        program=ProgramNode(declarations=final_declarations, line=1, column=0),
        loaded_files=loaded_files,
    )


def _resolve_import_path(import_path: str, base_dir: Path, include_dirs: List[Path]) -> Optional[Path]:
    """Busca un import relativo al archivo actual y luego en los -I."""

    candidate_names = [import_path]
    if not Path(import_path).suffix:
        candidate_names.append(f"{import_path}.f")

    search_roots = [base_dir, *include_dirs]
    for root in search_roots:
        for candidate_name in candidate_names:
            candidate = (root / candidate_name).resolve()
            if candidate.exists() and candidate.is_file():
                return candidate

    return None
