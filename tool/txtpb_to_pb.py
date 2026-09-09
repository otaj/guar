#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "protobean>=0.3.0",
#   "typer>=0.12",
# ]
# ///

# Converts a protobean text-format golden into tagged binary on stdout.
# Wire format: kind byte then protobuf bytes.
# 0x01=ParsedDirectives, 0x02=Errors, 0x03=ParsedLedger (options/info cases).

from __future__ import annotations

import sys
from pathlib import Path
from typing import Annotated

import typer
from google.protobuf import text_format
from protobean.beancount import directive_pb2, error_pb2, ledger_pb2

KIND_DIRECTIVES = 0x01
KIND_ERRORS = 0x02
KIND_LEDGER = 0x03

app = typer.Typer(
    add_completion=False, help="Load protobean .txtpb goldens for Dart tests."
)


def _top_level_fields(text: str) -> list[str]:
    fields: list[str] = []
    for line in text.splitlines():
        if not line or line[0].isspace():
            continue
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        token: list[str] = []
        for ch in stripped:
            if ch.isalnum() or ch == "_":
                token.append(ch)
            else:
                break
        if token:
            fields.append("".join(token))
    return fields


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
    fields = set(_top_level_fields(text))
    if fields & {"options", "info"}:
        message = ledger_pb2.ParsedLedger()
        text_format.Parse(text, message)
        kind = KIND_LEDGER
    elif "errors" in fields:
        message = error_pb2.Errors()
        text_format.Parse(text, message)
        kind = KIND_ERRORS
    else:
        message = directive_pb2.ParsedDirectives()
        text_format.Parse(text, message)
        kind = KIND_DIRECTIVES
    sys.stdout.buffer.write(bytes([kind]))
    sys.stdout.buffer.write(message.SerializeToString())


if __name__ == "__main__":
    app()
