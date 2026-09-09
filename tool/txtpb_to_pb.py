#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "protobean>=0.3.0",
#   "typer>=0.12",
# ]
# ///

# Converts a protobean text-format golden into tagged binary on stdout.
# Goldens are ParsedDirectives or Errors (not ParsedLedger), so fixtures stay flat.
# Wire format: one kind byte (0x01=ParsedDirectives, 0x02=Errors) then protobuf bytes.

from __future__ import annotations

import sys
from pathlib import Path
from typing import Annotated

import typer
from google.protobuf import text_format
from protobean.beancount import directive_pb2, error_pb2

KIND_DIRECTIVES = 0x01
KIND_ERRORS = 0x02

app = typer.Typer(
    add_completion=False, help="Load protobean .txtpb goldens for Dart tests."
)


def _first_field(text: str) -> str | None:
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        token = []
        for ch in stripped:
            if ch.isalnum() or ch == "_":
                token.append(ch)
            else:
                break
        return "".join(token) or None
    return None


@app.command()
def main(
    txtpb: Annotated[
        Path,
        typer.Argument(
            exists=True, dir_okay=False, readable=True, help="Path to a .txtpb golden"
        ),
    ],
) -> None:
    text = txtpb.read_text(encoding="utf-8")
    field = _first_field(text)
    if field == "errors":
        message = error_pb2.Errors()
        text_format.Parse(text, message)
        kind = KIND_ERRORS
    else:
        # Empty files and directive lists are ParsedDirectives.
        message = directive_pb2.ParsedDirectives()
        text_format.Parse(text, message)
        kind = KIND_DIRECTIVES
    sys.stdout.buffer.write(bytes([kind]))
    sys.stdout.buffer.write(message.SerializeToString())


if __name__ == "__main__":
    app()
