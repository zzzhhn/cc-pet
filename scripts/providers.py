#!/usr/bin/env python3
"""Pluggable image-edit provider for the cc-pet art pipeline.

The pipeline needs ONE capability: "given a prompt + one or more reference images,
return an edited image." Every hosted image model exposes this differently, so the
pipeline talks to this adapter instead of any single vendor.

Select a provider with the CCPET_PROVIDER env var (default: "fal"). Each provider
reads its own API key from an env var. The reference implementation is fal.ai's
gpt-image-2/edit; stubs document how to add OpenAI, OpenRouter, or Gemini.

    from providers import edit_image
    edit_image(prompt, ["base.png", "guide.png"], size={"width": 1024, "height": 1024},
               out_path="out.png")
"""
import os
import pathlib
import urllib.request


def _provider() -> str:
    return os.environ.get("CCPET_PROVIDER", "fal").lower()


def edit_image(prompt: str, image_paths: list[str], size, out_path: str) -> None:
    """Edit reference image(s) with a text prompt; write the result to out_path.

    `size` is either a preset string the provider understands (e.g. "auto",
    "square_hd") or a dict {"width", "height"}. Providers should honor it best-effort.
    """
    name = _provider()
    if name == "fal":
        _edit_fal(prompt, image_paths, size, out_path)
    elif name == "openai":
        _edit_openai(prompt, image_paths, size, out_path)
    else:
        raise ValueError(
            f"Unknown CCPET_PROVIDER={name!r}. Built-in: 'fal' (reference), 'openai' (stub). "
            "Add your own in providers.py by implementing the edit_image contract."
        )


# --- Reference implementation: fal.ai gpt-image-2/edit -----------------------------
def _edit_fal(prompt, image_paths, size, out_path) -> None:
    """fal.ai hosted gpt-image-2. Key: FAL_KEY env var.

    Note: fal rejects canvases with aspect ratio > 3:1; the pipeline generates frames
    as a 2xN grid to stay within that limit. Providers without this cap can use wider
    single-row strips.
    """
    key = os.environ.get("FAL_KEY")
    if not key:
        raise KeyError("FAL_KEY not set. export FAL_KEY=... (see .env.example)")
    os.environ["FAL_KEY"] = key
    import fal_client  # pip install fal-client

    urls = [fal_client.upload_file(p) for p in image_paths]
    result = fal_client.subscribe(
        "openai/gpt-image-2/edit",
        arguments={
            "prompt": prompt,
            "image_urls": urls,
            "image_size": size,
            "quality": "high",
            "output_format": "png",
            "num_images": 1,
        },
        with_logs=True,
        on_queue_update=lambda u: print(f"      .. {type(u).__name__}", flush=True),
    )
    images = (result or {}).get("images") or []
    if not images:
        raise RuntimeError(f"provider returned no images; payload: {result}")
    pathlib.Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(images[0]["url"], out_path)


# --- Stub: OpenAI Images edit (gpt-image-1) ----------------------------------------
def _edit_openai(prompt, image_paths, size, out_path) -> None:
    """Sketch for OpenAI's native image edit. Key: OPENAI_API_KEY.

    OpenAI's image edit accepts a wide canvas, so you can skip the 2xN grid workaround
    and generate a single horizontal strip. Implement with the openai SDK:

        from openai import OpenAI
        client = OpenAI()
        res = client.images.edit(model="gpt-image-1", prompt=prompt,
                                  image=[open(p, "rb") for p in image_paths], size="1024x1024")
        # decode res.data[0].b64_json -> out_path
    """
    raise NotImplementedError(
        "OpenAI provider is a documented stub — implement _edit_openai in providers.py. "
        "See the docstring for the outline."
    )
