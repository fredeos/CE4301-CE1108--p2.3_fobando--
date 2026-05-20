"""Utilidades para exportar el AST FCC a JSON."""

from __future__ import annotations

import json
from dataclasses import fields, is_dataclass
from pathlib import Path
from typing import Any

from ast_nodes import ASTNode


def ast_to_jsonable(value: Any) -> Any:
    """Convierte nodos AST y contenedores a estructuras serializables."""

    if isinstance(value, ASTNode):
        result = {"node": type(value).__name__}
        for field_info in fields(value):
            result[field_info.name] = ast_to_jsonable(getattr(value, field_info.name))
        return result

    if is_dataclass(value):
        result = {"node": type(value).__name__}
        for field_info in fields(value):
            result[field_info.name] = ast_to_jsonable(getattr(value, field_info.name))
        return result

    if isinstance(value, list):
        return [ast_to_jsonable(item) for item in value]

    if isinstance(value, tuple):
        return [ast_to_jsonable(item) for item in value]

    if isinstance(value, dict):
        return {str(key): ast_to_jsonable(item) for key, item in value.items()}

    return value


def derive_ast_json_output_path(input_path: Path) -> Path:
    """Deriva la ruta de salida para el JSON del AST."""

    return input_path.with_suffix(".ast.json")


def write_ast_json(ast: ASTNode, output_path: Path) -> None:
    """Escribe el AST como JSON UTF-8 indentado."""

    output_path.write_text(
        json.dumps(ast_to_jsonable(ast), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
